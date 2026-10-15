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
toc: true
toc_sticky: true
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

## 3. Selecting the Right Embedding Model

Once chunked, text is converted into numerical vectors. In the Data Cloud Search Index setup, you choose the embedding model, and that choice affects retrieval relevance, the maximum chunk size you can safely use, latency, and cost.

Two rules apply to every option below:

1. **Query and document embeddings must come from the same model.** Vectors from different models live in different spaces and are not comparable.
2. **Changing the model means re-embedding the entire corpus.** Decide deliberately, and prototype on a representative sample first.

The catalog is small and focused. At the time of writing, there are four options: **SFR V2**, **E5-large-v2**, **Multilingual-E5-large**, and **CLIP**.

### Option 1: The Long-Context Flagship (SFR V2 / `SFR-v2-small`, Salesforce Research)

- **Best for:** Content-rich documents where preserving long passages matters, and teams that want the strongest general-purpose relevance in the catalog.
- **Characteristics:** Developed by Salesforce Research. It offers a high degree of embedding resolution and better semantic relevance, and it supports inputs of up to roughly **8,000 tokens**, far beyond the E5 family.
- **Why the context window matters:** A larger input limit lets you use large chunks, or semantic chunks that follow long sections, without silent truncation. It is the natural pairing for structured Knowledge Articles whose sections are long.
- **Trade-off:** Larger chunks mean more tokens per retrieved result and more topic dilution if the content is not well structured. A big context window is permission to use big chunks, not a reason to.

### Option 2: The English Workhorse (`E5-large-v2`)

- **Best for:** Single-language (English) environments with moderate-length content.
- **Characteristics:** A text embedding model supporting up to **512 tokens**. Solid, well-understood retrieval quality for English queries.
- **Trade-off:** The 512-token ceiling is a hard design constraint. Any chunk longer than that is truncated, and the tail of the chunk never makes it into the vector.

### Option 3: The Multilingual Model (`Multilingual-E5-large`)

- **Best for:** Global enterprise rollouts.
- **Characteristics:** E5 (EmbEddings from bidirEctional Encoder rEpresentations) maps multiple languages into the *same* vector space, also with a **512-token** limit. A user can ask a question in Korean and retrieve the relevant chunk from an English manual, because the semantic meaning aligns across languages.
- **Practical tip:** E5-family models are trained with instruction-style prefixes (`query:` and `passage:`). Confirm how the platform handles this so queries and documents are embedded consistently.
- **Trade-off:** The same 512-token ceiling as E5-large-v2. If your content is English-only, the multilingual capacity is capability you are not using.

### Option 4: The Multimodal Model (CLIP)

- **Best for:** Corpora where meaning lives in images, charts, diagrams, or scanned documents.
- **Characteristics:** CLIP embeddings are used for image content in the multimodal search pipeline. Combined with OCR and LLM-generated captions (GPT-4o captioning), images, charts, and scanned documents become searchable vector content rather than invisible files.
- **Trade-off:** Image understanding adds processing steps (OCR, captioning), so ingestion is heavier and retrieval quality depends on the quality of those intermediate outputs. Test with your real documents, not clean samples.

### Comparison at a Glance

| Model | Max input | Languages | Best fit | Watch out for |
|---|---|---|---|---|
| **SFR V2** (`SFR-v2-small`) | ~8,000 tokens | See model card | Long, structured documents; highest relevance goal | Oversized chunks diluting meaning |
| **E5-large-v2** | 512 tokens | English | English-only knowledge, moderate chunk sizes | Truncation above 512 tokens |
| **Multilingual-E5-large** | 512 tokens | Multilingual | Global, cross-lingual retrieval | Truncation above 512 tokens |
| **CLIP** | n/a (image) | n/a | Images, charts, scanned documents | Heavier ingestion; OCR/caption quality |

> Specifications come from Salesforce Help's Search Index reference and the Data 360 release highlights, and they change between releases. Verify against the current documentation before you commit to a design.

### Chunk Size and Model Must Be Chosen Together

This is the most important consequence of the table above. **A chunk larger than the model's input limit is truncated, and the vector represents only the part the model actually saw.** No dashboard flags it; retrieval just gets quietly worse.

