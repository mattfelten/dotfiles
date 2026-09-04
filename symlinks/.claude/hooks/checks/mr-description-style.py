#!/usr/bin/env python3
"""PreToolUse check: keep MR/PR descriptions legible to a reviewer.

Run by ../dispatch.sh, which only starts it when the command mentions `gh pr`
or `glab mr` (see checks.conf). Reads the hook payload on stdin. Prints a hook
JSON response to block, or nothing to let the command through.

Handles `gh pr create|edit` and `glab mr create|update`. Pulls the description
out of the command, has a model read it the way a reviewer would, and denies the
tool call with that critique if it doesn't land.

The check is structural, not a word count. Every description must carry a
Why/Purpose and a What's Changed written as bullets, one fact each, because a
reviewer skims a list and has to read a paragraph. Every other section (Gallery,
testing notes, deploy notes) has to meet a specific trigger to be there at all.
It also rejects behind-the-scenes narration of how the work happened, which a
no-context reviewer cannot use.

If the check itself breaks, the command runs anyway. A timeout, an unreadable
answer from the model, or a missing `claude` binary all let the MR through
rather than blocking it. A style hook should never be the reason work stops.

Tuning (env vars):
  MR_STYLE_SKIP=1     bypass entirely for one command
  MR_STYLE_MODEL      judge model (default: sonnet; haiku under-flags)
  MR_STYLE_TIMEOUT    seconds to wait for the judge (default: 60)
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

# The same rules are written for an author in ~/.claude/skills/write-mr/standard.md.
# This copy stays embedded on purpose. It is a judge rubric, not documentation:
# numbered "answer unclear if" checks, an explicit not-criteria list, few-shot
# examples and a JSON contract. Two things break if the judge is fed the prose
# version instead. Asking for quality in the abstract inverted the result on real
# MRs, failing terse writing and passing the long explanatory kind; and a rule
# buried in prose gets under-weighted, which is why the why-length rule sits in
# the numbered list. Enforcement also should not change every time an authoring
# doc is reworded. Change a rule in both places, and re-validate against real MRs.
JUDGE_PROMPT = """You are checking a merge request description against the standard Matt holds
his team to. Answer whether it meets that standard.

=== The shape every description must have ===

TWO SECTIONS ARE MANDATORY, on every change, however small, in every repo. If
the repo has an MR template these are already in it. If it has no template, use
these headings anyway.

  Why (or Purpose) - what problem or goal this addresses. Prose, not bullets.
  Length depends on whether an issue is linked:
    issue linked     -> ONE high-level sentence, and let the ticket carry the
                        detail. Do not ask for more, and flag a Why that runs to
                        several paragraphs when the context is already on the
                        ticket.
    no issue linked  -> one to two paragraphs at most. This is usually Matt
                        reworking something because it bugs him, so the design,
                        aesthetic or UX thinking belongs here. Flag it if it
                        goes past two paragraphs.

  What's Changed - BULLET POINTS. Never paragraphs. One fact per bullet, one
  line, maybe two. The reviewer must be able to glance down this list, not read
  it. This is the single most important rule: paragraphs are much harder to
  read than bullets.

EVERY OTHER SECTION MUST EARN ITS WEIGHT. Include one only when its trigger is
genuinely met, and never for something the reviewer could work out from the code:

  Testing notes  - only if this will be tricky for the reviewer to validate.
  Gallery        - only for a complex UI change, a narrow UX edge case that is
                   hard to recreate, or an unexpected or uncommon UI pattern.
                   Not for a routine visual tweak or a label change.
  Deploy notes   - only if rolling this out has a dependency of any kind:
                   timing, feature flag swaps, dependent merges, ordering
                   against another MR, or a manual step someone must run for the
                   change to take effect. A plain consequence of merging is not
                   a dependency, and a one-line limitation does not need its own
                   section, it can sit at the end of What's Changed.
  Alternative approaches - optional. One bullet per approach: a sentence on what
                   was tried, then why it was ruled out.

=== Answer "unclear" if any of these hold ===

1. MISSING A MANDATORY SECTION. No Why/Purpose, or no What's Changed. A bare
   list of changes with no why fails. So does a why with no list of changes.

2. WHAT'S CHANGED WRITTEN AS PROSE, OR BULLETS THAT CANNOT BE SKIMMED.
   Paragraphs where bullets belong.

   The test for a bullet is ONE POINT, at most two sentences, readable at a
   glance. A point may include its cause and its fix. Do NOT split a coherent
   symptom-cause-fix into separate bullets, and do not count clauses. These are
   correct and must NOT be flagged:
     "- The name rendered as a blue underlined link. Colour and text-decoration
        were only on the <a>, and mail clients restyle an anchor's descendants,
        so both are now forced on the inner span."
     "- Drops ($CI_ENVIRONMENT_NAME), this block only runs for prod so it never
        said anything but 'prod'."

   Flag a bullet only when it is genuinely doing too much: several unrelated
   points, or an argument running past two sentences, so the reviewer has to
   stop and unpack it. Like this:
     "- **Drops PROD_DEPLOY_SUCCESS_NOTIFICATION_CHANNELS** in favour of naming
        channels in the repo. It was set to product-dev-releases/mission-control,
        and #product-dev-releases has been archived since 2023, so every prod
        deploy has been logging a channel_not_found warning into a job log nobody
        reads. Channel names aren't secrets and don't vary by environment, so
        routing belongs where it gets reviewed."
   That is four unrelated points and an argument, well past two sentences.
   Split it, or cut what the reviewer does not need.

