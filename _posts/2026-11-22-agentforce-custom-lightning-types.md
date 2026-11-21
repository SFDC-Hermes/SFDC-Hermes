---
layout: single
title: "Beyond the Wall of Text: Custom Lightning Types for Rich Agentforce Experiences"
date: 2026-11-22
categories:
  - Agentforce
tags:
  - Salesforce
  - Agentforce
  - LightningTypes
  - LWC
  - AgentActions
  - UX
  - Architecture
---

By default, an Agentforce conversation is text in and text out. The agent asks for an order number, a date, a product, and a quantity one message at a time, and it answers with paragraphs that the user has to read carefully to find the one value they need. That works for simple exchanges. It breaks down when the task needs structured input, validation, or a result that is easier to *see* than to read.

**Custom Lightning types** solve this. They let an action's inputs and outputs use **Lightning Web Components** inside the conversation: a form with dropdowns and validation instead of five back-and-forth questions, a set of cards instead of a wall of text. This post explains how they work, where they are supported, how to design them so they do not fail silently, and what I ran into when using them in a real implementation.

> **TL;DR**
> - A Lightning type defines a **data shape** plus how that shape is **edited** (input) and **rendered** (output).
> - A custom type is a **Lightning type bundle**: a required **schema**, plus an optional **editor** and **renderer** configuration that point to LWCs.
> - Apex defines the data shape and business logic. The LWC handles presentation only.
> - Support differs **by channel**: Lightning Experience, mobile, Enhanced Chat v2, and Experience Builder each have their own rules.
> - Two failure modes dominate: a **silent fallback to plain text** caused by naming mismatches, and **inconsistent rendering** because the model decides whether to show the component. Make critical UI **deterministic** instead of hoping the model chooses it.

---

## 1. The Problem With Text-Only Actions

| Text-only interaction | Consequence |
|---|---|
| The agent collects five inputs through five questions | Slow, and each answer is a chance for a misread value |
| Free text for structured values such as dates or picklists | The model has to parse and validate what a form control would enforce |
| Results returned as paragraphs | Users scan for the key value; comparisons across items are hard |
| No visual action in the response | Users must type the next request instead of acting on what they see |

The previous posts made actions reliable as contracts. Lightning types make the **user-facing side** of that contract as structured as the data behind it.

---

## 2. What a Lightning Type Is

A **Lightning type** is a JSON-based data type that defines, validates, and displays data. Salesforce provides **standard types**, such as text, number, date, date-time, boolean, URL, rich text, and object, each with a default editor and renderer.

**Custom Lightning types** replace the default UI with your own components for business-specific data, including nested objects and lists. They come in two categories:

| Category | Schema source | Where it is used |
|---|---|---|
| **Apex-based** | References an existing Apex class | Agentforce Employee agents in Lightning Experience and on mobile; Agentforce Service agents through Enhanced Chat v2 |
| **Object-based** | JSON structure defined directly, without Apex | Experience Builder, and Prompt Builder and Flows through structured outputs |

For agent actions, **Apex-based types** are the main pattern: the same Apex class that defines the action's input or output also defines the type's shape.

---

## 3. Anatomy of a Lightning Type Bundle

A custom type is deployed as a **Lightning type bundle** (available from API version 64.0), with one folder per type.

| Part | Required | Role |
|---|---|---|
| **Schema** (`schema.json`) | Yes | Defines the data structure and validation, or points to an Apex class |
| **Editor** (`editor.json`) | No | Defines the **input** UI: which LWC collects the data and how fields are laid out |
| **Renderer** (`renderer.json`) | No | Defines the **output** UI: which LWC displays the data |

Editor and renderer configurations live in **channel-specific subfolders**, so one type can look different in Lightning Experience, on mobile, and in a customer chat.

Three layers work together:

```
 ┌─────────────────────────┐
 │ AGENT DEFINITION        │  declares which action inputs and outputs
 │ (Agent Script / Builder)│  use a custom type and should be shown as UI
 └───────────┬─────────────┘
             ▼
 ┌─────────────────────────┐
 │ LIGHTNING TYPE BUNDLE   │  schema → Apex data shape
 │                         │  editor / renderer → LWC per channel
 └───────────┬─────────────┘
             ▼
 ┌─────────────────────────┐
 │ LIGHTNING WEB COMPONENT │  renders the form or the result
 │                         │  inside the conversation
 └─────────────────────────┘
```

The separation of concerns is the point: **Apex owns the data shape and the business rules; the LWC owns presentation.**

---
