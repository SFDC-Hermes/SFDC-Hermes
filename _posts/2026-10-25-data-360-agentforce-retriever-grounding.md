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

The retriever defines *what* is searched, *which fields* come back, *how many* results are returned, and *what the LLM is actually allowed to see*. Two teams can share an identical index and get very different agents purely because of retriever and prompt-level decisions.

> **TL;DR**
> - The index stores vectors. The **retriever** is the query-time contract on top of it: source, filters, returned fields, and result count.
> - Return only the fields the LLM needs (typically the chunk text), plus the metadata you need for citations and debugging.
> - There are two main routes to the agent: an **Agentforce Data Library** configured with a custom retriever, and a **Prompt Builder template** that embeds a retriever as a resource.
> - Validate retrieval at the **prompt template level first**, then wire it into the agent. Debugging inside a full agent conversation hides the cause.
> - Grounding is a prompt contract, not a feature flag: constrain the model to the retrieved context and give it an explicit "I don't know" path.
