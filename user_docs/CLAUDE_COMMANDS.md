# Claude Code — Commands & Usage Guide

> **What this is:** a running reference of Claude Code commands and skills
> introduced during this project. Append new entries before each `/clear`.
> Newest additions at the bottom of each section.
>
> **How to use:** treat this as your cheat-sheet. The "when to use" notes are
> opinionated based on this project's patterns — not universal rules.

---

## Session management

### `/clear`
Wipes the current conversation context.

**When to use:**
- Before starting a new coding task (keeps context clean and cheap)
- After any expensive operation like a code review (context is already large)
- At the start of each work session if picking up from a previous day

**What you don't lose:** anything written to files in the repo, memory files,
and the decision/review logs. Claude re-reads those on the next session.

**What you do lose:** the current conversation thread. If there's something
important mid-conversation that isn't in a file yet, save it first.

---

## Code review

### `/code-review <level> <instructions>`

Runs a structured multi-angle code review. Level controls depth and cost.

| Level | Agents | Cost | Best for |
|-------|--------|------|----------|
| `low` | 1, fast | cheap | Quick sanity check on a small change |
| `medium` | 1, thorough | moderate | Routine PR review |
| `high` | 3–4 parallel | moderate–expensive | Pre-production readiness, catching real bugs |
| `ultra` | Many parallel, Opus | expensive | Deep architectural review; maximum recall |

**When to use high vs ultra:**
- `high` is right for most serious reviews. It catches real bugs reliably and is
  significantly cheaper than ultra. Use it before any major milestone.
- `ultra` is for when you want a second opinion at the highest possible standard
  — e.g. before handing to a client, before a production launch, or when you
  suspect a deep structural issue and want maximum coverage.

**How to write good review instructions:**

The instructions after the level are the most important part. Tips:
- State the *purpose* of the review, not just "review this"
- Tell it what the *forward direction* is (e.g. "moving from POC to production")
- Point it explicitly at your design documents
- Flag known structural compromises so it doesn't re-flag them as bugs

**Good example (used in this project):**
```
/code-review high flag anything that may cause problems when moving from POC
to production. Note: docs/ contains the Shinylive app export (not documentation)
due to GitHub Pages constraints. Pay attention to ARCHITECTURE.md,
DECISION_LOG.md, PROJECT_BRIEF.md, DISCLOSURE_CONTROL.md and
DATA_DICTIONARY.csv as the source of truth for intended design and data
handling rules.
```

**Token-saving tips:**
- Don't `/clear` before a review — the review agents are fresh anyway, so it
  doesn't affect quality or cost
- Scoping to a subfolder (e.g. `/code-review high poc/`) saves tokens but
  excludes design docs — only do this if the docs aren't relevant
- `high` on a small codebase (~500–1000 lines) is meaningful but not ruinous;
  `ultra` on the same codebase is proportionally more expensive without always
  proportionally more findings

---

## Running the app

### `/run`
Launches the project's app and lets you observe it in a browser.

**When to use:** when you want to verify a UI change actually works, not just
that the code compiles. Useful after any changes to `app.R` files.

### `/verify`
Verifies that a specific code change does what it's supposed to.

**When to use:** after a bug fix, to confirm the fix actually resolves the
issue in the running app rather than just in theory.

---

## Code quality

### `/simplify`
Reviews changed code for reuse, simplification, and efficiency — then applies
the fixes. Quality-only (does not hunt for bugs; use `/code-review` for that).

**When to use:** after a coding session where you've been moving fast and want
to tighten things up before committing.

### `/security-review`
Runs a security-focused review of pending changes.

**When to use:** before any change that touches data handling, file I/O, or
anything that could expose sensitive data. For this project: before any ETL
changes or changes to how the fulfilment tool handles request.json.

---

## Configuration & settings

### `/update-config`
Configures Claude Code's behaviour — permissions, hooks, environment variables,
automated behaviours ("every time X, do Y").

**When to use:** when you want to set up automated behaviours (e.g. "before
stopping, always update the memory file") or add permissions for frequently-used
commands that keep prompting for approval.

### `! <command>`
Runs a shell command directly in the Claude Code session so its output lands
in the conversation.

**When to use:** for interactive commands that require your credentials or local
environment (e.g. `! git push`, `! Rscript poc/etl/etl.R`). Saves you switching
to a separate terminal.

**Example:** `! git status` — shows working tree state directly in chat.

---

## Scheduled & recurring tasks

### `/loop <interval> <command>`
Runs a command on a recurring interval within the session.

**Example:** `/loop 5m /verify` — re-verify the app every 5 minutes.

**When to use:** when you want Claude to keep an eye on something while you do
other work (e.g. watching a long-running process).

### `/schedule`
Creates a scheduled remote agent that runs on a cron schedule, outside of your
active session.

**When to use:** for tasks that should happen automatically (e.g. nightly checks,
automated reminders). Rarely needed for this project at current scale.

---

## Memory

Claude maintains a persistent memory file at `.claude/projects/.../memory/`.
This is read at the start of every session and updated during sessions.

**You don't need a command for this** — Claude manages it automatically.
But you can ask Claude to:
- "Remember X" — saves something explicitly
- "Forget X" — removes it
- "What do you remember about this project?" — surfaces the current memory

**What gets saved automatically:** project status, key decisions, your
preferences, things that surprised Claude, feedback you've given.

---

## Subagents (advanced)

Claude can spawn specialist subagents for specific tasks. You don't invoke these
directly — Claude decides when to use them — but it's useful to know they exist:

| Agent | What it does |
|-------|-------------|
| `Explore` | Fast read-only search across the codebase |
| `Plan` | Designs implementation strategy before coding |
| `general-purpose` | Research, multi-step investigation |

When Claude spawns agents in the background, it notifies you when they complete.
You can ask Claude to "run X and Y in parallel" to speed up independent tasks.

---

*Last updated: 2026-06-05. Append new commands before each `/clear`.*
