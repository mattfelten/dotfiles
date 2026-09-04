# The description standard

The standard every MR/PR description gets held to. This file is the whole of it — read it before
writing, and don't work from memory.

The goal is **legibility, not brevity**. A reviewer should skim it and know what changed and why, so
they know what to look for. Short is a side effect of that, never the target. Bullets over
paragraphs is the mechanism, because a list can be glanced at and a paragraph has to be read.

## Two sections are mandatory

On every change, however small, in every repo. If the repo's template has them, they're already
there. If it has no template, use them anyway.

### Why / Purpose

Prose, not bullets. Its length depends on whether an issue is linked:

- **Issue linked** → **one high-level sentence**, and link out. The ticket carries the detail. Don't
  re-explain history that already lives on the ticket.
- **No issue linked** → **one to two paragraphs, maximum.** This is usually a rework of something
  that was bugging the author, so the design, aesthetic and UX thinking belongs here. This is where
  reasoning matters and it should not be thin.

### What's Changed

**Bullet points, never paragraphs.** This is the single most important rule. The reviewer should
glance down the list rather than read it.

One point per bullet, at most two sentences. A point may carry its cause and its fix together and
still be one point — don't split a coherent symptom-cause-fix, and don't count clauses. These are
correct:

- The name rendered as a blue underlined link. Colour and `text-decoration` were only on the `<a>`,
  and mail clients restyle an anchor's descendants, so both are now forced on the inner span.
- Drops `($CI_ENVIRONMENT_NAME)`, this block only runs for prod so it never said anything but "prod".

A bullet is doing too much only when it carries several unrelated points, or an argument running
past two sentences, so the reviewer has to stop and unpack it. Split that, or cut what the reviewer
doesn't need.

**Headings can be dropped when the shape is already obvious.** A straightforward change can open
with a Why paragraph, then a before/after, then bullets, with no headings at all. The sections have
to be *there*; they don't always need labels. What they can't be is missing.

## Every other section earns its weight

Never include one for something that can be worked out from the code. Each has a trigger:

| Section | Include it only when |
|---|---|
| Testing notes / How to test | this will be tricky for the reviewer to validate |
| Gallery / Screenshots | complex UI change, a narrow UX edge case that's hard to recreate, or an unexpected or uncommon UI pattern. Not a routine tweak or a label change |
| Deploy notes | rollout has a dependency: timing, feature flag swaps, dependent merges, ordering against another MR, or a manual step someone must run for the change to take effect. A plain consequence of merging is not a dependency |
| Alternative approaches | optional. One bullet per approach: what was tried, then why it was ruled out |

A one-line limitation doesn't need its own section — it can sit at the end of What's Changed.

## Voice

**Say it positively.** Stacked negatives make the reader undo each one to reach a simple point. Not
*"Rejects behind-the-scenes narration a no-context reviewer can't use"* (four negations for one
idea), but *"Flags narration of how the work happened. The reviewer wants the change, not the
process."* Same for vague openers: *"descriptions had drifted long"* says less than *"recent
descriptions have got long and hard to skim."*

**Nothing that only signals thoroughness.** "Modernize", "enhance the overall user experience",
"better visual hierarchy", "comprehensive test coverage updates" — all say nothing checkable.

Habits worth keeping: backtick identifiers freely; concrete before/after when the change is about
output; dry asides are welcome (*"this block only runs for prod, so it never said anything but
'prod'"*). Em-dashes are fine here.

## Never put behind-the-scenes content in a description

How an earlier attempt was built and abandoned, what was tried first, narration of the process,
validation numbers, references to a conversation. The reviewer has no context and can't use it. If
an abandoned approach is worth recording it goes in Alternative approaches as one bullet, not as
narrative. Anything else worth saying goes in the reply to the author, not the MR body.

**Explicitly fine, don't strip these:** crediting a colleague ("DJ's catch on !2465"), pointing at a
related MR, and noting a limitation of the change. All three are useful to a reviewer.

## Not criteria

- **Length.** Never aim for shorter. A long description of well-formed bullets is fine. The fix is
  never "make it shorter", it's "cut what the reviewer doesn't need" or "turn that into bullets".
- **The number of sections, on its own.** Four are correct when four triggers are met. Two are
  correct when they aren't.
- **Screenshots, issue links, markdown style, and repo compliance checklists** such as a Creator
  Checklist of process boxes. Those are process, and they're allowed.

## Calibration

Meets the standard:

```markdown
### Why
The prod deploy success message duplicated the Changelog link, already posted in the message right
before it, and led with an always-"prod" environment parenthetical.

### What's Changed
- Drops the redundant Changelog link.
- Drops ($CI_ENVIRONMENT_NAME), this block only runs for prod so it never said anything but "prod".
- Leads with "Production" and puts the version first, short SHA in parentheses.
- Same change applied to the internal debug channel's copy of the message.
```

No Gallery, no testing notes, no deploy notes, because none of those triggers were met. The bullets
carry one fact each and can be skimmed.

Does not:

```markdown
### Why
The 75% coverage thresholds have never been enforced ...

### What's Changed
Flattens the threshold keys so the gate is real, and adds merge_test_reports to combine the shards'
blob reports - a threshold can only be checked on whole-suite coverage, never per shard.

### How to test
- [x] Pipeline 2731738652 green
```

What's Changed is a paragraph where bullets belong, and How to test holds one trivial box that
didn't earn the section. The Why is good.

## Two failure modes to design against

Both are what an agent writes by default, and both are why this file exists.

- **Structured as a document when it should read as a note to a colleague.** Four or five headings,
  bullets running three or four lines and carrying several facts each, a five-box test checklist on
  a change that needs none. The content is rarely wrong; the shape is.
- **Absolute-quality judgement instead of this standard.** Asking "is this clear?" in the abstract
  gets it backwards: it fails terse, well-aimed writing and passes the long explanatory version.
  More explanation reads as better, which is the exact habit being corrected here. Judge against
  the rules above, not against a general sense of thoroughness.
