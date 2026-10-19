---
layout: single
title: "From Index to Answer: Retriever Design and Grounding in Agentforce"
date: 2026-10-25
categories:
  - Agentforce
tags:
  - Salesforce
  - DataCloud
  - Agentforce
  - RAG
  - Retriever
  - Grounding
  - PromptBuilder
---

In the [previous post]({% post_url 2026-10-18-data-360-search-index-strategy %}) we focused on the ingestion half of RAG: preprocessing, chunking, and embedding models. A well-built Search Index is necessary, but it is not sufficient. Between the index and the agent's answer sits a component that is configured far less deliberately than it deserves: the **retriever**.

The retriever defines *what* is searched, *which fields* come back, *how many* results are returned, and *what the LLM is actually allowed to see*. Two teams can share an identical index and get very different agents purely because of retriever and prompt-level decisions.

> **TL;DR**
> - The index stores vectors. The **retriever** is the query-time contract on top of it: source, filters, returned fields, and result count.
> - Return only the fields the LLM needs (typically the chunk text), plus the metadata you need for citations and debugging.
> - There are two main routes to the agent: an **Agentforce Data Library** configured with a custom retriever, and a **Prompt Builder template** that embeds a retriever as a resource.
> - Validate retrieval at the **prompt template level first**, then wire it into the agent. Debugging inside a full agent conversation hides the cause.
> - Grounding is a prompt contract, not a feature flag: constrain the model to the retrieved context and give it an explicit "I don't know" path.

---

## 1. Where the Retriever Sits

```
 USER QUESTION
      │
      ▼
 ┌──────────────┐   topic / action   ┌───────────────────────────┐
 │ Atlas Engine │ ─────────────────► │ Knowledge action or       │
 │ (reasoning)  │                    │ Prompt template           │
 └──────────────┘                    └─────────────┬─────────────┘
                                                   │ query text
                                                   ▼
                                     ┌───────────────────────────┐
                                     │ RETRIEVER                 │
                                     │  source · filters ·       │
                                     │  fields · result count    │
                                     └─────────────┬─────────────┘
                                                   │ top-k chunks (+ metadata)
                                                   ▼
                                     ┌───────────────────────────┐
                                     │ Prompt = instructions     │
                                     │        + question         │
                                     │        + retrieved chunks │
                                     └─────────────┬─────────────┘
                                                   ▼
                                           LLM → grounded answer
```

Everything the model knows about your enterprise content at answer time is whatever survives this path. If the retriever returns the wrong chunks, or the right chunks wrapped in noise, the model has nothing reliable to be faithful to.

---

## 2. Anatomy of a Retriever

A retriever is created on top of a Search Index (or another data source) and activated before an agent can use it. The settings below are the ones that matter in practice.

| Setting | What it controls | Design guidance |
|---|---|---|
| **Retriever type** | **Individual Retriever** queries one source. **Ensemble Retriever** combines and ranks results from several retrievers. | Start with Individual. Move to Ensemble only when one question genuinely needs several corpora. |
| **Source** | Where the search runs: a Data Space, a Data Model Object, or a **Search Index**. | For RAG over unstructured content, point at the Search Index you designed for that content type. |
| **Filters** | Narrow the candidate set, for example by document attributes. | Use sparingly. Every filter is a way to accidentally return nothing. Prefer a clean index scope over many dynamic filters. |
| **Fields to return** | Which fields come back with each result. | The **chunk text** is the one field the LLM must have. URL, title, source record ID, and data source are useful for citations and debugging. |
| **Number of results** | How many chunks are returned per query. | A default around 20 is a reasonable starting point; tune it with your evaluation set (see section 6). |
| **Citation settings** | Whether source references are available to the answer. | Enable it when users need to verify answers. |

Two points deserve emphasis.

**Fields to return is a prompt-engineering decision.** Every returned field is a candidate for prompt tokens. Returning ten fields "just in case" inflates cost and gives the LLM more irrelevant text to be distracted by. Decide per field: does the model need it to answer, or do I need it to audit the answer?

**Filters trade recall for precision.** A filter that is correct 95% of the time silently removes the right answer for the other 5%. Reserve filters for hard boundaries such as language or audience, and keep soft preferences in the index design.

---
