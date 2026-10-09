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