3. AN OPTIONAL SECTION THAT HAS NOT EARNED ITS TRIGGER. A Gallery for a label
   change or a routine tweak. Testing notes for something the reviewer can
   obviously check, or a single trivial box. Deploy notes with no real
   dependency. A section holding one short line that belonged in What's Changed.

4. BEHIND-THE-SCENES OR PROCESS CONTENT. Anything that only makes sense to
   someone who watched the work happen: how an earlier attempt was built and
   abandoned, what the author tried first, narration of the development process,
   validation scores, references to a conversation. The reviewer has no context
   and does not need it. If an abandoned approach is genuinely worth recording,
   it belongs in Alternative approaches as one bullet, not as narrative.
   This does NOT cover crediting a colleague ("DJ's catch on !2465"), pointing at
   a related MR, or noting a limitation of the change. Those are useful to a
   reviewer and Matt writes them. Do not flag them.

5. A WHY OUT OF PROPORTION TO THE LINKED ISSUE. You are told below whether one
   is linked. If it is, the Why should be about one high-level sentence, with
   the ticket carrying the rest, so flag a Why that runs to multiple paragraphs
   or re-explains the history the ticket already holds. If no issue is linked,
   one to two paragraphs is the ceiling.

6. A SENTENCE THAT HAS TO BE UNPACKED TO GET A SIMPLE IDEA. Almost always
   stacked negatives: "Rejects behind-the-scenes narration a no-context reviewer
   can't use" carries four negations for one plain point, and the reader has to
   undo each one to reach it. Say it positively instead: "Flags narration of how
   the work happened. The reviewer wants the change, not the process."
   Judge how hard the sentence is to PARSE, not whether you would have picked
   different words. A plain sentence that summarises and then elaborates in the
   next one is fine, that is normal writing. Do not flag it.

7. PROSE THAT SIGNALS THOROUGHNESS WHILE SAYING NOTHING CHECKABLE. "modernize",
   "enhance the overall user experience", "better visual hierarchy",
   "comprehensive test coverage updates". Or a description so vague the reviewer
   learns nothing concrete.

=== Not criteria ===

- LENGTH. Never say a description is too long or too short, and never mention
  word or line count. A long description of well-formed bullets is fine. The
  fix is never "make it shorter", it is "cut what the reviewer does not need"
  or "turn that into bullets".
- The number of sections, judged on its own. Four sections are correct when all
  four triggers are met. Two are correct when they are not.
- Screenshots, issue links, markdown style, and repo compliance checklists such
  as a "Creator Checklist" of process boxes. Ignore those, they are process.
- Em-dashes and dry asides. He writes that way.

=== How much "why" to expect ===

You are told whether a Jira ticket is linked. The Why section is required either
way, but its depth changes:
- Linked: scope and rationale live on the issue. A brief why is correct. Do not
  ask for more.
- Not linked: usually Matt reworking something because it bugs him, and that is
  when his reasoning matters. Expect the design, aesthetic or UX thinking and
  the calls made along the way.

=== A description that meets the standard ===

  ### Why
  The prod deploy success message duplicated the Changelog link, already posted
  in the message right before it, and led with an always-"prod" environment
  parenthetical.

  ### What's Changed
  - Drops the redundant Changelog link.
  - Drops ($CI_ENVIRONMENT_NAME), this block only runs for prod so it never said
    anything but "prod".
  - Leads with "Production" and puts the version first, short SHA in parentheses.
  - Same change applied to Atlas and the internal #services-debug message.

No Gallery, no testing notes, no deploy notes, because none of those triggers
were met. Note the bullets: one fact each, skimmable.

=== One that does not ===

  ### Why
  The 75% coverage thresholds have never been enforced ...

  ### What's Changed
  Flattens the threshold keys so the gate is real, and adds merge_test_reports
  to combine the shards' blob reports - a threshold can only be checked on
  whole-suite coverage, never per shard.

  ### How to test
  - [x] Pipeline 2731738652 green

What's Changed is a paragraph and should be bullets (check 2), and How to test
holds one trivial box (check 3). The Why is good.

Respond with JSON and nothing else:
{"verdict": "clear" | "unclear", "problems": ["..."], "fix": "..."}

Each problem quotes the specific phrase and names which check it fails. At most
4. "fix" is one sentence on what to do instead."""


REASON = """Blocked: a reviewer would have to work to read this description.

%s

%s

Every description needs a Why/Purpose and a What's Changed written as bullets,
one fact each. Gallery, testing notes and deploy notes go in only when the
change actually calls for them.

Rewrite and run the command again. This is not about making it shorter. If there
is detail worth keeping that does not help the reviewer, put it in your reply to
Matt instead of the MR body.

Full guide: ~/.claude/skills/write-mr/standard.md
Composing one: the write-mr skill reconciles that standard with the repo's own
MR template, and runs this check on demand before you publish.
If Matt asked for this description as written, re-run with MR_STYLE_SKIP=1 set."""


def allow():
    """Let the command through: no output, normal permission flow continues."""
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


def judge(title, body):
    """Ask the model to read it as a reviewer would. None means 'no opinion'."""
    linked = "yes" if has_ticket(title, body) else "no"
    text = "Jira ticket linked: %s\n\nTitle: %s\n\nDescription:\n%s" % (
        linked, title or "(none given)", body[:MAX_CHARS])

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

    verdict = judge(title, body)
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
