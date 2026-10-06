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
  - Architecture
---

When building a Retrieval-Augmented Generation (RAG) architecture in Agentforce, developers often obsess over the runtime—how the Atlas Reasoning Engine formulates its prompt. However, RAG is fundamentally a two-phase architecture: **Data Preparation (Ingestion)** and **Runtime (Retrieval)**.

If you fail to configure your Data Cloud Search Index correctly during the preparation phase, your agent will retrieve garbage data. No amount of prompt engineering can fix a poorly chunked or improperly embedded vector. 

This guide breaks down the critical decisions architects must make in the Data Cloud UI when building a Search Index: **Chunking Strategies, HTML Preprocessing, and Embedding Model Selection.**

## 1. The Art of Chunking: Semantic vs. Window-Based

When you ingest unstructured data (like a Knowledge Article with rich text or a web page) into a Data Model Object (DMO), you cannot feed the entire document to the LLM at once. It must be chopped into smaller, digestible vectors.
Data Cloud offers two primary chunking strategies to handle this:

### 1.1 Window-Based Chunking (Fixed Size)

This strategy splits text based on paragraph or sentence levels into fixed, manageable sections.
* **Small Chunks (e.g., 256 size):** Highly precise. The vector represents a very specific thought. However, it lacks surrounding context. Best for dense FAQs or plain-text logs.
* **Large Chunks (e.g., 512 - 1024 size):** Preserves narrative context (e.g., a warning label and the instruction together). The downside is that semantic meaning can get diluted if multiple topics exist in one chunk.
*Architect's Note on Overlap:* Never set your overlap to 0. If a critical sentence is split right down the middle, the semantic meaning is destroyed. Always configure an overlap to preserve the narrative thread.

### 1.2 Semantic Chunking & HTML Preprocessing

Instead of blindly cutting text by token count, **Semantic Chunking** relies on the document's inherent structure (like HTML headings) to keep logically related information together.
