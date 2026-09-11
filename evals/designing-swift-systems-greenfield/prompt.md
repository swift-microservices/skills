---
max_turns: 15
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing]
---

We're building a marketplace in Swift on the server. Buyers browse listings and place orders, sellers manage their listings and get paid out, payments go through Stripe, and both sides get email and push notifications about order events. Propose the services, what data each one owns, how they talk to each other, and where consistency is strong versus eventual. Write the design to ./design.md and summarize the key decisions.
