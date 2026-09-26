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

### 1.2 Streaming Insights
*   **Mechanism:** Processes micro-batches of events in near real-time as they flow through a Data Stream, using a time-windowed approach (e.g., "Rolling 5-minute window").
*   **Best For:** Immediate trigger events (e.g., detecting if a user abandoned a cart 5 minutes ago).
*   **Cost Efficiency:** Extremely credit-intensive. Using streaming insights for standard metric aggregation will rapidly deplete your Data Cloud credit allocation.

## 2. Designing a CI SQL Pipeline

Calculated Insights are defined using standard **ANSI SQL**, not SOQL. This allows you to leverage powerful window functions and complex joins across unified profiles.

Below is an enterprise-grade CI SQL definition. It takes millions of raw sales order rows, joins them with the unified individual profile, and outputs a highly compressed analytical metric: Total Spend, Last Purchase Date, and a dynamic VIP Tier.

```sql

SELECT
    UnifiedIndividual__dlm.Id__c AS CustomerId__c,
    SUM(SalesOrder__dlm.GrandTotalAmount__c) AS Total_Spend__c,
    MAX(SalesOrder__dlm.CreatedDate__c) AS Last_Purchase_Date__c,
    CASE
        WHEN SUM(SalesOrder__dlm.GrandTotalAmount__c) >= 50000 THEN 'VIP'
        WHEN SUM(SalesOrder__dlm.GrandTotalAmount__c) >= 10000 THEN 'Gold'
        ELSE 'Standard'
    END AS Customer_Tier__c,
    UnifiedIndividual__dlm.Id__c 
FROM SalesOrder__dlm
JOIN UnifiedIndividual__dlm 
    ON SalesOrder__dlm.PartyId__c = UnifiedIndividual__dlm.Id__c
GROUP BY UnifiedIndividual__dlm.Id__c
```

## 3. Bridging the CI to Agentforce Actions

Once the CI is active, the aggregated result is materialized as a highly indexed virtual object (`<CIName>__cio`). Because this object is already pre-calculated, querying it is lightning fast.

However, standard SOQL cannot query `.cio` objects effectively. To expose this data to an Agentforce Sub-Agent, you must build an Apex Action that utilizes the **ConnectApi** to fetch the exact row needed, completely bypassing standard CRM governor limits.

```apex
public with sharing class CustomerInsightAction {

    @InvocableMethod(label='Get A')
    public static List<InsightResponse> getCustomerA(List<String> recordIds) {
        
        // 1. Construct the Data Cloud Query using ConnectApi
        ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
        queryInput.sql = 'SELECT Total_Spend__c, Customer_Tier__c FROM Customer_RFM_Insight__cio WHERE CustomerId__c = \'' + recordIds[0] + '\'';
        
        // 2. Execute the query against the Data Cloud compute layer
        ConnectApi.CdpQueryOutput output = ConnectApi.Cdp.queryDataCloud(queryInput);
        
        // 3. Parse the dynamic response
        InsightResponse result = new InsightResponse();
        if (output.data != null && !output.data.isEmpty()) {
            Map<String, Object> row = (Map<String, Object>) output.data[0];
            result.totalSpend = (Decimal) row.get('Total_Spend__c');
            result.customerTier = (String) row.get('Customer_Tier__c');
        }
        
        // Return a lightweight, structured context to the Sub-Agent's ReAct loop
        return new List<InsightResponse>{ result };
    }

    public class InsightResponse {
        @InvocableVariable public Decimal totalSpend;
        @InvocableVariable public String customerTier;
    }
}

```

