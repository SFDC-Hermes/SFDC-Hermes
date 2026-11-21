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
