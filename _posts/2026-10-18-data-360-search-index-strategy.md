---
layout: single
title: "The RAG Pipeline Deconstructed: Advanced Chunking Strategies and Embedding Models"
date: 2026-10-18
categories:
  - Agentforce
tags:
  - Salesforce
  - DataCloud
  - Agentforce
  - RAG
  - Embeddings
  - Chunking
  - Architecture
---

When building a Retrieval-Augmented Generation (RAG) architecture in Agentforce, developers often obsess over the runtime: how the Atlas Reasoning Engine formulates its prompt, which topics and actions get selected, how instructions are phrased. That focus is understandable, but it overlooks where most RAG quality is actually decided.

RAG is fundamentally a two-phase architecture: **Data Preparation (Ingestion)** and **Runtime (Retrieval)**. The quality ceiling of the second phase is set by the first. If the Data Cloud Search Index is configured poorly, the agent retrieves noise, and no amount of prompt engineering can recover information that was destroyed at indexing time.

> **TL;DR**
> - Chunking determines *what a vector represents*. Embedding determines *how queries are matched to it*. Both are effectively one-way doors: changing either means re-indexing.
> - Match chunking to document structure (semantic for structured rich text, window-based for flat text), and never use zero overlap.
> - Pick the embedding model by modality, language coverage, and maximum input length: SFR V2 for long context, the E5 models for chunks under 512 tokens, CLIP for images.
> - Treat the index as a measurable system: build a golden question set and evaluate retrieval *before* you tune prompts.

---

## 0. The Big Picture: Where Quality Is Decided

```
 INGESTION (once, and on every content change)          RUNTIME (every turn)
 ┌────────┐  ┌────────┐  ┌────────┐  ┌────────────┐     ┌───────────┐  ┌─────────┐  ┌───────┐
 │ Source │→ │ Parse/ │→ │ Chunk  │→ │ Embed →    │ ... │ Query     │→ │ Retrieve│→ │ Atlas │
 │  DMO   │  │ Clean  │  │        │  │ Vector idx │     │ embedding │  │ top-k   │  │ + LLM │
 └────────┘  └────────┘  └────────┘  └────────────┘     └───────────┘  └─────────┘  └───────┘
        ▲ decisions in this half are expensive to reverse ▲
```

Every decision on the left side of that diagram is made once, silently, and then inherited by every conversation. A bad chunk boundary is not a bug you see in a stack trace; it shows up as an agent that is *confidently* slightly wrong. That is why this half of the pipeline deserves architect-level attention.

This guide covers the critical decisions in the Data Cloud UI when building a Search Index: **parsing and preprocessing, chunking strategy, and embedding model selection**, plus the retrieval-side settings that interact with them.

> **Note:** Data Cloud and Agentforce ship three releases a year, and option names and available models change. Treat the specific labels below as illustrative and confirm them against the current release notes and the Search Index reference in Salesforce Help before committing to a design.

---

## 1. Preprocessing: Garbage In, Garbage Vectors

Before any chunking happens, the source must be turned into clean text. For Knowledge Articles and web content stored as rich text in a Data Model Object (DMO), that means dealing with HTML.

Common failure modes:

| Problem | Effect on retrieval |
|---|---|
| Navigation, footers, cookie banners in crawled pages | Boilerplate dominates the vector; unrelated queries match every page |
| Tables flattened into run-on text | Row/column relationships are lost; "Plan A limit is 5 GB" becomes ambiguous |
| Inline styling and script remnants | Wasted tokens, diluted embeddings |
| Duplicate or near-duplicate articles (versions, translations) | Top-k filled with redundant chunks, crowding out distinct evidence |

**Architect's checklist before indexing:**

1. Index only the fields that carry meaning (title, body, summary), not every column on the DMO.
2. Keep the **title and section heading attached to each chunk** (either through semantic chunking or by including them in the indexed text). A chunk that says "Set the value to 30" is useless without knowing *what* is being set.
3. Filter to published, current-version, correct-channel records at the source. It is much cheaper to exclude archived articles from the index than to explain why the agent quoted a retired policy.

---