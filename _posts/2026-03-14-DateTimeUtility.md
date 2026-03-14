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

## 🌎 Overview: The GMT Challenge
In Salesforce, the database stores all `DateTime` fields in **GMT (UTC)**. This often creates a gap when filtering data based on a user's local timezone. To solve this, I developed a centralized **DateTimeUtility** class.

## 🚀 Key Features
- **SOQL Optimization:** Precise GMT calculation for Start/End of Day.
- **Context Awareness:** Automatically detects `UserInfo` timezone.
- **Static Utility:** Easy to call from any Trigger or Service Layer.

---

## 💻 Core Implementation

The most critical part of this utility is ensuring **Global Data Integrity** by accounting for timezone offsets during SOQL filtering.

```java
/**
 * @description Calculates the GMT DateTime for the start of the day (00:00:00) in the user's timezone
 */
public static DateTime getStartOfDayInGmt(Date dateValue) {
    if (dateValue == null) return null;
    TimeZone tz = UserInfo.getTimeZone();
    DateTime dtGmt = DateTime.newInstanceGmt(dateValue, Time.newInstance(0, 0, 0, 0));
    Integer offsetMs = tz.getOffset(dtGmt);
    return dtGmt.addSeconds(-offsetMs / 1000);
}

/**
 * @description Converts a GMT DateTime to a formatted string based on a specific user's timezone
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
📂 Source Code & Repository
The full source code, including meta-xml and unit tests, is available in my repository:

👉 View on GitHub

💡 Practical Use Case
When querying records created "Today" for a Korean user (GMT+9), using Date.today() misses the first 9 hours. Use this instead:

Java
DateTime startOfDay = DateTimeUtility.getStartOfDayInGmt(Date.today());
List<Account> accounts = [SELECT Id FROM Account WHERE CreatedDate >= :startOfDay];
This utility is part of my effort to build a "Clean Apex" framework. Feel free to reach out with any questions!