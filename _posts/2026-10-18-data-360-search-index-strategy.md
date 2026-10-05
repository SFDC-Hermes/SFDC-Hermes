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