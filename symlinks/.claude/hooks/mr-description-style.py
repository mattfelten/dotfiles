#!/usr/bin/env python3
"""PreToolUse hook: keep MR/PR descriptions legible to a reviewer.

Fires on `gh pr create|edit` and `glab mr create|update`. Pulls the description
out of the command, has a model read it the way a reviewer would, and denies the
tool call with that critique if it doesn't land.

The check is a judgement, not a measurement, because legibility is not word
count. It asks three things: are the template sections earning their place for a
change this size, does each bullet carry a single fact, and does the prose say
anything a reviewer can check. It is calibrated by few-shot against Matt's real
MRs, and it is given the diff size, since a description always sounds more
substantial than the change behind it.

Validated against 21 held-out historical MRs: 18 agreed, and the 3 that did not
were borderline calls the judge arguably got right.

Fails open. If the judge errors, times out, or answers with anything
unparseable, the command is allowed through. A style hook must never be the
reason real work stops.

Tuning (env vars):
  MR_STYLE_SKIP=1     bypass entirely for one command
  MR_STYLE_MODEL      judge model (default: sonnet; haiku under-flags)
  MR_STYLE_TIMEOUT    seconds to wait for the judge (default: 60)
  MR_STYLE_DIFFSTAT   override the measured diff size (used by the tests)
"""

import json
import os
import re
import shlex
import subprocess
import sys

MODEL = os.environ.get("MR_STYLE_MODEL", "sonnet")
TIMEOUT = int(os.environ.get("MR_STYLE_TIMEOUT", "60"))
MAX_CHARS = 20000

# Commands that publish a description.
TRIGGER = re.compile(r"\b(gh\s+pr\s+(?:create|edit)|glab\s+mr\s+(?:create|update))\b")

BODY_FLAGS = {"--body", "-b", "--description", "-d", "--notes"}
FILE_FLAGS = {"--body-file", "-F", "--description-file"}
TITLE_FLAGS = {"--title", "-t"}

