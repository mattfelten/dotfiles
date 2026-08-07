---
name: cleanup
description: End-of-conversation close-out. Audits unfinished threads, curates ai-brain and harness memory (writing, correcting, and pruning without asking), verifies work has actually landed (commits, MRs/PRs, CI, tickets), and tears down worktrees, branches, and anything left running. Use when Matt runs /cleanup, or says he's wrapping up, closing out, or done for the day.
metadata:
  version: "1.0.0"
---

# cleanup — close out a conversation

Run right before the conversation is abandoned. The job is to leave **nothing that only
exists in this context**: no unfinished thread that will be forgotten, no lesson that
wasn't written down, no work stranded on disk, no process still running.

## The one rule

**Act freely on memory and on anything reversible. Gate anything that could destroy
unrecoverable work, and anything other people will see.**

Just do it: write, edit, merge, and **delete** memory notes; update indexes; comment on
tickets you already own.

Propose and wait: removing branches or worktrees, closing MRs, force-anything, posting to
Slack or anywhere else other people read.

Never delete something whose only copy is the thing being deleted.

## Arguments

- `/cleanup` — full run.
- `/cleanup dry` / `--dry-run` — report only. No writes, no deletions. Use when unsure.
- `/cleanup threads` — Phase 1 only, when Matt just wants the loose-ends list.

---

## Phase 0 — Sweep (read-only, parallel, fast)

Fire these together. If everything comes back clean and Phase 1 finds no threads, say so
in three lines and stop — a cheap no-op run is what keeps this skill worth running.

Identify every repo touched this session (from the transcript, plus any worktree under a
`.claude/worktrees/` path), then per repo:

```sh
git -C <repo> status --porcelain=v1 --branch   # dirty files + ahead/behind
git -C <repo> stash list
git -C <repo> log --oneline @{upstream}..HEAD 2>/dev/null   # unpushed commits
git -C <repo> worktree list
```

Also collect, in the same pass:
- Open MRs/PRs authored this session — `glab mr list --author=@me` / `gh pr list --author=@me`
- Background shells still running, dev servers, watchers started this session
- Scheduled work created this session — `CronList`, any `/loop` still armed
- Background agents/tasks not yet reported back

Hold all of this. Don't act on it until the phases below.

---

## Phase 1 — Open threads (this is a gate)

Re-read **the whole conversation**, not the last few turns. Look for things that were
raised and never closed:

- Work named but not done — "we should refactor X", "this needs a ticket", "let's fix the
  flaky test", "I'll redesign that later"
- A question Matt asked that got a partial answer, or that drifted before it was answered
- Something you flagged as a concern that was never resolved either way
- A `TODO`/`FIXME` added to code during the session
- Scope you narrowed, deferred, or quietly dropped — including anything you said you'd
  "come back to"
- A follow-up that depends on something now finished ("once the MR merges, update the doc")

Exclude anything Matt explicitly declined. Don't pad the list — a thread nobody would
regret losing isn't a thread.

Present each as one line with a proposed disposition. **Every thread gets one of three
outcomes — never leave one un-dispositioned:**

| Outcome | What it means |
|---|---|
| **Finish now** | Small enough to do in this run. Do it. |
| **Defer** | Real work, not now. It must get a durable home *in this run* — a Jira ticket via the Atlassian MCP, or an ai-brain project note. A deferral with no artifact is a dropped thread wearing a disguise. |
| **Drop** | Confirmed not worth doing. Say so out loud so the decision is on the record. |

If any thread lands on "finish now" or needs a decision from Matt, **stop here** and get
the answer before continuing. Do not tear down worktrees while work might still need them.

---

## Phase 2 — Land the work

**Working trees first.** Every dirty file, untracked file, unpushed commit, and stash found
in Phase 0 gets resolved: committed and pushed, or explicitly acknowledged as throwaway.
Commit messages follow the usual conventions — **no `Co-Authored-By`, no "Generated with
Claude Code"**.

**Debris check.** Diff what this session added and look for what shouldn't ship:
`console.log`, `debugger`, `.only(`/`.skip(` on tests, commented-out blocks, hardcoded
test values, scratch files written into the repo instead of `$CLAUDE_JOB_DIR/tmp`.

**MRs/PRs — the bar is *terminal or self-resolving*, not "merged".** For each one:

- Merged → confirm the post-merge pipeline on the target branch is green. Merged with a
  red `main` is not done.
- Open → it must be ready (not draft), have a reviewer, and have auto-merge armed. For
  MissionCloud repos that means `--reviewer djbowers` and arming via the raw API:
  ```sh
  glab api --method PUT "projects/<id>/merge_requests/<iid>/merge?merge_when_pipeline_succeeds=true"
  ```
  Verify with `merge_when_pipeline_succeeds` + `merge_user`, **not** `auto_merge_enabled`.
  See the `mr-defaults-mission` memory for the full checklist and the known `glab` refusals.
- Open, green, armed, waiting on review → **that is a valid end state.** Note it and move on.
- Open and red, or armed hours ago and never fired → surface it; that's a real loose end.

