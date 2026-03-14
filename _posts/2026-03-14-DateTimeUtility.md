---
layout: single
title: "Salesforce Apex: Mastering Global Timezone Conversions"
date: 2026-03-14
categories:
  - SFDC-Apex
tags:
  - Apex
  - Salesforce
  - Timezone
  - CleanCode
---

Salesforce stores all `DateTime` fields in **GMT (UTC)**. While consistent, this creates a gap when filtering data for global users. To bridge this, I’ve centralized the logic into a robust **DateTimeUtility**.

---

## 🚀 Key Features

* **SOQL Optimization:** Precise GMT calculation for Start/End of Day.
* **Context Awareness:** Automatically detects the current user's timezone.
* **Clean API:** Static methods designed for readability and reuse.

---

## 💻 Core Implementation

The most critical part of this utility is ensuring **Global Data Integrity** by accounting for timezone offsets during SOQL filtering.

```java
/**
 * @description Calculates the GMT DateTime for the start of the day (00:00:00) 
 * in the user's local timezone.
 */
public static DateTime getStartOfDayInGmt(Date dateValue) {
    if (dateValue == null) return null;

    TimeZone tz = UserInfo.getTimeZone();
    DateTime dtGmt = DateTime.newInstanceGmt(dateValue, Time.newInstance(0, 0, 0, 0));
    Integer offsetMs = tz.getOffset(dtGmt);

    return dtGmt.addSeconds(-offsetMs / 1000);
}

/**
 * @description Converts a GMT DateTime to a formatted string based on a specific user's timezone.
 */
public static String toDateTimeInUserTimezoneFormatted(DateTime datetimeValue, String userId) {
    if (datetimeValue == null) return null;
    
    TimeZone tz;
    if (String.isBlank(userId)) {
        tz = UserInfo.getTimeZone();
    } else {
        List<User> users = [SELECT TimeZoneSidKey FROM User WHERE Id = :userId LIMIT 1];
        tz = (!users.isEmpty()) ? TimeZone.getTimeZone(users[0].TimeZoneSidKey) : UserInfo.getTimeZone();
    }

    return datetimeValue.format('yyyy-MM-dd HH:mm:ss', tz.getId());
}
💡 Practical Use Case
When querying records created "Today" for a Korean user (GMT+9), using a standard Date misses the first 9 hours. This utility ensures you capture every record correctly.

Java
// Professional way to filter SOQL by User's local today
DateTime startOfDay = DateTimeUtility.getStartOfDayInGmt(Date.today());

List<Account> accounts = [
    SELECT Id, Name 
    FROM Account 
    WHERE CreatedDate >= :startOfDay
];
📂 Source Code & Repository
The full class definition, including meta-xml and unit tests, is available in my repository.

👉 View Full Class on GitHub

This utility is part of my continuous effort to build a "Clean Apex" framework. Feel free to reach out with any questions!