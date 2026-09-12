---
layout: single
title: "Salesforce Data 360 Architecture: Decoding Data Streams, DLOs, DMOs, Queries & Pricing"
date: 2026-09-20
categories:
  - Development
tags:
  - Salesforce
  - Data 360
  - Architecture
  - DataStream
  - DLO
  - DMO
---

When building advanced AI Agents like **Agentforce** or designing complex multi-system integrations, writing standard SOQL inside Salesforce is no longer enough. Enterprise architectures require a unified data layer capable of ingesting petabytes of structured and unstructured data, harmonizing it, and serving it in real time. This layer is **Salesforce Data Cloud**.

To master Data Cloud, an architect must understand how raw data flows from external sources into harmonized models, how to query them efficiently, and how platform usage translates into financial costs. 

This guide breaks down the core data pipeline (**Data Stream ➔ DLO ➔ DMO**), query patterns, and the Data Cloud credit consumption model.

## 1. The Core Pipeline: Data Stream, DLO, and DMO Relationships

Data in Data Cloud does not magically appear in a usable state. It flows through a strict, multi-tier pipeline that transforms raw external records into standardized, unified business entities.

```text
┌────────────────────────┐        Ingests       ┌──────────────────────┐        Maps         ┌──────────────────────┐
│  External Data Source  │ ───────────────────► │  Data Lake Object    │ ──────────────────► │ Data Model Object    │
│  (CRM, S3, Snowflake)  │                      │       (DLO)          │                     │       (DMO)          │
└────────────────────────┘                      └──────────────────────┘                     └──────────────────────┘
    (Data Stream)                                (Raw / Tabular Schema)                       (Harmonized / Unified)
```

### 1.1 Data Streams (The Ingestion Pipeline)

A Data Stream is the active configuration that connects an external data source (such as Salesforce CRM, AWS S3, Marketing Cloud, or an external database) to Data Cloud.
It handles scheduling (Batch) or near-real-time streaming.
Every Data Stream writes its incoming data directly into a corresponding DLO.

### 1.2 DLO (Data Lake Object): The Raw Storage Layer

A DLO (Data Lake Object) is a physical, tabular storage container inside the Data Cloud data lake.
Structure: A DLO strictly mirrors the schema of the incoming source dataset. If your source CSV or API payload has 10 columns, the DLO will store those exact 10 columns.
Role: It acts as the raw staging ground. No identity resolution or complex cross-object joining happens at the DLO level.


### 1.3 DMO (Data Model Object): The Harmonized Semantic Layer

A **DMO** (Data Model Object) is a virtual, harmonized business entity (e.g., *Individual*, *Account*, *Order*, *Engagement*) that maps to one or more DLOs.

* **The Mapping Step:** After data lands in a DLO, developers perform **Data Mapping**—linking source DLO fields (e.g., `cust_first_name`) to standard target DMO attributes (e.g., `Individual.FirstName`).
* **Why DMOs Matter:** Features like **Segmentation, Identity Resolution (Profile Unification), and Agentforce Grounding** do not look at DLOs; they operate strictly on DMOs. Multiple DLOs (e.g., Web Signups and In-Store POS data) can be mapped into a single unified `Individual` DMO.

---

## 2. Querying & Calling Data Cloud: How to Fetch Data

Once your data is modeled into DMOs, how do external systems, Apex code, or AI agents pull that data? Data Cloud provides distinct mechanisms depending on the latency and architecture required.

### 2.1 ANSI SQL via Data Cloud Query API (REST API)

For heavy analytical queries, reporting, or external system integration, Data Cloud provides a native **ANSI SQL Query API**.

* **Endpoint:** `/services/data/v61.0/ssot/query`
* **Example Query:**
```sql
SELECT 
    SSOT__Customer__dlm.SSOT__FirstName__c, 
    SSOT__Customer__dlm.SSOT__Email__c 
FROM 
    SSOT__Customer__dlm 
WHERE 
    SSOT__Customer__dlm.SSOT__Country__c = 'KR'
LIMIT 100;

```


* **Use Case:** Pulling aggregated customer insights or searching large datasets asynchronously.

### 2.2 Real-time Data Graph API

For low-latency interactions (such as an Agentforce Agent needing instant customer context mid-conversation), Data Cloud exposes **Data Graphs**.

* Instead of writing complex SQL joins on the fly, a Data Graph pre-links a Profile DMO with its related Engagement and Order DMOs into a hierarchical graph tree.
* When invoked, it returns a hyper-fast JSON payload containing the unified customer profile and their recent history in milliseconds.

### 2.3 Zero-Copy Queries (BYOL)

If your enterprise data resides in AWS Redshift, Snowflake, or Google BigQuery, you don't even need to ingest it into Data Cloud storage.

* Using **Zero-Copy Data Federation**, Data Cloud queries the external data lake directly via virtualized connections. The query engine pushes computation down to the external data warehouse and streams back only the requested result set.

---

