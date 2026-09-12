---
max_turns: 15
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing]
---

We're two developers building a recipe-sharing product in Swift on the server: people sign up, publish recipes, save other people's recipes to collections, and comment. The clients are a web app and an iOS app, both talking REST over HTTPS. One Postgres instance, one small team, no separate ops. Propose the architecture: how it's deployed, how it's structured internally, how the database is laid out, and how users are authenticated and kept apart from each other's data. Write the design to ./design.md and summarize the key decisions.
