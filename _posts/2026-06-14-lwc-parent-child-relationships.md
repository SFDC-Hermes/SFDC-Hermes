---
layout: single
title: "Salesforce Concept about Parent-Child Relationships in LWC"
date: 2026-06-07
last_modified_at: 2026-11-05
categories:
  - Concepts
tags:
  - LWC
  - Salesforce
  - JavaScript
  - UI/UX
  - Modeling
---

When building complex, enterprise-grade user interfaces in Lightning Web Components (LWC), modularity is key. Instead of creating massive, monolithic components that are difficult to test and maintain, modern UI modeling encourages breaking the interface down into smaller, decoupled pieces.

This requires a deep understanding of component composition—specifically, how parent and child components communicate and who owns the state.

In the LWC framework, component relationships follow a strict, predictable architectural contract: **"Data Down, Events Up."** Mastering this directional data flow is essential for system predictability, consistent UI/UX behavior, and performance across your Salesforce application.

---

## 1. The Architectural Pattern: "Data Down, Events Up"

To keep state predictable, LWC enforces a strict unidirectional data flow. There is no two-way data binding between components. Data travels down through public properties, and changes travel up through events.

```text
+------------------------------------------+
|             Parent Component             |
|  (Owns State, Coordinates Children)      |
+------------------------------------------+
        |                       ^
        |  [Data Down]          |  [Events Up]
        |  Public Properties    |  Custom Events
        |  (@api publicProp)    |  (new CustomEvent)
        v                       |
+------------------------------------------+
|              Child Component             |
|   (Renders UI, Captures User Input)      |
+------------------------------------------+
```

The parent is the single source of truth. The child renders what it receives and reports what the user did. It never decides on its own what the data should become.

## 2. Why the Flow Is One-Way

The one-way contract is not just a convention. The framework enforces it.

- **Public properties are read-only inside the child.** A child cannot reassign a value it received through `@api`. Attempting to do so raises an error in development mode, because the value belongs to the parent.
- **Objects and arrays passed down are read-only proxies.** The child cannot mutate a property of a received object, either. If the child needs a modified version for local display, it works on a shallow copy, never on the original.
- **Changes are requested, not applied.** When the user changes something in the child, the child dispatches an event describing the intent. The parent updates its own state, and the new value flows back down. The re-render is a consequence of the parent's state change, not of the child's action.

This is what makes the UI predictable. Every piece of data has exactly one owner, and every change passes through that owner. When something must be reset—such as clearing an uploaded file when the user switches records—the parent clears its own state once, and every child re-renders from the empty value. No child is left holding stale data.

## 3. Communication Patterns with Code Snippets

### ⚠️ Critical Naming Convention: CamelCase to Kebab-Case Mapping

Before reviewing the markup, we must understand LWC's HTML naming rules. JavaScript classes and component folders use `camelCase` (e.g., `childComponent`), but HTML is case-insensitive. To bridge this gap, **LWC maps every uppercase letter to a hyphen followed by the lowercase letter**.

* Component Folder: `childComponent` ➔ HTML Tag: `<c-child-component>`
* Property Name: `displayLabel` ➔ HTML Attribute: `display-label`

A component folder must start with a lowercase letter, and the folder name must exactly match its file names, including case. Using the camelCase form in a template either fails compilation (for tags) or leaves the public property silently unset (for attributes).

### 3.1 Passing Data Down & Invoking Child Methods

Public properties are the primary channel. Beyond them, a parent can also trigger imperative behavior inside a child by calling a **Public Method** decorated with `@api`.

#### Child Component (`childComponent.js`)

```javascript
import { LightningElement, api } from 'lwc';

export default class ChildComponent extends LightningElement {
    @api displayLabel; // Public property received from the parent

    // Public method exposed to the parent
    @api
    refreshView() {
        console.log('Child view refreshed for: ' + this.displayLabel);
    }
}
```

#### Parent Component Template (`parentComponent.html`)

```html
<template>
    <c-child-component
        lwc:ref="child"
        display-label={parentStateValue}>
    </c-child-component>
    <lightning-button
        label="Trigger Child Refresh"
        onclick={handleTrigger}>
    </lightning-button>
</template>
```

#### Parent Component Controller (`parentComponent.js`)

