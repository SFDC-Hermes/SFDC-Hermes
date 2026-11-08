---
layout: single
title: "Topics, Now Subagents: Designing Routing and Instructions in Agentforce"
date: 2026-11-08
categories:
  - Agentforce
tags:
  - Salesforce
  - Agentforce
  - Subagents
  - Topics
  - Instructions
  - AgentScript
  - Architecture
---

When an Agentforce agent gives a wrong answer, the instinct is to blame the model. In practice, most failures come from one of two design decisions made long before the conversation: **which subagent was chosen**, and **what that subagent was told to do**. Those are different problems with different fixes, and confusing them is the most common reason agent tuning goes in circles.

This post is about designing both well. It also covers a terminology change that matters for anyone reading older material: **starting in April 2026, agent "topics" are called "subagents."** The functionality is the same, but documentation, org settings, and older tutorials may mix both terms.

> **TL;DR**
> - Every turn involves two separate decisions: **routing** (which subagent handles the request) and **behavior** (what that subagent does).
> - Routing is driven by the subagent's **description**. Instructions do **not** affect routing. Fixing a routing error by editing instructions does not work.
> - Split subagents by **job**, not by data object, and make their descriptions **contrast** with their neighbors.
> - Keep instructions short and specific. Anything that must happen every time belongs in **deterministic logic**, not in natural language.
> - Measure routing accuracy separately from answer quality. A good final answer does not prove the right subagent handled the request.

---

## 0. Terminology: Old and New

| Earlier term | Current term | Role |
|---|---|---|
| Topic | **Subagent** | A bounded job the agent can perform |
| Topic Selector | **Agent Router** | Chooses which subagent handles each message |
| Classification description | **Description** ("when the subagent is used") | The text the router matches requests against |
| Topic instructions | **Reasoning instructions** | Guide behavior after the subagent is selected |

This post uses the current terms. If your org or an older guide still says "topic," read it as "subagent."

---

## 1. The Mental Model: Two Decisions per Turn

```
 USER MESSAGE + conversation history
              │
              ▼
 ┌──────────────────────────┐
 │ AGENT ROUTER             │   Decision 1: ROUTING
 │ matches against each     │   driven by subagent DESCRIPTIONS
 │ subagent's description   │
 └────────────┬─────────────┘
              ▼
 ┌──────────────────────────┐
 │ SELECTED SUBAGENT        │   Decision 2: BEHAVIOR
 │  reasoning instructions  │   driven by INSTRUCTIONS,
 │  deterministic logic     │   logic, and ACTION descriptions
 │  available actions       │
 └────────────┬─────────────┘
              ▼
     actions run → grounded response
```

Routing happens inside the Atlas reasoning engine's loop. The router reads the user's input and the conversation history, then compares the request with each subagent's description. Only after a subagent is chosen do its instructions and actions come into play.

The practical consequence is the most important idea in this post:

> **Instructions change behavior, not routing.** If the wrong subagent is selected, adding rules to instructions will not fix it. The fix lives in the descriptions.

---

## 2. Designing Subagents

### 2.1 Split by Job, Not by Data Object

A subagent should represent a bounded job the user wants done, named by its outcome: *Order Status*, *Returns and Refunds*, *Appointment Scheduling*. A design that mirrors the data model, such as an *Account* subagent and an *Order* subagent, forces the router to guess, because real requests cut across objects.

### 2.2 Make the Set Mutually Exclusive

Together, the subagents should cover the agent's jobs without overlapping. A simple test helps:

> If you cannot explain the difference between two subagents in one sentence, merge them.

### 2.3 Review the Whole Set When Adding One

Adding a custom subagent without re-reading the existing ones, including standard subagents, is a common way to create a new collision. Every new subagent changes the routing landscape for all the others.

### 2.4 Know When to Split the Agent

