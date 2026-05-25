> I’m building a software project and I want to structure it so that **I can frequently clear the chat (`/clear`) between tasks while still keeping the model aware of what’s been done and what’s next**.  
>   
> Please do the following:
>
> 1. **Create a project plan file** named `FEATURES.md` that:
>    - Lists the main features or tasks of my app (e.g., “User Authentication”, “Dashboard”, “API Integrations”, etc.).  
>    - For each feature, include:
>      - A short description.  
>      - A status field: one of `planned`, `in progress`, `done`, or `blocked`.  
>      - A brief note on which files or modules are involved.  
>    - At the top, add a short instruction like:  
>      > “Always read this file before working on any feature. Assume previous completed features are already implemented.”
>
> 2. **Create a journal file** named `JOURNAL.md` that:
>    - Logs progress, decisions, bugs, and experiments in short entries.  
>    - Each entry should contain:
>      - Date or “Session N”.  
>      - Feature or task being worked on.  
>      - What was done, what failed, and what to try next.  
>    - At the top, add a short instruction like:  
>      > “Always read this file before starting a new session to understand the project’s history and current state.”
>
> 3. **Create a main README file** named `README.md` that:
>    - Gives a brief overview of the project, its purpose, and its main components.  
>    - Includes a section “Project Status” that summarizes which high‑level features are completed, in progress, or planned (referencing `FEATURES.md`).  
>
> 4. **Create a Claude‑specific configuration file** named `CLAUDE.md` (or `CLA UDE_PLAN.md`) that:
>    - Explains how you should behave when I start a new session or run `/clear`.  
>    - Instructs you to:
>      - Always read `FEATURES.md` and `JOURNAL.md` first.  
>      - Confirm the next feature or task to work on (for example, “Next we are working on feature 2”).  
>      - Ask me for confirmation before starting work on that task.  
>    - Include a short note like:  
>      > “If the chat context is empty or has been cleared, assume that previous features marked as ‘done’ in FEATURES.md are already implemented, and continue from the next incomplete feature.”
>
> 5. Finally, generate for me a **short reusable bootstrapping prompt** that I can paste into Claude at the start of a new session or after `/clear`, which:
>    - Tells you to read `FEATURES.md`, `JOURNAL.md`, and `README.md`.  
>    - Asks you to summarize what’s been done so far.  
>    - Asks you to propose the next feature or task to work on.  
>    - Gives you a chance to confirm with me before starting that task.
>
> Please write all of these files as **Markdown templates** that I can copy into my project, and keep the language clear and concise so it fits well with Claude‑Code or similar workflows.

***

You can then:
- run this once,  
- save the generated files into your project root,  
- and after every `/clear` paste the **bootstrapping prompt** Claude gives you at the end (or a slightly trimmed version) to reconnect context and continue from the right feature.  

This pattern is widely used by Claude‑heavy coders to keep context tight while preserving project‑level continuity.[1][2][3]

Sources
[1] Is there a way to resume a Claude code terminal conversation ... https://www.reddit.com/r/ClaudeAI/comments/1r7444l/is_there_a_way_to_resume_a_claude_code_terminal/
[2] How to refresh Claude code's memory after restart? - Facebook https://www.facebook.com/groups/vibecodinglife/posts/1810748216180374/
[3] Guiding the Conversation https://www.educative.io/courses/claude-code/guiding-the-conversation
