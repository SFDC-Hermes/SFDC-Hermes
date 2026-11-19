---
layout: single
title: "Designing Agent Actions: Apex, Flow, and Prompt Template Patterns for Agentforce"
date: 2026-11-15
categories:
  - Agentforce
tags:
  - Salesforce
  - Agentforce
  - AgentActions
  - Apex
  - Flow
  - PromptBuilder
  - Architecture
---

Subagents decide *which job* the agent is doing. Instructions shape *how* it behaves. But nothing actually happens in Salesforce until an **action** runs. Actions are where the agent reads records, writes data, calls external systems, and generates content. They are also where most production incidents originate: wrong data returned, duplicate records created, silent failures the agent reports as success.

This post covers how to design actions as reliable contracts, regardless of whether they are implemented in Apex, Flow, or a prompt template. It reflects the platform as of the **Winter '27** release.

> **TL;DR**
> - An action is a **typed contract**: inputs, outputs, and a description the model reads. Design the contract before the implementation.
> - **Default to Flow**, use **Apex** when Flow cannot meet the requirement, and use **prompt templates** for generation, never for writes.
> - Keep each action to **one responsibility**, validate every agent-supplied input, and return **explicit success or failure**.
> - Writes must be **idempotent**. The agent may retry, and events may be delivered more than once.
> - Decide deliberately whether an action runs **deterministically** or is offered to the model as a **tool**.

---

## 1. What an Action Is Today

An action is a task a subagent can perform. It points to an executable target and declares typed inputs and outputs. The current builder supports three primary target types:

| Target | What it runs |
|---|---|
| **Apex** | An invocable Apex method |
| **Flow** | An autolaunched flow |
| **Prompt template** | A Prompt Builder template that generates content |

In addition, Winter '27 lists **MCP server tools** alongside standard actions in the Agentforce Builder, so external capabilities can be added without building a custom wrapper for each system.

Two structural facts shape design:

- **Actions belong to a subagent.** Each subagent gets its own copy of an action, so the same capability can be described differently depending on the job it serves.
- **Actions run in one of two modes.** They can run **deterministically**, every time a condition is met, or be exposed to the model as a **tool** that it chooses to call based on context.

```
                    ┌──────────────────────────────┐
                    │          SUBAGENT            │
                    │                              │
  condition met ──► │  deterministic action  ──┐   │
                    │                          │   │
  model decides ──► │  tool (LLM-selected)  ───┤   │
                    │                          ▼   │
                    │        ┌──────────────────┐  │
                    │        │ ACTION CONTRACT  │  │
                    │        │ inputs · outputs │  │
                    │        │ description      │  │
                    │        └────────┬─────────┘  │
                    └─────────────────┼────────────┘
                                      ▼
                     Apex · Flow · Prompt template · MCP tool
```

---

## 2. Choosing the Implementation

| Option | Use when | Avoid when |
|---|---|---|
| **Flow** | Standard record reads and writes, simple branching, admin-maintained logic | Complex transformation, heavy computation, or logic that becomes unreadable on a canvas |
| **Apex** | Complex logic, external callouts with careful error handling, shared service-layer logic, strict control over output | The team cannot support Apex long term |
| **Prompt template** | Summaries, drafts, classification, analysis of record context | Any create, update, or delete operation |
| **MCP tool** | Capabilities owned by another system or exposed through a standard tool interface | When a native action already does the job more simply |

Three rules make the choice easier:

1. **Default to Flow.** Escalate to Apex only when Flow cannot meet the requirement. Apex is more powerful, but it needs developers to maintain it.
2. **Writes go through Apex or Flow.** A prompt template generates text; it should never be the mechanism that changes data.
3. **Use autolaunched flows, not screen flows.** An agent action has no screen to show.

---

## 3. Designing the Contract

The contract is what the model sees. A well-implemented action with a vague contract still fails, because the model calls it at the wrong time or with the wrong values.

### 3.1 One Responsibility per Action

Each action should do one thing. A useful refinement:

- **Writes should be narrow.** One action creates a case; another updates its priority.
- **Reads can be flexible.** A single lookup action may search several objects based on a parameter, because a read has no side effects.

### 3.2 Inputs

| Practice | Why |
|---|---|
| **Describe every input** | Input descriptions are how the model knows what value to supply. |
| **Mark only truly required inputs as required** | The model may fill required, unbound inputs from the conversation (slot-filling). Extra required inputs mean extra chances for a wrong guess. |
| **Prefer verified context over inference** | Values such as customer tier or account ID should come from verified records or variables, not from what the model infers from chat. |
| **Validate at the boundary** | Treat every agent-supplied value as untrusted input. Check format, range, and ownership before acting on it. |

### 3.3 Outputs

| Practice | Why |
|---|---|
| **Return only the fields the next step needs** | Hand-pick output fields instead of returning whole records. |
| **Include an explicit status and message** | The model cannot reliably infer failure from a null or empty response. |
| **Keep sensitive or irrelevant outputs out of the model's context** | Outputs are remembered for the session by default; exclude what the model should not see or repeat. |
| **Store outputs that other subagents need in variables** | Variables carry state reliably across subagents and later turns. |

### 3.4 Plan for Change

Changing an action's inputs or outputs can force you to rebuild it. A practical pattern, especially for flows, is to include a **spare text input or output** from the start, so you can pass additional context later without breaking the contract.

---

## 4. Error Handling: Make Failure Explicit

A failed action that returns nothing looks, to the model, like a successful action with no data. That is how agents end up telling users "your request is complete" when it is not.