There is a practical ceiling on how many subagents one agent should carry. Commonly cited guidance is around **15 subagents per agent and no more than 15 actions per subagent**; confirm the current numbers for your edition. Approaching that ceiling is a signal to divide the work across multiple agents rather than to keep adding subagents.

---

## 3. Writing Descriptions: The Routing Contract

The description is the single most important routing field. The router matches each request against it, so it must be written for the model, not for the admin who reads the setup page.

| Principle | Weak description | Strong description |
|---|---|---|
| **Use the customer's words** | "Handles order objects" | "Questions about where an order is, when it will arrive, or why it is delayed" |
| **State the boundary** | "Order help" | "Tracking and delivery status for existing orders. Does not handle returns, refunds, or order changes." |
| **Contrast with neighbors** | Two subagents both say "helps with orders" | One owns *status and delivery*, the other owns *returns and refunds*, and each says so |
| **Be specific about the job** | "Customer support" | "Booking, rescheduling, or cancelling a service appointment" |

The key word is **contrast**. A description that is accurate on its own can still collide with a neighbor. When two subagents compete for the same requests, add the discriminating fact to **both** descriptions, so the router can tell them apart from either side.

Where the builder offers a separate **scope** field, use it to restate purpose and boundaries. It reinforces classification, but the description remains the primary routing signal.

---

## 4. Writing Instructions: Behavior After Routing

Once a subagent is selected, its reasoning instructions guide conversation flow, tone, action selection, and business context. Salesforce's own guidance stresses keeping them **short, clear, and actionable**. Long instructions are not more controlling; they are more ambiguous.

Practices that hold up:

| Practice | Why it matters |
|---|---|
| **Define domain terms** | The model may not know what "PO hold" or "tier-2 partner" means in your business. |
| **State required sequences explicitly** | "Confirm the order number before checking status" is clearer than hoping the model infers it. |
| **Use exact action names consistently** | Referring to the same action by different names creates confusion about which one to call. |
| **Use "always" and "never" deliberately** | Overused absolutes lose meaning; reserve them for real rules. |
| **Give decision criteria between similar actions** | Tell the model when to use a lookup by order number versus a lookup by email. |

A quick contrast:

- **Vague:** "Get the customer's order details."
- **Specific:** "Ask for the order number. If the customer does not have it, ask for the email address used at checkout and use the email-based lookup. If several orders match, list them and ask which one."

The specific version gives the model a decision path. The vague version gives it a goal and leaves the path to chance.

---

## 5. Deterministic vs. Non-Deterministic Control

Instructions are natural language, which means they are **non-deterministic**. They are excellent for tone, phrasing, and conversational judgment. They are not a reliable place for rules that must hold every time.

Agentforce addresses this with what Salesforce calls **hybrid reasoning**: deterministic logic for control, natural-language instructions for behavior. In the current builder, **Agent Script** brings both into one readable definition, so a subagent can mix fixed rules and LLM reasoning.

| Belongs in deterministic logic | Belongs in instructions |
|---|---|
| Identity or eligibility checks that must always run | Tone, empathy, and phrasing |
| Mandatory step order | How to ask clarifying questions |
| Calculations and business rules | How to summarize results for the customer |
| Moving to another subagent when a condition is met | Judgment calls in ambiguous conversations |
| Hiding risky actions until conditions are met | Choosing among options when there is no hard rule |
| Tracking state, such as whether a user is verified | Adapting explanations to the user's level |

Several mechanisms make this concrete:

- **Logic instructions** run an action or set a value every time a condition is true, while **prompt instructions** are passed to the model as guidance.
- **Transitions** between subagents can be **deterministic** (triggered by a condition) or **exposed to the model** as a choice.
- **Availability conditions** control whether an action is offered at all, and **user confirmation** can be required before a risky action runs.
- **Variables** hold state reliably, instead of relying on the model to remember it from context.

A useful boundary: if a process is fully static, with no conversational judgment involved, it probably belongs in **Flow** rather than in an agent at all.

---