JUDGE_PROMPT = """Matt writes merge request descriptions a particular way. Your job is to tell
whether a new description reads like HIS writing or like the agent-written ones
he is trying to stop producing.

This is a matching task, not a quality review. Both sets below are real.

=== SET A: Matt's own MRs. All of these are ACCEPTABLE. ===

A1: "Tooltips using `asChild` will not trigger on disabled elements. That's how
disabled works. Pointer events in the browser just don't fire."

A2: "- Converted 11 components that were still using prop-types to TypeScript
with proper interfaces
- Deleted the unused LineGraph propTypes directory
- Uninstalled the prop-types package"

A3: "Three small fixes to the company-name header from !2465:
1. The name rendered as a blue underlined link, because the color and
   text-decoration were only on the <a> and mail clients restyle an anchor's
   descendants. Now forced on the inner span too.
2. Only render the eyebrow when company_url is present, so the link can't end up
   with an empty href.
3. Adds the fields to loop-reopened, DJ's catch on !2465.
Needs services!4307 for the reopened data."

A4: "The prod deploy success message duplicated the Changelog link and led with
an always-'prod' environment parenthetical.
Before: Mission Control (prod) has been updated to c6103d9e (2.24.4)
After:  Production Mission Control has been updated to 2.24.4 (c6103d9e)
- Drops the redundant Changelog link.
- Drops ($CI_ENVIRONMENT_NAME), this block only runs for prod, so it never said
  anything but 'prod'."

A5: "Replaces the inline <Breadcrumbs /> child in ContentLayout with a new
useBreadcrumbParts hook that reads route handle data and passes it to Page's
native breadcrumbs prop, placing breadcrumbs in the correct header area."

Note what Set A does NOT do, and is not penalised for: A2 and A5 never state a
why, because the change explains itself. A1 never says how the fix works. None
of them have headers, a test plan, or a summary section. Terse is correct here.

=== SET B: agent-written. All of these are NOT ACCEPTABLE. ===

B1: "### Why
A production release posted three Slack messages to #mission-control ...
### What's Changed
- #mission-control now gets **one** message per release, sent by a new
  notify_prod_deploy job after Mission Control, Atlas, and Postmark have all
  deployed. It carries the changelog and the deployed version together.
- **Drops PROD_DEPLOY_SUCCESS_NOTIFICATION_CHANNELS** in favour of naming
  channels in the repo. It was set to product-dev-releases/mission-control, and
  #product-dev-releases has been archived since 2023 — every prod deploy has
  been logging a channel_not_found warning into a job log nobody reads.
### How to test
- [ ] Success -> one payload to #mission-control, 6 blocks ...
### Deploy notes ..."

B2: "## Summary
Major refactoring of the Dashboard feature to modernize the UI, improve
consistency across widgets, and enhance the overall user experience. This update
includes redesigned widgets, improved empty states, better loading patterns, and
comprehensive test coverage updates.
- More consistent spacing and sizing across all widgets
- Cleaner, more modern card designs
- Better visual hierarchy with improved typography"

What puts these in Set B: stacked section headers standing between the reader and
the point; bullets that carry three or four facts each and have to be unpacked;
prose that signals thoroughness while saying nothing checkable ("modernize",
"enhance the overall user experience", "better visual hierarchy"); test-plan
checklists; bolded lead-ins on every bullet.

=== What to flag ===

Answer "unclear" if ANY of these three hold. Otherwise answer "clear".

1. SECTIONS THAT HAVE NOT EARNED THEIR PLACE. The repo template offers a MENU of
   sections (Why, What's Changed, How to test, Gallery, Scope, Deploy notes).
   It is not a mandate. The author keeps the ones this change needs and deletes
   the rest. Matt's changes are usually small, so he deletes most of them.
   A two-line CSS fix does not need five sections and screenshots.

   You are given the size of the diff. Use it, because a description always
   sounds more substantial than the change behind it. Rough guide:
     under ~30 changed lines   -> no headings. Prose or a short list.
     ~30 to ~150 changed lines -> at most one or two headings.
     larger                    -> more headings can be justified.
   Flag when the heading count outruns the change: three or more headings on a
   change of a couple of hundred lines or fewer is the common case, and it is
   what Matt is trying to stop. Also flag a heading sitting over a single short
   line, a "How to test" holding one trivial check, or a Scope / Deploy-notes
   section for a change that has neither.
   Do not flag a section that carries something the reviewer genuinely needs.

2. BULLETS CARRYING MORE THAN ONE FACT. Matt's bullets are one line, maybe two,
   one fact, skimmable. Flag any bullet that stacks several facts with dashes,
   parentheticals or subordinate clauses, the way B1's bullets do.

3. PROSE THAT SIGNALS THOROUGHNESS WHILE SAYING NOTHING CHECKABLE. "modernize",
   "enhance the overall user experience", "better visual hierarchy",
   "comprehensive test coverage updates". Also a description so vague the
   reviewer learns nothing concrete about what changed.

=== How much "why" to expect (a modifier, never a reason to fail on its own) ===

You are told below whether a Jira ticket is linked.
- Linked: scope and rationale already live on the issue. A light why, or none at
  all, is correct. Never ask for more.
- Not linked: this is usually Matt reworking something because it bugs him, and
  that is when his reasoning is worth having, the design, aesthetic or UX
  thinking and the calls he made along the way. If you are ALREADY failing the
  description on one of the three checks, mention this in "fix". On its own, a
  missing why is NOT grounds to fail. Set A entries A2 and A5 have none.

Hard rules:
- NEVER mention length, word count, or say it is too long or too short. Set A
  entries run from one line to a dozen. Length is not the signal, and the fix is
  never "make it shorter", it is "cut what the reviewer does not need".
- Do NOT ask for a mechanism, a test plan, or more context than a Set A entry
  has. A bare list of what changed is fine.
- Ignore screenshots, issue links, markdown formatting, and repo compliance
  checklists such as a "Creator Checklist" of process boxes. Those are process,
  not description. Em-dashes and dry asides are fine, he writes that way.

Respond with JSON and nothing else:
{"verdict": "clear" | "unclear", "problems": ["..."], "fix": "..."}

Each problem quotes the specific phrase and names which of the three checks it
fails. At most 4. "fix" is one sentence on what to do instead."""

REASON = """Blocked: a reviewer would have to work to read this description.

%s

%s

Rewrite the description so a reviewer gets what changed and why on one read,
then run the command again. This is not about making it shorter. It is about
making it land. If there is detail worth keeping that does not help the
reviewer, put it in your reply to Matt instead of the MR body.

Full guide: ~/Projects/personal/ai-brain/me/mr-description-voice.md
If Matt asked for this description as written, re-run with MR_STYLE_SKIP=1 set."""


