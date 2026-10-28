---
layout: single
title: "Prompt Builder as Architecture: Designing Reliable Prompt Templates for Agentforce"
date: 2026-11-01
categories:
  - Agentforce
tags:
  - Salesforce
  - Agentforce
  - PromptBuilder
  - PromptEngineering
  - Grounding
  - Architecture
---

In the previous posts we followed the retrieval path: index, retriever, and the knowledge that reaches the model. We ended at a single box labeled "Prompt = instructions + question + retrieved chunks." This post opens that box.

In Agentforce, the **prompt template** is the unit where business intent, enterprise data, and a model meet. It is versioned, testable, and reusable across agents, flows, record pages, and Apex. Teams that treat it as "a text box where you type a prompt" end up with fragile behavior. Teams that treat it as an **interface contract** get agents that stay predictable as data, models, and requirements change.

> **TL;DR**
> - A template is **instructions + inputs + resources + model + version**. Design each of the five deliberately.
> - Pick the **template type first**: it determines the inputs you can bind and where the template can be called from.
> - Ground with the lightest resource that works: merge fields for simple record data, **Flow or Apex** for computed or external data, a **retriever** for unstructured knowledge.
> - A good prompt is **structured, delimited, and has an explicit fallback** for missing data.
> - Test with edge cases (null fields, long text, other languages), compare versions, and only then expose the template to an agent.

---

## 1. Anatomy of a Prompt Template

```
 ┌───────────────────────── PROMPT TEMPLATE ─────────────────────────┐
 │                                                                   │
 │  INPUTS            RESOURCES (grounding)        INSTRUCTIONS      │
 │  ───────           ─────────────────────        ────────────      │
 │  record(s)   ───►  merge fields / related  ┐    role              │
 │  free text         Flow output             ├──► task              │
 │                    Apex output             │    constraints       │
 │                    retriever results       ┘    output format      │
 │                                                                   │
 │  MODEL + VERSION        ──►  Einstein Trust Layer  ──►  LLM       │
 └───────────────────────────────────────────────────────────────────┘
```

| Component | Design question |
|---|---|
| **Inputs** | What does the caller pass in: one record, several records, or free text? |
| **Resources** | Which data does the model need that the inputs alone do not contain? |
| **Instructions** | What is the role, task, boundary, and output shape? |
| **Model** | Which model fits the task's quality, speed, and language needs? |
| **Version** | What changed, and can you roll back? |

---