**Tickets.** If the session maps to a Jira issue, transition it and/or comment the outcome
via the Atlassian MCP. A merged MR with a ticket still in "In Progress" is an open thread.

---

## Phase 3 — Curate knowledge

### You own this. Never ask.

Matt does not manage memory — you do, and that includes deleting. Never ask "should I
remove this note?" Decide, do it, and report it in Phase 5. Both stores are in git, so a
deletion you get wrong is recoverable from history; that is what makes this safe to do
unattended. Treat a run that only *adds* notes as an incomplete run.

Two stores. Route deterministically so they don't duplicate:

- **`~/.claude/projects/<workspace>/memory/`** — short, operational, must load *every*
  session for this workspace. Defaults, hard-won tool quirks, corrections to your own
  behavior. Loud and unconditional. Keep these few.
- **`~/Projects/personal/ai-brain/`** — everything else durable: decisions and their
  reasoning, project context, people, references, domain knowledge. Follow its `CLAUDE.md`
  exactly (frontmatter, one idea per file, update the *enclosing* `INDEX.md`, write straight
  to `main` — never a branch or PR).

When something belongs in both, the full note goes in ai-brain and the harness memory gets
a one-line pointer to it.

### Curate, don't just append

Before writing anything, search for what already covers it — extend before you create.
Then do the maintenance pass, every run, whether or not the session produced something new:

- **Delete** notes that are wrong, superseded, or that no future session would benefit from
  reading. A stale note is worse than a missing one, because it gets trusted.
- **Correct** notes this session proved wrong. Higher value than anything new you'd add.
- **Merge** duplicates and near-overlaps into the better-placed of the two, and repoint the
  inbound `[[wikilinks]]`.
- **Archive** projects that finished, per ai-brain rule 4, rather than leaving them `active`.
- **Prune the harness store hard.** Every file there costs context on *every* session in the
  workspace. A note that no longer earns that slot gets deleted outright, or moved to
  ai-brain with nothing left behind.
- Update the enclosing `INDEX.md` for anything removed, moved, or merged.

Ask of the session: what would have saved time if it had been known at the start? That's
the note. Skip anything the repo, git history, or a `CLAUDE.md` already records, and skip
anything that only mattered inside this conversation.

**Before writing to ai-brain, scan for secrets** — tokens, keys, credentials, customer
data, anything from a `.env`. It's git-synced; a secret written there is a secret
published.

If work is genuinely continuing next session, leave a resume note in the relevant ai-brain
project folder: current state, next step, and anything non-obvious you'd otherwise re-derive.

---

## Phase 4 — Tear down

Only after Phases 1–3 are settled.

**Stop what's running** (safe, just do it): background shells, dev servers, watchers,
`/loop`s, crons created this session, and any background agent still pending. Report what
was stopped.

**Worktrees and branches** (gated — propose, then wait for a yes):

Per worktree/branch created this session, verify *before* proposing deletion that its work
is reachable elsewhere:

```sh
git -C <repo> status --porcelain          # uncommitted work
git -C <repo> diff main <branch>          # read the "+" side: content the branch has and main lacks
```

**Use that content diff, not a SHA-based check.** `git log <branch> --not --remotes`,
`git cherry`, and the three-dot `git diff main...<branch>` all report a branch as holding
unmerged work when its content is already on `main` — they compare commit identity, and
autosync (ai-brain, dotfiles) re-commits the same content under new SHAs. Trusting one of
those on 2026-08-07 nearly duplicated a note into ai-brain.

**Then actually read the `+` lines before calling them "work to save."** They are just as
often *older* versions of things `main` has since corrected — in the case above, every
branch-unique line was a superseded note, including one stating a claim `main` had already
disproved. Superseded content is a reason to delete the branch, not to keep it.

- Clean + merged/pushed → propose removal.
- **Any** unmerged commits, uncommitted changes, or stashes → do **not** propose deletion.
  Surface it as a loose end and let Matt decide. This is the one place cleanup can destroy
  something irrecoverable, so the bias is strongly toward leaving it.
- Never delete a worktree you didn't create this session — it may be one Matt is using.

```sh
git -C <repo> worktree remove <path>
git -C <repo> branch -d <branch>       # -d, never -D, without an explicit yes
```

Also clear scratch files this session created outside the repo.

---

## Phase 5 — Report

One compact block. Scannable, no prose.

```
CLEANUP — <workspace>

Threads      3 found → 1 finished, 1 deferred (PROJ-482), 1 dropped
Work         2 repos clean · 1 commit pushed
MRs          !2501 merged (main green) · !2503 open, green, armed, w/ DJ
Tickets      PROJ-482 created · PROJ-471 → Done
Memory       ai-brain: +1 note · updated 1 · deleted 2 (stale) · archived 1 project
             harness: pruned mr-defaults-mission → folded into ai-brain
Running      stopped 1 dev server, 1 loop
Teardown     removed 1 worktree + branch · 1 kept (unmerged commits)

⚠ Needs you   !2503 armed 4h ago, hasn't fired — DJ hasn't reviewed
```

End with the open items only. If nothing needs Matt, say that in one line.
