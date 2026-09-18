---
layout: single
title: "Inside the Atlas Reasoning Engine: Sub-Agents, ReAct Loops, and Execution Architecture"
date: 2026-09-27
categories:
 - Development
tags:
 - Salesforce
 - Agentforce
 - AtlasEngine
 - SubAgent
 - Architecture
 - ReAct
---

A common misconception among developers transitioning to AI is treating Salesforce Agentforce as a simple wrapper around a Large Language Model (LLM). In reality, throwing raw user prompts at an LLM alongside 50 enterprise APIs results in catastrophic hallucinations, context window overflow, and non-deterministic behavior.
The true core of Agentforce is the **Atlas Reasoning Engine**. Atlas is not a language model; it is an autonomous orchestrator—a complex state machine built on the **ReAct (Reasoning + Acting)** paradigm. It dynamically manages conversational state, delegates tasks to specialized domains, and strictly controls the metadata injected into the LLM's prompt.
To build enterprise-grade agents, architects must understand how Atlas routes intents, manages memory, and executes actions.

## 1. The Routing Architecture: Main Agent to Sub-Agents

Previous iterations of conversational AI relied on rigid NLP intent mapping or flattened "Topics." Agentforce has evolved into a hierarchical **Multi-Agent Architecture**.
When a user initiates a conversation, they are interacting with the **Main Agent** (e.g., the Copilot or Service Agent). The Main Agent does not execute business logic directly. Its primary job is semantic routing: classifying the user's intent and delegating the conversation to a specialized **Sub-Agent**.
*   **The Main Agent:** Evaluates the initial prompt against the descriptions of all available Sub-Agents.
*   **The Sub-Agent (Domain Expert):** A specialized boundary containing its own specific Instructions and a restricted pool of Actions (e.g., an *Order Management Sub-Agent* vs. a *Technical Support Sub-Agent*).
**Architectural Imperative:**
Sub-Agent descriptions must be mutually exclusive. If a *Billing Sub-Agent* and a *Contract Sub-Agent* both have instructions mentioning "invoice adjustments," Atlas will experience a routing collision (Ambiguity Fallback), forcing the engine to halt and ask the user for clarification rather than acting autonomously.

## 2. The ReAct Loop: Anatomy of an Execution

Once Atlas hands the context over to the appropriate Sub-Agent, it enters the **ReAct Loop**. This is where probabilistic AI meets deterministic execution.
Instead of immediately generating a final response, Atlas loops through three distinct phases:
1.  **Thought (Reasoning):** The engine analyzes the user's request against the Sub-Agent's instructions and the available Action descriptions. *("The user wants to cancel Order #123. I must first check the order status using `Get_Order_Status`, then verify if it is eligible for cancellation.")*
2.  **Action (Execution):** Atlas structures a JSON payload and fires the selected declarative tool (an Apex `@InvocableMethod`, a Flow, or a Data Cloud Vector Search).
3.  **Observation (Ingestion):** The system waits for the execution result. Atlas ingests the returned payload and evaluates it. If the goal is met, it breaks the loop and generates the final response. If the data is incomplete, it initiates another Thought phase.
---**
