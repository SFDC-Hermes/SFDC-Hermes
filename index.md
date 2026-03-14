---
layout: home
author_profile: true
title: "Innovating the Salesforce Ecosystem"
header:
  overlay_color: "Black" 
  overlay_filter: "0.5"
  excerpt: "Salesforce Developer | Application Architect | AgentBlazer Legend"

certifications:
  - image: /assets/images/Application_Cert.png
    date: "Issued Feb 2026"
    alt: "Application Architect"
    title: "Salesforce Certified Application Architect"
    statis: "Active"
  - image: /assets/images/Agentforce_Cert.png
    date: "Issued Oct 2024"
    alt: "Agentforce"
    title: "Salesforce Certified Agentforce Specialist"
  - image: /assets/images/Developer_Cert.png
    date: "Issued Jul 2025"
    alt: "PD2"
    title: "Salesforce Certified Platform Developer II"
---

<style>
  .cert-container {
    margin-top: 20px;
  }
  .cert-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 15px 0;
    border-bottom: 1px solid rgba(128, 128, 128, 0.2);
  }
  .cert-left {
    display: flex;
    align-items: center;
    gap: 20px;
  }
  .cert-icon {
    width: 60px !important;
    height: 60px !important;
    margin: 0 !important;
  }
  .cert-info h4 {
    margin: 0 0 5px 0 !important;
    font-size: 1.05rem;
  }
  .cert-info p {
    margin: 0 !important;
    font-size: 0.85rem;
    color: #888;
  }
  .cert-right .status-badge {
    padding: 5px 12px;
    border: 1px solid #0050FF;
    color: #0050FF;
    border-radius: 4px;
    font-size: 0.8rem;
    font-weight: bold;
    text-decoration: none;
  }
  .cert-right .status-badge:hover {
    background: #0050FF;
    color: #fff;
  }
</style>

# 👋 Welcome! I'm Hermes.

I am a **Salesforce Developer** who obsesses over clean code and scalable architecture. I don't just solve tickets; I design systems that empower businesses. 

### 🏆 Professional Achievements

<div class="cert-container">
  {% for cert in page.certifications %}
  <div class="cert-item">
    <div class="cert-left">
      <img src="{{ cert.image }}" alt="{{ cert.title }}" class="cert-icon">
      <div class="cert-info">
        <h4>{{ cert.title }}</h4>
        <p>{{ cert.date }}</p>
      </div>
    </div>
    <div class="cert-right">
      <span class="status-badge">Active</span>
    </div>
  </div>
  {% endfor %}
</div>

---

### 🛠️ Technical Focus
* **Apex Excellence:** Architecting reusable and performant backend logic.
* **LWC Mastery:** Crafting high-speed, intuitive user interfaces.
* **AI & Automation:** Mastering Agentforce to lead the next generation of Salesforce.

---

## 📂 Recent Posts