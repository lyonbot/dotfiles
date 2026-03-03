---
name: open-dev-browser
description: Opens the local dev server at http://localhost:5173/ using Playwright (1024x1024 window), then reads memory files to restore session context. Use when the user says "/open-dev-browser", "打开开发界面" or wants to start a dev session with the UI open and memory loaded.
---

# open-dev-browser

Execute these steps in order:

- Use playwright MCP to open `http://localhost:5173/` and resize window to 1024x1024
- Read project memory.
- Report to user: browser is open and memory is loaded, ready to work.