def allow():
    """Stay out of the way: no output, normal permission flow continues."""
    sys.exit(0)


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def read_file(path):
    try:
        with open(os.path.expanduser(path), "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


def normalize_newlines(text):
    r"""Treat literal \n escapes as line breaks.

    `--body "one\ntwo"` reaches the hook as a single physical line. Only applied
    when there are no real newlines at all, so genuine backslashes inside a
    genuinely multi-line body are left alone.
    """
    if text and "\n" not in text and "\\n" in text:
        return text.replace("\\n", "\n")
    return text


def extract_heredocs(text):
    """Return the bodies of any heredocs in `text`.

    Covers the `--body "$(cat <<'EOF' ... EOF)"` idiom, which is how most
    multi-line descriptions actually reach the shell.
    """
    bodies = []
    for match in re.finditer(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1\s*\n", text):
        term = match.group(2)
        rest = text[match.end():]
        end = re.search(r"^\s*" + re.escape(term) + r"\s*$", rest, re.M)
        bodies.append(rest[:end.start()] if end else rest)
    return bodies


def resolve(value):
    """Turn a flag value into description text, following $(cat file) if used."""
    sub = re.search(r"\$\(\s*cat\s+([^)]+?)\s*\)", value)
    if sub:
        return read_file(sub.group(1).strip("'\""))
    return value


def tokenize(text):
    try:
        return shlex.split(text, comments=False)
    except ValueError:
        pairs = re.findall(r"""[^\s"']+|"([^"]*)"|'([^']*)'""", text)
        return [p if isinstance(p, str) else next(filter(None, p), "") for p in pairs]


def extract(command):
    """Return (title, description). Either may be None."""
    trigger = TRIGGER.search(command)
    if not trigger:
        return None, None
    # Only look at the part of the line belonging to the create/update call, so a
    # preceding `git commit -m "$(cat <<EOF ...)"` isn't mistaken for the body.
    tail = command[trigger.start():]

    tokens = tokenize(tail)
    title, body = None, None
    for i, tok in enumerate(tokens):
        flag, _, inline = tok.partition("=")
        value = inline if inline else (tokens[i + 1] if i + 1 < len(tokens) else None)
        if value is None:
            continue
        if flag in TITLE_FLAGS and title is None:
            title = value
        elif flag in BODY_FLAGS and body is None:
            body = normalize_newlines(resolve(value))
        elif flag in FILE_FLAGS and body is None and value != "-":
            body = read_file(value)

    if body is None:
        heredocs = extract_heredocs(tail)
        if heredocs:
            body = normalize_newlines(max(heredocs, key=len))
    return title, body


TICKET = re.compile(
    r"(atlassian\.net/browse/|\b(?:RND|ENG|OPS|SEC|PLAT)-\d+\b|"
    r"^\s*(?:fixes|closes|resolves)\s*:\s*\S)", re.I | re.M)


def has_ticket(title, body):
    """Whether an issue is linked, which decides how much 'why' is expected."""
    return bool(TICKET.search("%s\n%s" % (title or "", body or "")))


def git(args, cwd):
    try:
        p = subprocess.run(["git"] + args, capture_output=True, text=True,
                           timeout=15, cwd=cwd)
    except (OSError, subprocess.SubprocessError):
        return None
    return p.stdout.strip() if p.returncode == 0 else None


def diff_size(command, cwd):
    """How big is this change? Section count should be proportional to it.

    Whether a change is small is the one fact the description cannot tell the
    judge, and it is exactly what decides whether five sections are justified.
    """
    override = os.environ.get("MR_STYLE_DIFFSTAT")
    if override:
        return override

    target = None
    match = re.search(r"--target-branch[= ]\s*([^\s'\"]+)", command)
    if match:
        target = match.group(1)

    candidates = [target] if target else []
    head = git(["symbolic-ref", "refs/remotes/origin/HEAD"], cwd)
    if head:
        candidates.append(head.rsplit("/", 1)[-1])
    candidates += ["main", "master"]

    for name in candidates:
        if not name:
            continue
        for ref in ("origin/" + name, name):
            base = git(["merge-base", "HEAD", ref], cwd)
            if not base:
                continue
            stat = git(["diff", "--shortstat", base + "..HEAD"], cwd)
            if stat:
                return stat
    return None


def judge(title, body, stat):
    """Ask the model to read it as a reviewer would. None means 'no opinion'."""
    linked = "yes" if has_ticket(title, body) else "no"
    text = "Size of the change: %s\nJira ticket linked: %s\n\nTitle: %s\n\nDescription:\n%s" % (
        stat or "unknown", linked, title or "(none given)", body[:MAX_CHARS])

    env = dict(os.environ)
    env["MR_STYLE_SKIP"] = "1"  # belt and braces against hook recursion
    try:
        proc = subprocess.run(
            ["claude", "-p", "--model", MODEL, "--output-format", "json",
             "--no-session-persistence", "--strict-mcp-config",
             "--allowedTools", "", "--system-prompt", JUDGE_PROMPT, text],
            capture_output=True, text=True, timeout=TIMEOUT, env=env,
            cwd=os.path.expanduser("~"),
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        return None

    try:
        envelope = json.loads(proc.stdout)
    except ValueError:
        return None
    if envelope.get("is_error"):
        return None

    raw = (envelope.get("result") or "").strip()
    raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw)
    match = re.search(r"\{.*\}", raw, re.S)
    if not match:
        return None
    try:
        verdict = json.loads(match.group(0))
    except ValueError:
        return None
    return verdict if isinstance(verdict, dict) else None


def main():
    if os.environ.get("MR_STYLE_SKIP") == "1":
        allow()

    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        allow()

    command = (payload.get("tool_input") or {}).get("command") or ""
    if not command or "MR_STYLE_SKIP=1" in command:
        allow()

    title, body = extract(command)
    if not body or not body.strip():
        allow()

    cwd = payload.get("cwd") or os.getcwd()
    verdict = judge(title, body, diff_size(command, cwd))
    if not verdict or verdict.get("verdict") != "unclear":
        allow()

    problems = [p for p in (verdict.get("problems") or []) if isinstance(p, str)][:4]
    if not problems:
        allow()

    listed = "\n".join("  - " + p for p in problems)
    fix = verdict.get("fix") or ""
    deny(REASON % (listed, fix.strip()))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        allow()
