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

In the previous post, we focused on the ingestion half of RAG: preprocessing, chunking, and embedding models. A well-built Search Index is necessary, but it is not sufficient. Between the index and the agent's answer sits a component that is configured far less deliberately than it deserves: the **retriever**.

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

## 3. Building a Retriever: The Short Version

The exact menu path depends on your release. Some guides place retrievers under **Einstein Studio → Retrievers**, while newer documentation places them under **Agentforce Studio → Data → Retrievers**. The flow is the same:

1. **New Retriever** and choose **Individual Retriever**.
2. Select the data source (Data Cloud), then the **Data Space**, **Source Object**, and **Search Index**.
3. Set filters (start with all documents).
4. Choose **Fields to Return**: at minimum the chunk field. Add title, URL, source record ID, or data source as needed.
5. Enable **Citation Settings** if answers must show their sources.
6. **Save**, then **Activate**. An inactive retriever cannot be used.

> **Note:** Labels and menu locations change between releases. Confirm against the current Salesforce Help before following this literally.

---

## 4. Two Routes From Retriever to Agent

### Route A: Agentforce Data Library with a Custom Retriever

In the agent builder, you create a data library, set its data type to **Custom Retriever**, and select your retriever. The agent then uses it through its knowledge-answering action (the standard **Answer Questions with Knowledge** action).

This route is the fastest to a working agent. It is also the least visible: the prompt that combines instructions, question, and chunks lives in a template you did not write unless you override it.

### Route B: Retriever as a Prompt Builder Resource

In **Prompt Builder**, a retriever is inserted as a **resource** inside the template, typically in a dedicated knowledge section. You configure:

- **Search text:** where the query comes from, for example a free-text input.
- **Output fields:** which retriever fields are rendered into the prompt. For most RAG prompts, this is the chunk field only.

This route gives you full control over the prompt, and it is where you can test retrieval in isolation by previewing the template with a sample query and retriever.

### Which one should you use?

| Situation | Recommended route |
|---|---|
| Standard knowledge Q&A, quick start | Route A with the default behavior, then validate quality |
| FAQ-style content, strict answer format, or the default answers feel off | Route B: own the template, then connect it to the agent |
| Need to experiment with models, languages, or instructions | Route B: preview in Prompt Builder before touching the agent |

The practical lesson from teams that have done this at scale: **the default knowledge template is a starting point, not a final design.** Overriding the default retriever and template is normal for domain-specific content.

---

## 5. Grounding Is a Prompt Contract

A retriever supplies context. **Grounding** is the instruction that forces the model to stay inside it. Without that instruction, the LLM blends retrieved text with its general knowledge, and the answer looks authoritative either way.

A minimal grounding prompt has four parts:

```text
You are a support assistant for <product>.

Answer the QUESTION using only the information in the KNOWLEDGE section.
If the KNOWLEDGE section does not contain the answer, say that you could
not find it. Do not guess and do not use outside knowledge.
When you state a fact, mention the source title if one is provided.

QUESTION:
<user query input>

KNOWLEDGE:
<retriever resource, output field: chunk>
```

Variable and resource names in Prompt Builder are generated by your configuration, so treat the placeholders above as illustrative.

Why each part matters:

- **Role and scope** reduce off-topic answers.
- **"Only use KNOWLEDGE"** is the grounding constraint itself.
- **An explicit fallback** gives the model a safe way out. Without it, models tend to fabricate rather than refuse.
- **Citation instruction** works only if the retriever returns title or URL fields and citation settings are enabled.

---

## 6. Validate in Layers

Debugging a wrong answer inside a live agent conversation is slow because five things can be wrong at once: topic selection, action selection, retrieval, prompt, and model. Isolate them in this order:

1. **Retriever level.** Does the correct chunk appear in the results for your golden questions? Inspect the raw returned chunks.
2. **Prompt template level.** Preview the template in Prompt Builder with the same questions. Is the answer faithful to the chunks? Does it refuse when it should?
3. **Agent level.** Only now test through the agent: does it pick the right topic and action, and pass the user's question through correctly?

