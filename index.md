---
layout: home
author_profile: true
title: "Innovating the Salesforce Ecosystem"
header:
  overlay_color: "Black" 
  overlay_filter: "0.5"
  excerpt: "Salesforce Developer | Application Architect | AgentBlazer Legend"
---

<link rel="stylesheet" href="{{ '/assets/css/achievements.css' | relative_url }}">

# 👋 Welcome! I'm Hermes.

I am a **Salesforce Developer** who obsesses over clean code and scalable architecture.

### 🏆 Professional Achievements

<div class="cert-container">
  {% for cert in site.data.certs %}
  <div class="cert-item">
    <div class="cert-left">
      <img src="{{ cert.image | relative_url }}" class="cert-icon">
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