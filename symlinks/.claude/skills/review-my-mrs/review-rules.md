# MR review rules

Canonical rules for reviewing Matt's GitLab review queue. Both `review-my-mrs` (manual) and
`review-my-mrs-auto` (autonomous) read this file. They differ **only** in whether they may act
on a conclusion — never in how they reach it.

Do not duplicate any of this into the skill files. Change it here.

---

## 1. Scope

- Open MRs where reviewer = `@me`: `glab mr list --reviewer=@me`. Ignore MRs where Matt is only
  assignee or author.
- Skip Draft/WIP.
- `control.missioncloud.com` (project `27492617`) — fully in scope.
- `missioncloud/platform/services` (project `9405729`) — **out of scope by default**, even when
  Matt is the requested reviewer. Include one only if it tags `@mattfelten` by name in the
  description **or** a non-system comment. Being added as a reviewer is not enough.
  - description: `glab api "projects/9405729/merge_requests/<iid>"` → `.description`
  - comments: `glab api "projects/9405729/merge_requests/<iid>/notes?per_page=100"`

Re-check approval every pass: **GitLab wipes approval on push and on retarget**, even at the
same SHA (ai-brain `work/mission/reference/gitlab-approval-resets-on-push.md`).

---

## 2. What you do NOT review

Two systems already cover large areas. Duplicating them wastes the pass and clutters the MR.

**`claude_review` (CI job)** owns severity 5+ on its own rubric — security, bugs, logic errors,
subtle correctness, maintainability (6), and readability/structure (5). Read
`.gitlab/claude-review-prompt.md` in the control repo for the authoritative list. It already
covers naming, "consider extracting", dead code, file structure, and its project-specific bug
classes (GraphQL codegen staleness, `*.mocks.ts` drift, `composeStories` coupling, `@m`/`@mc`/
`@atlas` path aliases, public vs private GraphQL API, Auth0/Atlas separation, `@mc/router`
shim, edits to generated output).

**Other CI jobs** own ESLint/Prettier, TypeScript, commitlint, Vitest, Playwright, npm audit.

So: **do not run tests locally to confirm what CI already reports.** Green/red is free and
authoritative. Going local is the exception — only when a read genuinely cannot settle a
question, or for an on-demand UI run Matt asked for.

### Why you still add value

`claude_review` is instructed to explore *sparingly*, to emit only line-anchored findings, to
**omit any finding it cannot confidently place on a line**, and never to summarize what the MR
does.

So it finds bugs in code that exists, but **cannot flag code that should exist and doesn't** —
absence has no line number. And it never checks the description against the diff. That gap is
your job.

---

## 3. What you verify — six checks

**1. Claims vs code.** Does the description match the diff? Look for unstated scope creep, and
for "fixes X" that only handles one path of X. The bot is forbidden from this by its own prompt.

**2. Right size of change** — both directions:
- *Too big*: carries changes the stated outcome doesn't need. An opportunistic refactor bundled
  with a bugfix also destroys clean revertability. Could this be 5 lines instead of 80?
- *Too small*: fixes the instance, not the class. Or leaves a new inconsistency, or other call
  sites still carry the same bug. **!2543 → !2544 is the canonical example**: flagging that
  Atlas `loops`/`companies` shared the `keyArgs` bug became a 359-line follow-up.
- *Wrong shape*: right total size, split wrong. Should be two MRs so the risky half can revert
  on its own.

**3. What's missing** — the bot's structural blind spot:
- feature-flag gate on new UI or behavior
- a test that would actually *catch* a regression on the tricky path
- error / empty / loading states
- migration or backfill for a schema change
- the other half of a FE/BE pair (is the backend merged *and deployed*?)
- cleanup: old code path, dead flag, or dead field left behind

**4. Blast radius.** Other callers of a changed function or component. The other app via shared
packages. Apollo cache implications. Data scoping. And whether behavior changes for **existing**
data, not just new.

**5. Consistency.** Does this match how the codebase already does it — `Stack`/`Group` over raw
flex, the `@mc/router` shim, public vs private GraphQL API — or does it fork a second way to do
something that already has one?

**6. Context and decisions.** Does it contradict a decision recorded in ai-brain? Does it touch
a paused or contested design (e.g. `work/mission/close-loop-redesign.md`)? Does it actually
satisfy the ticket's intent?

