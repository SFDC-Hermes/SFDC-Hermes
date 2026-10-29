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
 ┌───────────────────────── PROMPT TEMPLATE ──────────────────────────┐
 │                                                                    │
 │  INPUTS            RESOURCES (grounding)        INSTRUCTIONS       │
 │  ───────           ─────────────────────        ────────────       │
 │  record(s)   ───►  merge fields / related  ┐    role               │
 │  free text         Flow output             ├──► task               │
 │                    Apex output             │    constraints        │ 
 │                    retriever results       ┘    output format      │
 │                                                                    │
 │  MODEL + VERSION        ──►  Einstein Trust Layer  ──►  LLM        │
 └────────────────────────────────────────────────────────────────────┘
```

| Component | Design question |
|---|---|
| **Inputs** | What does the caller pass in: one record, several records, or free text? |
| **Resources** | Which data does the model need that the inputs alone do not contain? |
| **Instructions** | What is the role, task, boundary, and output shape? |
| **Model** | Which model fits the task's quality, speed, and language needs? |
| **Version** | What changed, and can you roll back? |

---

## 2. Choose the Template Type First

The type is chosen at creation, and it decides which inputs you can bind and where the template can be invoked. Choosing wrongly means rebuilding the template.

| Type | Purpose | Where it is used |
|---|---|---|
| **Sales Email** | Draft personalized emails for a contact or lead | Einstein Sales Emails |
| **Field Generation** | Populate a field with an LLM-generated summary or description | Lightning record pages |
| **Flex** | Generate output from a variable number of inputs across different object types | An invocable action anywhere on the platform, the Connect REST API, or Connect in Apex |

Other types exist for specific features (for example Record Summary, Record Prioritization, and Service Email Assistant), but these three cover most custom work.

**Flex is usually the right default for custom agent actions**, because it is not tied to one object or one UI surface. Two Flex design facts matter early:

- A Flex template accepts **up to five inputs**, of type **Object**, **Free Text**, or **Data Model Object**.
- **Inputs cannot be changed after configuration.** Include at least one **Free Text** input from the start, so you can pass extra context later without rebuilding the template.

> **Note:** Type names and supported entry points change between releases. Confirm what your org supports in Salesforce Help ("Prompt Builder").

---
