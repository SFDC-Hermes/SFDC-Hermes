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