Checks 2, 3 and 6 frequently produce **no comment at all**. They are reasons to escalate to
Matt or to accept, not findings to post. That is the main difference from how the bot operates.

---

## 4. Triage tiers

Classify every MR into exactly one tier. The tier determines what the *skill* does with it.

### Tier 1 — straightforward
All of: diff read; the six checks come back clean; CI green, or red in a way that's understood
and unrelated; no Tier 3 trigger fires; confidence is high.

Typical: tests/stories/mocks/fixtures, dependency bumps, copy without logic, cosmetic UI, pure
refactors, bugfixes whose tricky path is already covered by a test.

### Tier 2 — objective issue, no judgment needed
There is a defensible finding with a clear fix, and no reasonable person needs to weigh in.

- Objective bug with a clear fix
- A tricky path with no test to catch it
- Cross-file inconsistency the bot cannot see (the `keyArgs`-drift class on !2544)
- **Reuse and abstraction**, both directions: a shared util/component already does this, *or*
  this is duplicated elsewhere and should be extracted into a shared one
- Missing feature-flag gate
- Cleanliness **only** where `claude_review` structurally cannot reach — cross-file placement,
  naming that only makes sense repo-wide. Otherwise defer to the bot.

### Tier 3 — needs Matt

**Escalate on unresolved risk, never on topic.** A subject area is a signal to look harder, not
a reason to forward. "This is a caching change" is not an escalation; "this is a caching change
and I could not establish that customer data stays isolated" is.

**(a) Always his call.** No amount of verification resolves these — they're taste, direction, or
authority, not facts:

- UI that the rubric in §5 scores as **Review**
- Product behavior: what it *should* do, not whether the code works
- Architecture direction: a new abstraction, pattern, or dependency the codebase will live with
- Contested or paused design areas — check ai-brain first
- **The author pushed back** on one of your comments. Arguing in Matt's voice is Matt's call.
- You disagree with the approach and it's a judgment call
- A right-size question you can't answer alone — should this be smaller, or does it need a
  follow-up MR

**(b) Verify first, then escalate only what's left.** These areas carry consequences big enough
to be worth real work before deciding. Do the work. If you can establish safety, say how and
treat it as Tier 1 or 2. Escalate the specific thing you couldn't settle, not the whole MR:

- Data scoping / RBAC / permissions / multi-tenancy
- Migrations, or irreversible/destructive changes
- Wide blast radius through shared packages

Worked example — !2544 keyed ~25 Apollo cache fields, including Atlas lists that had been
bleeding rows across customers. Topic alone says escalate. But the question "does customer
isolation hold?" is *answerable*: Atlas has no company-switch cache reset, so isolation depends
on the company scope sitting inside a keyed argument. Checking all three Atlas customer-scoped
lists showed `loops` and `awsAccounts` carry it in `where.and_`, and `meteredCharges` passes a
top-level `company` that is itself keyed. Isolation holds, tests prove it, so it was **Tier 2**
— comment on the maintenance risk and approve. Escalating it would have been offloading work
Matt would only have handed straight back.

**(c) Low confidence — always escalate.** The description and the code don't line up and you
can't tell why, or a check in §3 came back inconclusive and you've exhausted what a read can
settle. Name the specific unresolved question.

The confidence trigger is load-bearing. **Never** downgrade to Tier 1 to keep the Need Human
Review list short — and never inflate to Tier 3 to avoid doing the verification.

---

## 5. UI rubric — which UI changes reach Matt

Most should not. The question is *what kind* of change it is, not whether it renders. The
distinction doing the work: **JSX structure changed vs. only values changed.**

| Category | Signal in the diff | Action |
|---|---|---|
| **Workflow** | steps added/removed/reordered, new or changed route, nav change, form submit path changed, destructive action introduced | **Review** — highest priority |
| **Shared primitive** | `packages/ui/**` or `packages/tokens/**` **and** a visual or public-API change (props, variants, story diff) | **Review** |
| **New UI** | new component file, new `*.stories.*`, new page/route | **Review** |
| **Redesign** | JSX structure changed on something existing: nodes added/removed/reordered, variant swapped, element replaced | **Review** |
| **Removal** | component/story/page/route deleted, or an element dropped from a view | **Note** |
| **Shared primitive, internal only** | `packages/ui/**` paths, no prop/variant/story/visual change | Auto |
| **Cosmetic** | only className/style/token values, spacing, color, copy, a11y attrs, hover/focus states | Auto |