| Principle | Practice |
|---|---|
| **Explicit result** | Return a success or failure flag plus a specific, actionable message. |
| **Fault paths for writes** | Every flow that performs DML needs a fault path that returns a clear result. |
| **Partial success is a valid result** | Report which parts succeeded and which did not, so the agent can respond accurately. |
| **Retry ceilings** | Limit retries and route repeated failures to a human. Winter '27 adds deterministic escalation in Agent Script for this kind of handoff. |
| **Honest language** | Never describe a dispatched request as completed. If work was queued, return a reference ID and say it was submitted. |

---

## 5. Execution: Timing, Retries, and Idempotency

### 5.1 Synchronous or Asynchronous

| Pattern | Use when |
|---|---|
| **Sequential** | Each step needs the verified result of the previous one. |
| **Parallel** | Independent calls can run concurrently. |
| **Asynchronous** | The work is slow and the user does not need the result in this turn. The action confirms dispatch and returns a reference ID. |

Synchronous actions keep the user waiting. Set explicit timeouts on every callout, and handle throttling and temporary unavailability with backoff and limited retries.

### 5.2 Idempotency

Every write must be safe to repeat:

- The reasoning engine may call an action **more than once in a turn**.
- Retries after an ambiguous response must not create duplicates.
- Event delivery is typically **at least once**.

Use a stable reference key for each logical operation, and make the action check whether that operation already happened before acting again.

---

## 6. Security: The Action Is the Enforcement Point

- **Permission sets control object and field visibility, not record access.** Record-level checks must be enforced inside the Flow or Apex logic.
- **Test both directions.** Confirm the agent can retrieve the records it should, and confirm it cannot retrieve records it should not.
- **Credentials belong in Named Credentials**, and integration users should have least privilege.
- **Sanitize model-supplied inputs.** They can carry injection attempts from user text or retrieved content.
- **Gate risky actions.** Require user confirmation before actions with significant side effects, such as cancellations, refunds, or data deletion.
- **Never expose open-ended query access** to the model. Give it specific, bounded actions instead.

---

## 7. Deterministic Execution vs. Tool Selection

| Run deterministically when | Offer as a tool when |
|---|---|
| The step must always happen, such as identity verification | Whether to call it depends on what the user asked |
| Order matters and a later step depends on an earlier one | Several actions could be relevant and the model must choose |
| The result must be stored for later subagents | The call is cheap and side-effect free |

**Action chaining** lets one action run immediately after another, passing outputs as inputs. Use it when two actions always belong together, such as finding an account and then retrieving its details. Leaving such pairs to the model's judgment is a common source of inconsistent behavior.

---

## 8. Winter '27 Changes Worth Knowing

- **MCP tools in the action picker.** MCP server tools now appear next to standard actions in the Agentforce Builder.
- **Structured action output per connection.** Agent Script can send structured action output directly to a client in a specified format, instead of always passing it through the model's text response.
- **Deterministic escalation.** A condition can hand the conversation to a human without relying on the model's judgment.
- **Higher Apex heap limits.** The synchronous heap limit increased from 6 MB to 10 MB, and the asynchronous limit from 12 MB to 25 MB. Larger heaps are not a reason to return larger outputs to the model.
- **Simpler agent metadata.** From API version 68.0, agents are described by agent definition and version metadata, so deployments no longer require listing every Apex class, flow, and prompt template by hand.
- **Typed outputs with Lightning types.** Action outputs can be typed with custom Lightning types and rendered as rich UI, which is the subject of the next post.

---

## Anti-Patterns

- One action that reads, decides, and writes in a single step.
- Prompt templates used to change data.
- Returning entire records instead of selected fields.
- Treating a null response as success.
- Writes that are not idempotent.
- Relying on permission sets alone for record-level security.
- Open-ended query actions exposed to the model.
- Leaving mandatory step sequences to the model's choice.
- Describing queued work as completed.

## Production Checklist

- [ ] Each action has one responsibility; writes are narrow.
- [ ] Every input and output has a specific description.
- [ ] Only truly required inputs are marked required.
- [ ] Agent-supplied inputs are validated at the action boundary.
- [ ] Outputs include an explicit status and message, and only needed fields.
- [ ] Sensitive outputs are kept out of the model's context.
- [ ] Writes are idempotent and safe to retry.
- [ ] Callouts have timeouts, backoff, and retry ceilings.
- [ ] Record-level access is enforced inside the action and tested negatively.
- [ ] Risky actions require user confirmation.
- [ ] Mandatory steps run deterministically.

---

## Conclusion

The model is only as trustworthy as the actions it can call. Design actions as contracts first: narrow responsibilities, explicit inputs and outputs, clear failure signals, and idempotent writes. The implementation, whether Flow, Apex, prompt template, or an MCP tool, then becomes a detail that can change without changing the agent's behavior.

In the next post, we look at **custom Lightning types**: how to give action inputs and outputs a rich UI by embedding Lightning Web Components in the agent experience.

---

### References

- Salesforce Developers: [Agent Script Reference: Actions](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html)
- Salesforce Developers: [The Salesforce Developer's Guide to the Winter '27 Release](https://developer.salesforce.com/blogs/2026/10/developers-guide-to-the-winter-27-release)
- Salesforce Architects: [Agentic Integration Patterns](https://architect.salesforce.com/docs/architect/fundamentals/guide/agentic-integration-patterns)
- Salesforce Break: [Agentforce Agent Flow Action Best Practices](https://salesforcebreak.com/2026/08/20/agentforce-agent-flow-actions/)
