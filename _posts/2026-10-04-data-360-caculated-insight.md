---
layout: single
title: "Weaponizing Data Cloud: Pre-aggregating AI Context with Calculated Insights"
date: 2026-10-04
categories:
  - Development
tags:
  - Salesforce
  - DataCloud
  - Agentforce
  - Architecture
  - CalculatedInsight
  - SQL
---

When transitioning from basic CRM development to AI Agent architecture, the most common point of failure is data volume. 

Imagine a Sub-Agent handling a user request: *"Am I eligible for the VIP discount based on my purchases this year?"* 
If your Apex Action attempts to answer this by running a standard SOQL aggregate query against a raw Data Model Object (DMO) containing 5 million transaction records, the transaction will instantly crash, hitting the **50,000 SOQL Row Limit** or timing out. 

To provide Agentforce with real-time, aggregated intelligence across massive datasets without breaching platform limits, architects must shift the heavy compute loads off the transactional CRM engine. This is achieved using Data Cloud's **Calculated Insights (CI)**.

## 1. The Aggregation Engine: Batch vs. Streaming Insights
Data Cloud provides two distinct analytical engines to process DMOs. Choosing the wrong one results in catastrophic credit consumption and latency issues.
### 1.1 Calculated Insights (Batch CI)
*   **Mechanism:** Executes complex multidimensional ANSI SQL aggregations on a scheduled cadence (e.g., every 6 hours or daily).
*   **Best For:** Heavy historical data analysis, RFM (Recency, Frequency, Monetary) scoring, and customer lifetime value (CLV) calculations.
*   **Cost Efficiency:** Highly optimized. It processes billions of rows efficiently without continuous compute drain.