Tie-breakers:
- Spans categories → take the **highest** row.
- Cosmetic but sweeping (>~10 files or >~5 components) → **Note**. The risk there is regression,
  not design.
- Can't classify confidently → **Review**.

Meaning: **Auto** = no mention beyond the normal line. **Note** = fine to approve, but say it
happened. **Review** = Tier 3, goes to Matt.

Why `@m/ui` outranks almost everything: it lands in both apps at once, so the blast radius is
the whole codebase.

---

## 6. UX output — the part that has to be right

UI changes ship the moment they merge, and this is where Matt's time actually goes. Optimize
for **the fewest clicks that still let him judge it**.

**Always run the UX subagent on anything reaching Matt.** It is far cheaper than his attention.
It reviews the interaction against his design standards and returns findings. Include them
**summarized to a line or two** — never a full report, never auto-posted. UI is his call.

### Link ladder, in order of preference

1. **One link.** The default. The single most-useful story to look at. Most changes need nothing
   more.
2. **More links.** Only when the change spans components or states that one story can't show,
   and only for the ones carrying real nuance.
3. **Before/after pair.** Only when something that already existed changed visually and the
   *difference* is the point — redesigns, refactors with a visual delta.
4. **No link, and say so.** New UI has nothing to compare against, so MR-only. And pages or
   multi-step flows often have no story at all — say that Storybook can't show it and offer the
   local run, rather than handing over a link that won't answer the question.

### Mechanics

- Per-MR Storybook: the CI bot posts the URL as a comment on every MR, e.g.
  `https://missioncloud.gitlab.io/platform/control.missioncloud.com/mr-2544`. Already built by
  CI — no build cost to us.
- Live main, for the "before" half:
  `https://missioncloud.gitlab.io/platform/control.missioncloud.com/`
- Deep-link a specific story with `?path=/story/<story-id>`.
- **Storybook is behind GitLab SAML SSO.** Any fetch of it — including `index.json` — 302s to
  an SSO redirect, so you **cannot** look up story ids, verify a link resolves, or screenshot
  it with Playwright. Only Matt can open these URLs. Consequences:
  - Derive the story id from `.storybook/main.ts`: each entry maps a `directory` to a
    `titlePrefix`, and the auto-title is `<titlePrefix>/<path under directory, no extension>`.
    The id is that title plus `--<export>`, lowercased with every non-alphanumeric run
    collapsed to a single dash. camelCase is **not** split, so `CollaborationHub` becomes
    `collaborationhub`.
  - Treat the deep link as **unverified**. Always give the sidebar path next to it as a
    fallback (`Mission Control → features → … → Default`) so a wrong id costs him one click,
    not a dead end.
- **Local run is on-demand only**, triggered by Matt saying something like *"let's review
  Storybook on !X"*. Then pull the branch, run it, and hand back specific URLs. Remember
  `npm install` in a worktree or `@m/*` resolves to the main checkout (ai-brain
  `work/mission/worktree-node-modules-symlink-gotcha.md`).

---

## 7. Voice and posting mechanics

