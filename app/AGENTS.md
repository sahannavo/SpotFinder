# AI Rules & Behavioral Constraints

NEVER use the automated browser agent, do not take screenshots, and do not extract the DOM. I will manually provide all necessary code snippets and error logs.

# Project rules: New Step Finance website

Always-on. Keep this file short: it is loaded on every turn.

## Project

- Marketing site for an Australian mortgage broker. React 18.2 + Vite, Three.js + React Three Fiber, GSAP + Lenis, Phosphor Icons, Nunito.
- Use Australian English and AUD ($1,234.50). Do not add libraries without asking. Reuse what is already installed.

## Save credits

1. Search before reading. Use grep or file search to find the exact file and lines. Read line ranges, not whole files or folders.
2. Do not re-read a file already in this conversation, unless it changed.
3. Small task: just do it. No plan, no task list, no walkthrough. Plan only when a change touches 3 or more files, and keep the plan to 5 lines.
4. Smallest possible diff. Edit in place. Never rewrite a whole file to change a few lines. No drive-by refactors, renames or formatting changes.
5. Do not run the browser, take screenshots or record anything unless I ask, or the change is visual. Then check once, fix once, stop.
6. Do not start a dev server if one is running. Check the port first. Run targeted checks (lint or typecheck for the files you changed), not a full build, unless I ask for one.
7. Do not create docs, READMEs, tests or sample files unless I ask.
8. If a fix fails twice, stop. Report the cause and what you tried. Do not keep looping.
9. Replies are short. No recap of the steps. Do not paste back code you already wrote to disk.
10. If a request is ambiguous and a wrong guess would be expensive, ask one short question first. If it is cheap to redo, make the most reasonable choice and say which.

## Be accurate

1. Never guess file paths, props, function names or library APIs. Open the code or the docs and confirm. If you cannot confirm, say so.
2. Never invent business facts: rates, fees, licence numbers, ABN, reviews, lender names, statistics. Use a visible `TODO(client): ...` placeholder and tell me.
3. Do not remove or change code you do not understand. Flag it instead.
4. Keep existing behaviour unless I asked to change it. If a fix needs a wider change, say so before doing it.
5. Money and dates: compute in code, never by hand. After changing a calculator, test one known case and show the input and output.
6. Do not claim "done" or "fixed" unless you ran something that proves it. State what you verified and what you did not.
7. Accessibility is part of done: labels on inputs, visible focus, sufficient contrast, and `prefers-reduced-motion` for animation.

## Finish with

- What changed, in one or two lines, and which files.
- How you verified it.
- Anything risky or left undone.