| Model | Practical chunk-size guidance |
|---|---|
| E5-large-v2 / Multilingual-E5-large | Keep chunks comfortably **under 512 tokens**, including any title and heading text attached to the chunk. Large 1,024-token chunks are not an option here. |
| SFR V2 | Large chunks and long semantic sections are viable, but size them by *topic coherence*, not by the maximum. |

If you use semantic chunking with an E5 model, check how long your longest sections are. A single 900-token "Troubleshooting" section will be cut off at 512.

---

## 4. Beyond the Basics: Retrieval-Side Settings That Interact With Your Index

A great index can still underperform if retrieval is naive. Three levers are worth knowing about when designing the full pipeline. Availability and naming vary by release, so check what your org exposes.

- **Hybrid search (vector + keyword).** Pure vector search is excellent at meaning and weak at exact tokens such as product SKUs, error codes, and policy numbers. Combining semantic and keyword matching typically improves recall on identifier-heavy queries.
- **Metadata filtering (prefilters).** Narrow the candidate set *before* similarity ranking: by language, product line, region, audience, or article status. This improves precision, reduces cost, and is often the cleanest way to enforce "customers must not see internal-only content."
- **Top-k and reranking.** Retrieving more candidates and then reranking them with a stronger relevance model often beats simply increasing k. More retrieved chunks also means more prompt tokens and more room for the LLM to be distracted.

---

## 5. Architecting the Final Index

Building the Search Index is the final act of data preparation. A senior architect looks at the source data and makes calculated pairings rather than accepting defaults.

**Scenario A: Rich-text Knowledge Articles with complex tables, global audience**
Semantic chunking on cleaned HTML, paired with `Multilingual-E5-large` and language and article-status prefilters. Cross-lingual retrieval works, but sections must stay under 512 tokens, so audit your longest sections first. If many sections run longer, SFR V2 gives you room to keep tables and their context together.

**Scenario B: Plain-text internal chat logs, high volume, speed-sensitive**
Window-based chunking with a modest chunk size (well under 512 tokens) and light overlap, paired with `E5-large-v2` if the logs are English. There is no structure to exploit, volume is high, and the cost of an occasional imperfect match is low.

**Scenario C: Short FAQ pairs in a single language**
Window-based chunking sized so each Q&A pair stays in one chunk, with `E5-large-v2` for English content. Each pair is short, so the 512-token limit is not a concern.

**Scenario D: Manuals with diagrams, charts, or scanned pages**
Enable the multimodal path with CLIP so that images are indexed through OCR and captioning. Test retrieval on a handful of real scanned pages before rolling it out.

---

## 6. Measure It: Treat the Index as a System Under Test

The most common reason RAG projects stall is that nobody can say whether a change made things better. Replace opinions with a small evaluation harness:

1. **Build a golden set** of 30-100 realistic questions, each mapped to the source article or section that should answer it. Include multilingual, ambiguous, and identifier-style queries.
2. **Measure retrieval first, generation second.** For each question, check whether the correct chunk appears in the top-k (recall@k) and how high it ranks. If retrieval is wrong, fixing the prompt is wasted effort.
3. **Change one variable at a time:** chunk size, overlap, model, hybrid on/off. Keep a simple log of configuration versus result.
4. **Inspect failures by hand.** Read the actual retrieved chunks. Most problems become obvious within minutes: a chunk cut mid-table, a missing heading, boilerplate winning the ranking.
5. **Re-run after content changes.** Index quality drifts as source content evolves.

### Common Pitfalls

- Defaulting to one giant index for every content type.
- Setting overlap to zero, or to such a large value that duplicates flood the results.
- Letting chunks exceed the model's input limit (512 tokens for the E5 models), which silently truncates content.
- Indexing archived or draft content.
- Tuning prompts to compensate for retrieval failures.
- Switching embedding models without a full re-index, or comparing vectors across models.

---

## Conclusion

Agentforce is only as intelligent as the data you feed it. The Atlas Reasoning Engine can only reason over what retrieval hands it, and retrieval can only return what the index preserved. By mastering the parsing, chunking, and embedding pipeline, and by validating it with a real evaluation set, you ensure that when Atlas fires a retrieval action, it receives exactly the pristine, well-scoped context it needs.

Get the foundation right once, and every prompt, topic, and action built on top of it gets better for free.