- Write every comment in Matt's voice per ai-brain `me/review-comment-voice.md` — short, plain,
  collaborative but decisive, no severity labels, state the effect and the fix rather than the
  mechanism, ` ```suggestion ` blocks for concrete fixes. **Read that note before drafting.**
- Post line-anchored comments per ai-brain `work/mission/reference/glab-inline-mr-comments.md`
  (`glab api --input` with a real nested `position` object plus an explicit JSON content-type
  header).
- **Leave your own optional/FYI threads unresolved.** The author resolves them as an
  acknowledgement that they saw it. This project blocks merge on unresolved threads, and that
  block is the forcing function — it costs nothing because the author resolves on their next
  pass. Only resolve a thread you opened if Matt says so. (Corrected 2026-08-24 on !2544.)

---

## 8. State

`~/.claude/mr-review-state.json`, keyed by MR iid. Survives session restarts.

```jsonc
"2544": {
  "project_id": 27492617,
  "reviewed_head_sha": "d354cf2e…",
  "action": "approved",           // free-text audit label
  "note": "…",                    // what you verified, in enough detail to answer later
  "status": "approved",           // needs_human | pending_ok | waiting_on_changes | approved | merged
  "title": "fix(cache): …",
  "web_url": "https://gitlab.com/…",
  "auto": true,                   // acted on without Matt
  "first_shown_session": null,    // set on first render; drives receipt clearing
  "escalation": null,             // which Tier 3 trigger fired
  "ui_category": null,            // workflow | shared | new | redesign | removal | cosmetic
  "recommendation": null,         // approve suggested | changes suggested | unsure
  "look_at": null,                // what specifically Matt should look at
  "ux_read": null,                // subagent findings, summarized
  "storybook": []                 // [{story, mr_url, main_url?}]
}
```

Per-MR flow:
- New MR → review it.
- Reviewed and head SHA unchanged → skip, nothing new.
- Reviewed and head SHA changed → treat as a re-request and review **only** the changes since
  `reviewed_head_sha`.
- Record the SHA only **after** acting (autonomous) or after Matt confirms (manual). Recording
  early makes a skipped MR look reviewed.

Keep `note` genuinely informative. It is the permanent audit trail — the thing that answers
"what's the deal with XYZ that you approved?" months later.

---

## 9. The report

Print it **in full, every pass**. It is an aggregate view, not a per-pass changelog — it does
not reset. Render it from the state file so the two can't drift.

Rules:
- **Omit empty sections.** If everything is empty, say so in one line.
- **Multi-line entries.** Title on its own line, details indented beneath. Never pack a long
  title, status, and URL onto one line with separators — it's unreadable.
- **URLs only under Need Human Review.** Nothing else needs one.

```
## Need Human Review
- !2294: Add bulk archive to the Loops list
  Recommendation: approve suggested
  Why you: workflow change, introduces a destructive bulk action
  Look at: the confirm step, it archives 20 loops with no undo
  UX read: no undo affordance, and the button says Archive while the copy implies delete
  Storybook: <one most-useful url>
  Question: want me to comment about undo, or approve as-is?
  https://gitlab.com/…/merge_requests/2294

## Waiting on Changes
- !9482: Fix metered charge rounding on invoice export
  commented 2d ago, nothing since

## Approved
- !2492: Key list caches by their query filters
  auto-approved

## Shipped without you
- !3934: Remove the legacy AwsAccounts filter panel
  auto-approved, merged
  removed: filter panel and its story
```

Section semantics:

- **Need Human Review** — the only section that pings. Every entry carries: recommendation,
  *why it came to you*, *what specifically to look at* (never "the whole change"), the
  subagent's read for UI, links, a concrete question, and the MR URL.
- **Pending your OK** — *manual skill only*. Analysis complete, waiting on a yes. Say which
  action is waiting: "verified clean, approve?" or "comment drafted, post it?"
- **Waiting on Changes** — comment posted and blocking, waiting on the author. Show age and
  whether they've pushed since.
- **Approved** — open, approved, not yet merged. Mark `auto-approved` or `approved by you`.
- **Shipped without you** — *auto skill only*. The receipt. **Only MRs approved without Matt.**
  Ones he approved himself drop off immediately; he already knows about those. Note-tier facts
  ("removed: …") belong here.

### Receipt retention

Stamp `first_shown_session` with `$CLAUDE_CODE_SESSION_ID` the first time an entry is rendered.

Drop a line from the screen only when `first_shown_session` is set **and** differs from the
current session — meaning Matt saw it, and has since cleared. Anything acted on while he was
away has no stamp yet, so it survives a `/clear` he never read and appears next session.

Nothing is ever deleted from the state file. On screen ≠ on record.

---

## 10. Notifications

Fire **one** `PushNotification` per pass, and only when **Need Human Review gains an entry** —
Matt is genuinely the blocker.

Never notify for: auto-approvals, auto-comments, idle passes, routine progress, or right after
he's replied and is clearly watching. Name the MR and what you need:
`"!2421 reviewed, clean — approve? (2 MRs waiting on you)"`

Reaches his phone only if Remote Control is connected; otherwise desktop-only. A "not sent"
result is normal when he's active at the terminal.

---

## 11. Running as a loop

Standalone: invoke the skill. Recurring: `/loop 15m /review-my-mrs-auto`, or self-paced.

Reviews aren't urgent, but latency has a real cost — 5 of the first 68 MRs merged before Matt
could act, wasting the review entirely. A 15-minute cadence on the autonomous skill is
reasonable. Don't hammer the API faster than that.