```javascript
import { LightningElement } from 'lwc';

export default class ParentComponent extends LightningElement {
    parentStateValue = 'Enterprise Payload';

    handleTrigger() {
        // lwc:ref gives a direct reference without a CSS selector
        this.refs.child?.refreshView();
    }
}
```

`lwc:ref` is the preferred way to reach a child element. `this.template.querySelector()` still works, but it couples the parent's logic to class names in the markup.

**Use public methods sparingly.** They are appropriate for purely visual actions such as setting focus, scrolling into view, or opening and closing a panel. They should not be used to change data—for example, a `reset()` method that clears the child's values. Data changes belong to the parent's state. If the child clears itself through a method while the parent still holds the old value, the two drift apart, and the next render can bring the stale data back.

### 3.2 Dispatching Events Up

When the child needs to signal an action back to its coordinator, it creates and dispatches a `CustomEvent`.

#### Child Component Controller (`childComponent.js`)

```javascript
import { LightningElement } from 'lwc';

export default class ChildComponent extends LightningElement {
    handleSelection(event) {
        const selectedId = event.target.dataset.id;

        // Build the event with a minimal payload
        const selectEvent = new CustomEvent('itemselect', {
            detail: { id: selectedId }
        });

        // Dispatch to the parent
        this.dispatchEvent(selectEvent);
    }
}
```

#### Parent Component Template (`parentComponent.html`)

```html
<template>
    <c-child-component
        onitemselect={handleItemSelection}>
    </c-child-component>
</template>
```

A few rules keep events clean:

- **Name events in lowercase without hyphens or an `on` prefix.** The parent listens with `on` + the event name (`itemselect` ➔ `onitemselect`).
- **Keep the payload minimal and primitive.** Send an Id or a value, not the child's internal objects. The parent already owns the data and can look up the rest.
- **Leave `bubbles` and `composed` at their defaults (`false`) unless you need them.** A non-bubbling event reaches only the direct parent, which keeps the contract explicit. Enabling `composed` lets the event cross shadow boundaries and turns it into part of the component's public API.

## 4. UI/UX Modeling Best Practices: Smart vs. Dumb Components

When dividing your user interface into component hierarchies, apply the **Separation of Concerns (SoC)** principle by separating **Smart (Container)** components from **Dumb (Presentational)** components.

| Component Type | Role & Responsibility | Architectural Behavior |
| --- | --- | --- |
| **Smart (Container)** | Owns state, orchestrates logic, uses wire adapters, calls Apex controllers. | Single source of truth. Coordinates its sub-components. |
| **Dumb (Presentational)** | Focuses on rendering, styling, and capturing user interaction. | Purely reactive. Relies entirely on data down and events up. Never calls Apex. |

### What a Dumb Component May Still Hold

"Dumb" does not mean stateless. A presentational component may keep **transient UI state** that has no business meaning: whether a dropdown is open, the text currently being typed, or a debounce timer for a search input. None of these needs to survive a re-render, and the parent has no reason to know about them.

The line is business data. Anything that would be saved, validated, or must be cleared when the context changes belongs to the container.

### When the Child Needs Server Data

A typeahead search is the classic temptation to call Apex from a child. Instead, the child debounces the input and dispatches a `search` event with the term. The container calls Apex and passes the results back down through a public property. The child stays reusable across objects, and all server access stays in one place.

### Why This Separation Matters

* **High Reusability:** Presentational components (a card layout, a search input, a record picker) can be reused across different objects and pages, because they carry no hardcoded data dependencies.
* **Testability:** Business logic concentrated in the container—or in a plain JavaScript module it imports—can be unit-tested with Jest by injecting mock data at a single entry point. Presentational components need only rendering tests.
* **Predictable Resets:** Because state lives in one place, context changes such as switching records are handled once, in the container.
* **UI/UX Consistency:** Layout adjustments made inside presentational components apply everywhere they are used, without risking data corruption.

## 6. Summary

Designing robust component structures in LWC requires strict discipline about data ownership. Keep state in the container, pass it down through `@api` properties, and bubble user intent up through `CustomEvent`. Reserve public methods for visual actions, let presentational components hold only transient UI state, and reach for Lightning Message Service only when components share a page but not a tree. Following these boundaries produces modular, enterprise-grade interfaces that are easy to maintain, scale, and refactor.
