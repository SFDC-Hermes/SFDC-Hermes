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

## 3. Resources: Choosing How to Ground

Grounding means supplying the data the model must rely on. Prompt Builder lets you reference **merge fields (record fields and related lists), Flow, and Apex**, and it also supports Data 360 sources such as DMOs, data graphs, and Knowledge or retrievers (individual, ensemble, and web), as well as file inputs. The choice of provider is an architectural one.

| Provider | Best for | Trade-off |
|---|---|---|
| **Merge fields and related lists** | Straightforward record data such as account name, case status, or recent activities | Simple and declarative, but limited to what the bound records expose |
| **Flow** | Computed context, branching logic, data from several sources, external callouts | Low-code and admin-friendly, but complex logic becomes hard to maintain |
| **Apex** | Data from SOQL or external APIs, programmatic filtering, well-formatted JSON | Most control and most testable, but needs developers |
| **Retriever (Data 360)** | Unstructured knowledge such as articles, manuals, FAQs | Depends on index and retriever quality |

A practical rule: **start with merge fields, escalate to Flow when you need logic, escalate to Apex when you need control.** Every escalation adds maintenance cost, so pay it only when the simpler provider cannot do the job.

Prompt Builder also has documented limits on how many resources a template can use. Treat them as a design constraint and check the current numbers in "Prompt Builder Limits" in Salesforce Help.

---

## 4. Grounding With Flow and Apex: Design Principles

Flow and Apex resources share the same idea: **the template passes its inputs to your logic, and your logic returns text that becomes part of the prompt.** The template does not care how that text was produced. That makes the resource a contract, and contracts deserve deliberate design.

### 4.1 How the Contract Works

- **Flow** uses a dedicated prompt-flow type that receives the template's inputs. The flow gathers or computes data and appends it to the prompt, which lets admins build grounding logic without code.
- **Apex** uses an invocable method. Its inputs mirror the template's inputs, and **each input name must match the template input's API name exactly**. The method returns a single text value that Prompt Builder inserts into the prompt.

One historical note matters if you read older tutorials: Apex resources used to bind to Flex templates through a dedicated capability type. **That capability type is now retired**, so examples that still rely on it need to be updated.

### 4.2 Principles for Resource Output

Whatever tool produces the text, the same principles decide whether the model can use it well.

| Principle | Why it matters |
|---|---|
| **Bound the output** | Cap the number of records and the length of long text fields. Unbounded dynamic text is the most common cause of slow, expensive, and unfocused responses. |
| **Return an explicit empty state** | "No open cases were found" lets the model say so. Silence invites the model to improvise. |
| **Select, don't dump** | Return only the fields the task needs, not whole records. Every extra field is cost and distraction. |
| **Use a compact, consistent format** | One line per item, in a fixed order, is easier for the model to parse than a pretty-printed record dump. |
| **Respect data access** | Grounding text should contain only what the running user is allowed to see. Make the security context explicit in your logic rather than assuming it. |

### 4.3 Operational Cautions

- **Treat resource inputs as a public contract.** Changing the inputs of an Apex class that a template uses breaks the template, and you cannot save new versions until it is fixed.
- **Plan for debugging.** Logic hidden inside a resource is invisible in the final prompt unless you inspect it. Test the resource output on its own before judging the model's answer.

---

## 5. Writing the Instructions

Instructions are the part developers spend the least structured effort on, and where most inconsistency comes from. A reliable pattern has five blocks:

```text
ROLE
You are a support operations assistant for <company>.

TASK
Write a briefing for the agent who is about to contact this customer.

CONSTRAINTS
- Use only the information in the CONTEXT section.
- If information is missing, write "Not available" for that item.
- Do not speculate about causes or promise outcomes.

OUTPUT FORMAT
1. One-sentence situation summary
2. Up to three open issues, ordered by priority
3. One recommended next step

CONTEXT
Account: <account merge field>
<Flow or Apex resource output>
```
