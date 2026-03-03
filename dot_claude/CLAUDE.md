# AI ASSISTANT RULES: DOCUMENTATION & CODE SYNCHRONIZATION

You must strictly adhere to the following principles regarding documentation generation and maintenance. 

## 1. Documentation as an Index (Map, Not Territory)
* **Act as a Directory:** High-level documentation (`README.md`, `AGENTS.md`, architecture docs) must serve as an index or a map of the codebase, NOT a detailed explanation of the code. 
* **Always Use Source File Paths:** Instead of explaining how a specific function or module works, provide a brief summary of its responsibility and explicitly link to its file path (e.g., `Authentication logic is handled in src/services/auth.ts`). 
* **Enable Traceability:** Every major system component, API route, or agent workflow mentioned in the markdown files must include a direct, relative file path reference pointing to where the actual implementation lives.

## 2. The DRY Principle (Don't Repeat Yourself)
* **Never translate code into natural language:** Do not write markdown documentation that simply repeats what the code already says line-by-line.
* **Code is the Single Source of Truth:** Implementation details, parameter descriptions, and return types belong strictly in the code itself via standard docstrings (e.g., JSDoc, Python Docstrings) and inline comments.
* **Focus on the "Why" and "High-Level How":** External files must only contain system design decisions, business logic context, directory structures, and setup workflows. 

## 3. Concise Documentation Formatting
* **Keep it brief and scannable:** Avoid long, verbose paragraphs. Use bullet points, bold text for key terms, and clear headings.
* **No Redundancy:** If a workflow or API is already explained in `docs/api.md`, do not duplicate it in `README.md`. Use relative markdown links between documents instead.
* **Agent Context (AGENTS.md):** When updating agent instructions or system prompts, write strictly declarative rules. Point the agent to the relevant source code files rather than pasting code examples into the prompt document.

## 4. Mandatory Update Protocol (Continuous Synchronization)
* **The "Check-Before-Complete" Rule:** Every time you modify core logic, add a new dependency, change environment variables, restructure directories, or alter the system architecture, you MUST pause and evaluate the project documentation.
* **Automatic Updating:** If your code changes make any file path, architecture description, or setup step in `README.md`, `AGENTS.md`, or the `docs/` folder obsolete, you are required to update those files in the exact same iteration/commit.
* **Reporting:** Whenever you update documentation as a result of a code change, explicitly state what you updated in your final conversational response (e.g., "I updated the auth logic and also updated the file path references in README.md").

## 5. Advanced SWE & Maintainability Practices
* **Prefer Visuals over Prose (Mermaid.js):** Whenever describing data flow, system architecture, or state machines, DO NOT write paragraphs of text. Instead, generate or update a `mermaid` code block. 
* **Append-Only Architecture (ADRs):** For major structural changes, do not aggressively rewrite the README. Instead, draft a brief Architecture Decision Record (ADR) as `docs/adr/####-[title].md`.
* **Target Audience Separation:** Keep `README.md` strictly for end-users (installation, basic usage). Put all developer scripts, CI/CD explanations, and test commands in `DEVELOPMENT.md`.
