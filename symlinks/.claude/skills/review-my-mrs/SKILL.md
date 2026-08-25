---
name: review-my-mrs
description: Review the GitLab MRs where Matt is the requested reviewer, in his voice, and wait for his decision on everything. Never approves or comments on its own. Use when Matt says "review my MRs", "check my review queue", or wants to go through his review queue together. For the hands-off version that approves and comments by itself, use review-my-mrs-auto.
---

# Review my MRs (manual)

One invocation = one full pass over the pending review queue. You do the complete analysis and
present it. **Matt decides every action.**

## First: read the rules

Read `~/.claude/skills/review-my-mrs/review-rules.md` before anything else. It is the single source
of truth for scope, what CI already covers, the six verification checks, the triage tiers, the
UI rubric, UX output, voice, state, the report format, and notifications.

Follow it exactly. The only thing this file adds is **what you're allowed to do with a
conclusion.**

## This skill never acts

Hard rules, no exceptions:

- **Never approve.** Not even a Tier 1 MR you're certain about.
- **Never post a comment, reply, or resolve a thread.**
- **Never record `reviewed_head_sha`** until Matt has confirmed the action for that MR.
  Recording early makes a skipped MR look reviewed on the next pass.

Everything else in the rules still happens: full six-check analysis, UI rubric scoring, the
UX subagent on anything UI-related, drafted comments written in his voice and ready to post.

Do the work, then stop and ask.

## Report sections

Use the rules' format, with this section set:

- `## Need Human Review` — Tier 3. Judgment calls, with the full entry shape from the rules.
- `## Pending your OK` — Tier 1 and Tier 2. Analysis done, waiting on a yes. State which action
  is waiting: `verified clean, approve?` or `comment drafted, post it?`
- `## Waiting on Changes` — comments Matt already approved posting, now waiting on the author.
- `## Approved` — open, approved, not yet merged. All marked `approved by you`, since nothing
  here approves itself.

**Omit `## Shipped without you`** — it exists to cover MRs approved without Matt looking, which
this skill never produces.

## Acting after he answers

When Matt says go on something:

1. Do exactly what he approved, nothing adjacent.
2. Post comments per the rules' mechanics, then approve if that's what he asked for.
3. **Then** record `reviewed_head_sha` and update `status` and `note` in the state file.
4. Report back what landed, with URLs.

If he approves some items and not others, act only on the ones he named and leave the rest
sitting in `Pending your OK`.

## Notifications

Per the rules: one per pass, only when Matt is genuinely the blocker. In this skill that
includes a non-empty `Pending your OK`, since nothing moves without him.
