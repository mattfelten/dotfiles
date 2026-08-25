---
name: review-my-mrs-auto
description: Autonomously review the GitLab MRs where Matt is the requested reviewer — approving straightforward ones and posting objective comments on his behalf, escalating only judgment calls and UI to him. Use when Matt wants his review queue handled hands-off, or wants a recurring MR-review loop. For the version that waits for his approval on everything, use review-my-mrs.
---

# Review my MRs (autonomous)

One invocation = one full pass over the pending review queue. You act on your own conclusions
and bring Matt only what needs his judgment.

## First: read the rules

Read `~/.claude/skills/review-my-mrs/review-rules.md` before anything else. It is the single source
of truth for scope, what CI already covers, the six verification checks, the triage tiers, the
UI rubric, UX output, voice, state, the report format, and notifications.

Follow it exactly. The only thing this file adds is **what you're allowed to do with a
conclusion.**

## What you may do

| Tier | Action |
|---|---|
| **Tier 1** — straightforward | Approve. No ping. |
| **Tier 2** — objective issue | Post the comment, then approve if non-blocking, or leave it unapproved and move it to `Waiting on Changes` if blocking. No ping either way — nothing is being asked of Matt. |
| **Tier 3** — needs judgment | Do not act. Report it and ping once. |

Then record `reviewed_head_sha`, `status`, `auto`, and a substantive `note` in the state file.

## Approving is shipping

Matt's approval releases auto-merge, so a Tier 1 approval usually means the code reaches main.
Treat that as the real bar:

- **Never approve to keep the Need Human Review list short.** The low-confidence trigger in the
  rules exists precisely for this. If the description and the code don't line up and you
  can't tell why, that's Tier 3 — regardless of how small the diff is.
- If a later pass finds something you missed on an MR you already approved, **unapprove it**,
  post the finding, and put it in `Need Human Review` with what changed your mind.
- Never approve an MR whose UI the rubric scores as Review. Those ship on merge and are his call.

## Report sections

Use the rules' format, with this section set:

- `## Need Human Review` — Tier 3, full entry shape. The only section that pings.
- `## Waiting on Changes` — blocking comment posted, waiting on the author.
- `## Approved` — open, approved, not yet merged. Marked `auto-approved` or `approved by you`.
- `## Shipped without you` — the receipt. Only MRs *you* approved, now merged. This is how Matt
  avoids being blindsided by something he never saw. Include Note-tier facts here, e.g.
  `removed: filter panel and its story`.

**Omit `## Pending your OK`** — that's the manual skill's section. Nothing waits here.

## Notifications

Per the rules: one per pass, and **only** when `Need Human Review` gains an entry. Never for
auto-approvals, auto-comments, or idle passes — those are the whole point of this skill.

## Running as a loop

`/loop 15m /review-my-mrs-auto`, or self-paced. Latency has a real cost: 5 of the first 68 MRs
merged before Matt could act, wasting the review entirely. Don't poll faster than ~15 minutes.
