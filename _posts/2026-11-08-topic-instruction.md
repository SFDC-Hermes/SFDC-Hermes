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