Reuse the golden question set from the previous post. The same 30-100 questions now test the whole chain, and a failure at layer 1 is never fixed by editing layer 2.

---

## 7. Troubleshooting Guide

| Symptom | Likely cause | First thing to try |
|---|---|---|
| Answer is generic or ignores your content | Retriever returns nothing, or the template is not using the retriever resource | Preview the template with a known question and check the knowledge section is populated |
| Correct article exists but is never retrieved | Chunking or embedding mismatch, or an overly strict filter | Inspect returned chunks; remove filters temporarily; revisit chunk size vs. model limit |
| Answers mix your content with outside facts | No grounding instruction | Add "use only KNOWLEDGE" and an explicit fallback |
| Right facts, wrong or missing citations | Source fields not returned or citations disabled | Add title/URL/source record to fields to return; enable citation settings |
| Responses are slow or expensive | Too many results or too many returned fields | Reduce number of results; return only the chunk field |
| Agent answers FAQ questions poorly with the default setup | The default knowledge template and retriever are too generic | Build a custom retriever and template, then connect through a custom-retriever data library |
| Works in Prompt Builder, fails in the agent | Wiring problem: wrong retriever selected, inactive retriever, or topic/action not routing to the knowledge action | Verify the data library points to the activated retriever; test topic routing separately |

---

## 7. Troubleshooting Guide

| Symptom | Likely cause | First thing to try |
|---|---|---|
| Answer is generic or ignores your content | Retriever returns nothing, or the template is not using the retriever resource | Preview the template with a known question and check the knowledge section is populated |
| Correct article exists but is never retrieved | Chunking or embedding mismatch, or an overly strict filter | Inspect returned chunks; remove filters temporarily; revisit chunk size vs. model limit |
| Answers mix your content with outside facts | No grounding instruction | Add "use only KNOWLEDGE" and an explicit fallback |
| Right facts, wrong or missing citations | Source fields not returned or citations disabled | Add title/URL/source record to fields to return; enable citation settings |
| Responses are slow or expensive | Too many results or too many returned fields | Reduce number of results; return only the chunk field |
| Agent answers FAQ questions poorly with the default setup | The default knowledge template and retriever are too generic | Build a custom retriever and template, then connect through a custom-retriever data library |
| Works in Prompt Builder, fails in the agent | Wiring problem: wrong retriever selected, inactive retriever, or topic/action not routing to the knowledge action | Verify the data library points to the activated retriever; test topic routing separately |

---

## 8. Production Checklist

- [ ] Retriever is **activated** and the agent's data library points to the right one.
- [ ] **Fields to return** are limited to what the model needs plus audit fields.
- [ ] Filters are minimal and each one has a documented reason.
- [ ] Number of results is tuned against the golden set, not left at the default by habit.
- [ ] The prompt contains a **grounding constraint** and a **fallback instruction**.
- [ ] Citations are enabled where users must verify answers.
- [ ] Retrieval, prompt, and agent behavior were each validated **separately**.
- [ ] Content-type-specific indexes have their own retrievers.

---

## Conclusion

The index decides what *can* be found. The retriever decides what *is* returned. The prompt decides what the model *does* with it. Treat those as three separate design layers, validate them separately, and most "the agent hallucinated" tickets turn out to be retrieval or prompt bugs that were visible all along.

In the next post, we move one layer up and look at **Prompt Builder and prompt template design**: variables, data resources, template types, and how to structure prompts that stay reliable as your content and models change.

---

### References

- Salesforce Developers: [Create Search Index and Retriever](https://developer.salesforce.com/docs/ai/ground-agentforce-on-website/guide/aes-create-search-index-and-retriever.html)
- Salesforce Ben: [Connecting Agentforce to Data Cloud for Grounding with RAG](https://www.salesforceben.com/connecting-agentforce-to-data-cloud-for-grounding-with-rag/)
