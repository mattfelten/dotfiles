---
name: write-mr
description: Write a merge request or pull request — title and description — to a consistent standard, built on the repo's own MR/PR template. Use when Matt says "write the MR", "draft the MR/PR description", "write this up as an MR", "open a PR for this", or when finished work needs an MR/PR. Also use to rewrite the description on an MR/PR that is already open.
---

# Write an MR / PR

Compose the title and the description, check it, then publish. The description is built **on the
repo's own template** — never on a structure invented here.

## Read these first, don't work from memory

1. **The standard** — `standard.md`, next to this file. It is the whole of how each section gets
   written, and none of it is restated here. Read it before writing a line.
2. **The repo's template** — find it in step 2, then read it.
3. **The repo's own conventions** — the `CLAUDE.md` at the repo root, section on Merge Requests or
   Pull Requests, plus any `CONTRIBUTING.md`. A repo can override the standard's defaults and can
   require a section the standard would leave out, so read it before writing.

## 1. Gather

- `git log origin/main..HEAD` and `git diff origin/main...HEAD --stat` for what actually changed.
  Read the diff itself where the summary isn't enough — the description has to be true.
- The issue key, from the branch name, the commits, or by asking. **Whether an issue is linked
  changes the Why**: linked means one high-level sentence and let the ticket carry the detail; not
  linked means one or two paragraphs holding the design and UX thinking.
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
  Templates often say this outright: delete what doesn't apply, don't add sections that aren't there.
- **Both mandatory ideas still have to be present in substance.** Where the template has no
  Why-equivalent, the why becomes the opening sentence or two of the first content section, with no
  heading of its own. The standard lets the sections go unlabelled; it does not let the why go
  missing.
- **Map the template's vocabulary onto the standard, then write to the standard:**

  | Template heading | How it gets written |
  |---|---|
  | Why, Purpose, Motivation, Context | prose, never bullets; length set by whether an issue is linked |
  | What's Changed, Changes, Description, Scope | bullets, one point each, at most two sentences |
  | How to test, Testing notes, Test plan | real steps, and only when the trigger is met |
  | Gallery, Screenshots | images, and only when the trigger is met |
  | Deploy notes, Rollout | only when rollout has an actual dependency |

- **Delete an optional template section whose trigger isn't met.** Where a template asks for
  deletion rather than "N/A", cutting the section *is* compliance. Never leave one empty.
- **Strip the `<!-- ... -->` comments.** They are instructions to whoever is writing, not content
  for the reviewer.
- **Never ship a placeholder.** Issue-key stubs, `- [ ] Step 1`, `@/username` and the like each get
  filled in or the line goes.
  - **Trap worth knowing:** a leftover issue-link stub such as
    `Closes: [ABC-###](https://tracker.example/browse/ABC-###)` still contains the tracker's URL, so
    the style check reads it as a linked ticket and expects a one-sentence Why — while the reviewer
    has no ticket to open. Put the real key in, or delete the line.
- **Keep the process furniture the repo asks for** — Creator and Reviewer checklists, reviewer
  quick actions. Tick and prune them honestly. The style check ignores them as process.
- **A repo mandate beats a standard default.** Where the repo's `CLAUDE.md` requires a section, it
  goes in even when the standard would call its trigger unmet; keep it to a line or two. A repo that
  mandates evidence the change works is the common case — a screenshot for anything user-visible, or
  a green targeted test run recorded under How to test.

## 4. Write the title

Where the repo squash-merges, **the title becomes the single commit on the default branch and the
single changelog line** — check for that before titling. Conventional Commit, meaningful scope,
issue key at the end:

```
feat(storybook): preview email templates (ABC-1234)
```

Some repos enforce the format in CI, so match it exactly rather than approximately.

## 5. Check it before publishing

Write the body to a file, then:

```sh
python3 ~/.claude/skills/write-mr/gate.py "<title>" <body-file>
```

`PASS` means publish. `FAIL` prints which checks it missed and what to do instead — fix and re-run.
The fix is rarely "make it shorter". If it reports that no check is installed, self-review against
`standard.md` instead; the standard is the authority either way.

Where that check also runs as a hook on the create call, running it here turns a blocked command
into a few cents. Note that in that setup **any Bash command mentioning `glab mr` or `gh pr` gets
read by the check, heredocs included** — so build the body in a file of its own rather than inline,
and keep the create call in its own command instead of chaining it behind the write.

## 6. Publish

- **Check the house conventions for opening one** — who reviews, whether it opens ready or as a
  draft, whether auto-merge is the default. That is per-project, and lives in the repo's `CLAUDE.md`
  or in memory for that project, not here.
- **GitHub** → `gh pr create --title "…" --body-file <file>`.
- **GitLab** → `glab mr create --title "…" --description "…"`. There is no `--description-file`, so
  the body goes inline. In a worktree-isolated session, command substitution and backticks in a
  command get refused, so a body full of backticked identifiers may have to use plain quotes
  instead — worth confirming that trade with Matt when the MR matters.
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
- Skip the check to get an unclear description through.
