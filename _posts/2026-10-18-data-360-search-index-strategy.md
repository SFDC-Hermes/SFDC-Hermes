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

## 2. The Art of Chunking: Semantic vs. Window-Based

When you ingest unstructured data into a DMO, you cannot hand the entire document to the LLM. It must be split into smaller units, each of which is embedded as its own vector. The chunk is the **atomic unit of retrieval**: the agent can only find and quote what a single chunk contains.

Chunking is a trade-off between two forces:

- **Precision:** smaller chunks produce vectors about one specific idea, so they match specific queries sharply.
- **Context:** larger chunks keep the surrounding explanation intact, so the LLM has enough to answer correctly.

Data Cloud offers two primary families of strategies.

### 2.1 Window-Based Chunking (Fixed Size)

This strategy splits text at paragraph or sentence boundaries into sections of a target size, with a configurable overlap between neighbors.

| Chunk size | Strengths | Weaknesses | Best for |
|---|---|---|---|
| **Small** (e.g., ~256 tokens) | Highly precise; one vector ≈ one thought | Lacks surrounding context; answers may be incomplete | Dense FAQs, glossaries, short plain-text records |
| **Medium** (e.g., ~512 tokens) | Balanced; usually a sensible default | Needs validation against real queries | General policy and how-to content |
| **Large** (e.g., 1,024 tokens; needs a long-context model such as SFR V2) | Preserves narrative context (e.g., a warning *and* its instruction) | Semantic meaning dilutes when multiple topics share a chunk; more tokens per retrieved result | Long-form narrative, procedures with dependencies |

**On overlap.** Never set overlap to 0. If a critical sentence is split down the middle, neither half carries its full meaning, and the information becomes effectively unretrievable. A common starting point is roughly **10-20% of the chunk size**, then adjust based on evaluation. Be aware of the cost side: overlap increases total chunk count, storage, and the chance that near-duplicate chunks both appear in the top-k.

**A subtle point on units.** Chunk size is a token (or character) budget, not a "topic" budget. Window-based chunking is structure-blind: it will happily put the end of one section and the start of the next into the same vector. That is acceptable for flat text and costly for structured documents, which is precisely where semantic chunking earns its place.

### 2.2 Semantic Chunking and HTML Preprocessing

Instead of cutting by size alone, **semantic chunking** uses the document's inherent structure (such as HTML headings, sections, and lists) so that logically related information stays together. A "Prerequisites" section stays one unit; a troubleshooting table does not get cut between header and rows.

Why it matters for enterprise content:

- **Coherent retrieval units.** Each chunk corresponds to something a human author considered a unit of meaning.
- **Better citations.** When the agent grounds an answer, the cited passage maps to a recognizable section, which makes responses easier to verify.
- **Variable chunk sizes.** Chunks follow the content, so a one-line note and a long procedure are treated appropriately rather than being forced to the same length.

The trade-off is dependence on source quality. If authors use bold text instead of real headings, or paste entire articles as a single `<div>`, there is no structure to exploit and semantic chunking degrades toward arbitrary splitting. **Auditing your content's HTML hygiene is part of the chunking decision.**

### 2.3 Decision Guide

| Source characteristic | Recommended approach |
|---|---|
| Rich-text Knowledge with headings, tables, lists | Semantic chunking |
| Long documents with weak or no structure (PDF text dumps, transcripts) | Window-based, medium-large size, overlap 10-20% |
| Short, self-contained records (FAQ pairs, product snippets) | Window-based, small size, minimal overlap needed because records are already atomic |
| Mixed corpus | Separate indexes per content type, rather than a single compromise configuration |

That last row is underrated. One index per content type costs a little more to manage but lets each corpus use the configuration it actually deserves.

---