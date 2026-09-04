---
name: write-mr
description: Write a merge request or pull request — title and description — in Matt's voice, built on the repo's own MR/PR template. Use when Matt says "write the MR", "draft the MR/PR description", "write this up as an MR", "open a PR for this", or when finished work needs an MR/PR. Also use to rewrite the description on an MR/PR that is already open.
---

# Write an MR / PR

Compose the title and the description, check it, then publish. The description is built **on the
repo's own template** — never on a structure invented here.

## Read these first, don't work from memory

1. **The standard** — `~/Projects/personal/ai-brain/me/mr-description-voice.md`. Read the whole
   note. It is the single source of truth for how each section gets written, and none of it is
   restated here.
2. **The repo's template** — find it in step 2, then read it.
3. **The repo's own mandate** — the `CLAUDE.md` at the repo root, section on Merge Requests or Pull
   Requests. It can override the standard's defaults, so read it before writing.
4. **MissionCloud repos only** — the pre-flight for the create call itself (reviewer, ready not
   draft, auto-merge, the quoting rules) is harness memory `mr-defaults-mission.md`. **Open the
   file.** Reading its one-line index entry is not reading the note, and that is how these get
   missed.

## 1. Gather

- `git log origin/main..HEAD` and `git diff origin/main...HEAD --stat` for what actually changed.
  Read the diff itself where the summary isn't enough — the description has to be true.
- The Jira key, from the branch name, the commits, or by asking. **Whether a ticket is linked
  changes the Why**: linked means one high-level sentence and let the ticket carry the detail; not
  linked means one or two paragraphs holding the design, aesthetic and UX thinking.
- Whether anything user-visible changed, which is what decides Gallery.

## 2. Find the template

First hit wins:

| Host | Look in |
|---|---|
| GitLab | `.gitlab/merge_request_templates/default.md`, then any other `*.md` in that directory whose name fits this change |
| GitHub | `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `PULL_REQUEST_TEMPLATE.md`, `docs/PULL_REQUEST_TEMPLATE.md`, then `.github/PULL_REQUEST_TEMPLATE/*.md` |

Not in a checkout, or the file isn't on disk? Read it from the API instead:

```sh
# GitLab — :id resolves from the current directory's repo; a numeric project id works anywhere
glab api "projects/:id/repository/files/.gitlab%2Fmerge_request_templates%2Fdefault.md/raw?ref=main"

# GitHub
gh api "repos/{owner}/{repo}/contents/.github/pull_request_template.md" \
  -H "Accept: application/vnd.github.raw"
```

**No template anywhere** → use the standard's two mandatory sections, `### Why` and
`### What's Changed`, and nothing else unless a trigger is met.

## 3. Reconcile the template with the standard

> **The template decides which sections exist and what they are called.
> The standard decides how each one is written.**

- **Use the template's headings, wording and order exactly.** Don't rename `## Description` to
  `## What's Changed`, don't reorder, and don't add a `### Why` to a template that hasn't got one.
  `services` says it outright: delete what doesn't apply, don't add sections that aren't there.
- **Both mandatory ideas still have to be present in substance.** Where the template has no
  Why-equivalent, the why becomes the opening sentence or two of the first content section, with no
  heading of its own. The standard lets the sections go unlabelled; it does not let the why go
  missing.
- **Map the template's vocabulary onto the standard, then write to the standard:**

  | Template heading | How it gets written |
  |---|---|
  | Why, Purpose, Motivation, Context | prose, never bullets; length set by whether a ticket is linked |
  | What's Changed, Changes, Description, Scope | bullets, one point each, at most two sentences |
  | How to test, Testing notes, Test plan | real steps, and only when the trigger is met |
  | Gallery, Screenshots | images, and only when the trigger is met |
  | Deploy notes, Rollout | only when rollout has an actual dependency |

- **Delete an optional template section whose trigger isn't met.** Both MissionCloud templates ask
  for deletion rather than "N/A", so cutting the section *is* compliance. Never leave one empty.
- **Strip the `<!-- ... -->` comments.** They are instructions to whoever is writing, not content
  for the reviewer.
- **Never ship a placeholder.** `RND-###`, `TICKET-#`, `- [ ] Step 1`, `@/username` each get filled
  in or the line goes.
  - **Trap worth knowing:** leaving `Closes: [RND-###](https://…atlassian.net/browse/RND-###)` in
    place reads to the style check as a linked ticket, so it expects a one-sentence Why while the
    reviewer has no ticket to open. Put the real key in, or delete the line.
- **Keep the process furniture the repo asks for** — Creator and Reviewer checklists,
  `/request_review` quick actions. Tick and prune them honestly. The style check ignores them.
- **A repo mandate beats a standard default.** Where the repo's `CLAUDE.md` requires a section, it
  goes in even when the standard would call its trigger unmet; keep it to a line or two.
  `control.missioncloud.com` mandates the template's structure, a Gallery for any user-visible
  change, and evidence of verification under How to test.

## 4. Write the title

These repos squash-merge, so **the title becomes the single commit on `main` and the single
changelog line**. Conventional Commit, meaningful scope, Jira key at the end:

```
feat(storybook): preview email templates (RND-1234)
```

`control.missioncloud.com` enforces the format in CI via `lint_mr_title`.

## 5. Check it before publishing

Write the body to a file, then:

```sh
python3 ~/.claude/skills/write-mr/gate.py "<title>" <body-file>
```

`PASS` means publish. `FAIL` prints which checks it missed and what to do instead — fix and re-run.
The fix is rarely "make it shorter".

This is the same check that runs on the create call, so running it here turns a blocked command
into a few cents. Note that **any Bash command mentioning `glab mr` or `gh pr` gets read by that
check, heredocs included** — so build the body in a file of its own rather than inline, and keep
the create call in its own command instead of chaining it behind the write.

## 6. Publish

- **MissionCloud** → follow `mr-defaults-mission.md` exactly: ready rather than draft, the right
  reviewer, auto-merge armed via the raw API, and its rules on quoting a multi-line description
  (there is no `--description-file`, and `$(cat …)` is refused inside a worktree).
- **GitHub** → `gh pr create --title "…" --body-file <file>`.
- **Show Matt the title and body before publishing**, unless he asked for it to just go up.
- **Paste the full URL** once it's open.

## Rewriting one that's already open

Read the current description first and keep whatever is still true — this is usually a restructure,
not a rewrite. Then `glab mr update <iid> --description "…"` or `gh pr edit <n> --body-file <file>`.
The same check applies.

## Never

- Invent a section structure the template doesn't have.
- Put behind-the-scenes content in the body: what was tried first, how the work went, validation
  numbers, references to a conversation. That belongs in the reply to Matt.
- Reach for `MR_STYLE_SKIP=1` unless Matt asked for the description as written.
