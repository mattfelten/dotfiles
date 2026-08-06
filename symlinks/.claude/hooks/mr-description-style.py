#!/usr/bin/env python3
"""PreToolUse hook: enforce Matt's MR/PR description writing style.

Fires on `gh pr create|edit` and `glab mr create|update`. Extracts the
description body from the command, measures it, and denies the tool call with
a rewrite instruction if it reads long-winded.

This is deliberately NOT project-specific. Repo templates, checklists,
screenshots, code fences and HTML comments are stripped out before anything is
counted, so a project's own template can be as elaborate as it likes. What gets
measured is the prose Matt would have written himself.

Tuning (env vars):
  MR_STYLE_SKIP=1           bypass entirely for one command
  MR_STYLE_MAX_WORDS        total prose words (default 110)
  MR_STYLE_MAX_SECTION      prose words in any one section (default 45)
  MR_STYLE_MAX_BULLETS      bullet lines (default 8)
"""

import json
import os
import re
import shlex
import sys

MAX_WORDS = int(os.environ.get("MR_STYLE_MAX_WORDS", "110"))
MAX_SECTION_WORDS = int(os.environ.get("MR_STYLE_MAX_SECTION", "45"))
MAX_BULLETS = int(os.environ.get("MR_STYLE_MAX_BULLETS", "8"))

# Commands that publish a description. Group 1 = tool, group 2 = subcommand.
TRIGGER = re.compile(r"\b(gh\s+pr\s+(?:create|edit)|glab\s+mr\s+(?:create|update))\b")

BODY_FLAGS = {"--body", "-b", "--description", "-d", "--notes"}
FILE_FLAGS = {"--body-file", "-F", "--description-file"}

# Phrases that signal padding rather than information. Kept short on purpose:
# every entry here has to be worth blocking an MR over.
FILLER = [
    (r"\bthis (?:mr|pr|change|commit) (?:does|will|introduces|implements|adds|aims)\b",
     'opening with "This MR does..." — lead with the change itself'),
    (r"\bin this (?:mr|pr)\b", '"In this MR" — the reader knows where they are'),
    (r"\bsummary of (?:the )?changes\b", '"Summary of changes" heading — just say what changed'),
    (r"\bas (?:mentioned|noted|described) (?:above|below|earlier)\b", "back-reference filler"),
    (r"\bit(?:'s| is) worth noting\b", '"it\'s worth noting"'),
    (r"\bplease note that\b", '"please note that"'),
    (r"\bin order to\b", '"in order to" — use "to"'),
    (r"\bthe purpose of this\b", '"the purpose of this"'),
    (r"—", "em-dash — use commas and periods"),
    (r"\bco-authored-by\b", "Co-Authored-By line"),
    (r"generated with \[?claude", "Claude Code footer"),
    (r"🤖", "robot emoji footer"),
]

HEADING = re.compile(r"^\s{0,3}#{1,6}\s")
CHECKLIST = re.compile(r"^\s*[-*+]\s*\[[ xX]\]")
BULLET = re.compile(r"^\s*(?:[-*+]|\d+\.)\s+\S")
ISSUE_REF = re.compile(r"^(closes|close|fixes|fix|resolves|resolve|refs|ref|part of|related)\b", re.I)


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


def normalize_newlines(text):
    r"""Treat literal \n escapes as line breaks.

    `--body "one\ntwo"` reaches the hook as a single physical line, which would
    hide every heading and bullet from the line-based checks below. Only applied
    when there are no real newlines at all, so genuine backslashes inside a
    genuinely multi-line body are left alone.
    """
    if "\n" not in text and "\\n" in text:
        return text.replace("\\n", "\n")
    return text


def extract_description(command):
    """Pull the description out of the command, or None if there isn't one."""
    trigger = TRIGGER.search(command)
    if not trigger:
        return None
    # Only look at the part of the line that belongs to the create/update call,
    # so a preceding `git commit -m "$(cat <<EOF ...)"` isn't mistaken for it.
    tail = command[trigger.start():]

    heredocs = extract_heredocs(tail)
    if heredocs:
        return normalize_newlines(max(heredocs, key=len))

    try:
        tokens = shlex.split(tail, comments=False)
    except ValueError:
        tokens = re.findall(r"""[^\s"']+|"([^"]*)"|'([^']*)'""", tail)
        tokens = [t if isinstance(t, str) else next(filter(None, t), "") for t in tokens]

    for i, tok in enumerate(tokens):
        flag, _, inline = tok.partition("=")
        value = inline if inline else (tokens[i + 1] if i + 1 < len(tokens) else None)
        if value is None:
            continue
        if flag in BODY_FLAGS:
            resolved = resolve(value)
            return normalize_newlines(resolved) if resolved else resolved
        if flag in FILE_FLAGS:
            if value == "-":
                return None  # stdin, can't see it
            return read_file(value)
    return None


def strip_scaffolding(text):
    """Remove everything that isn't Matt's own prose."""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)          # template comments
    text = re.sub(r"```.*?```", "", text, flags=re.S)           # fenced code
    text = re.sub(r"`[^`\n]*`", "", text)                       # inline code
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)            # images / screenshots
    text = re.sub(r"<img[^>]*>", "", text, flags=re.I)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)        # links -> label only

    kept = []
    for line in text.split("\n"):
        s = line.strip()
        if not s:
            kept.append("")
            continue
        if HEADING.match(line):        # template section titles
            continue
        if CHECKLIST.match(line):      # template checklists
            continue
        if s.startswith("/"):          # gitlab quick actions (/label, /assign)
            continue
        if s.startswith("|") or re.match(r"^[-=|:+]{3,}$", s):  # tables, rules
            continue
        if ISSUE_REF.match(s):         # Closes #123
            continue
        kept.append(line)
    return "\n".join(kept)


def count_words(text):
    return len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'’/._-]*", text))


def split_sections(body):
    """Split on markdown headings, falling back to blank-line paragraphs."""
    lines = body.split("\n")
    if any(HEADING.match(l) for l in lines):
        sections, title, buf = [], "opening", []
        for line in lines:
            if HEADING.match(line):
                sections.append((title, "\n".join(buf)))
                title = line.strip().lstrip("#").strip() or "section"
                buf = []
            else:
                buf.append(line)
        sections.append((title, "\n".join(buf)))
        return [(t, b) for t, b in sections if b.strip()]
    paras = [p for p in re.split(r"\n\s*\n", body) if p.strip()]
    return [("paragraph %d" % (i + 1), p) for i, p in enumerate(paras)]


def check(body):
    problems = []
    prose = strip_scaffolding(body)

    total = count_words(prose)
    if total > MAX_WORDS:
        problems.append("%d words of prose (max %d)" % (total, MAX_WORDS))

    sections = split_sections(body)
    for title, raw in sections:
        words = count_words(strip_scaffolding(raw))
        if words > MAX_SECTION_WORDS:
            label = "the description" if len(sections) == 1 else '"%s"' % title
            problems.append("%s is %d words (max %d per section)"
                            % (label, words, MAX_SECTION_WORDS))

    bullets = sum(1 for l in prose.split("\n") if BULLET.match(l))
    if bullets > MAX_BULLETS:
        problems.append("%d bullets (max %d)" % (bullets, MAX_BULLETS))

    lowered = prose.lower()
    for pattern, label in FILLER:
        if re.search(pattern, lowered):
            problems.append("filler: %s" % label)

    return problems


REASON = """Blocked: this MR/PR description does not match Matt's writing style.

What tripped it:
%s

Matt's style, regardless of project:
  - Lead with ONE sentence: what the change does, and the crux to review. For a
    normal MR that sentence is the entire description.
  - Keep whatever sections the repo template requires, but one line each.
  - Add a line only for what the reviewer cannot see in the diff: a non-obvious
    deploy order, a real gotcha, where the core logic lives.
  - Do not restate the diff. Do not pad to look thorough.
  - Plain and literal. Commas and periods, no em-dashes, no metaphor, no hedging.
  - Analysis, benchmarks and rationale go to Matt in chat, never in the MR body.

Rewrite the description and run the command again. Long-form detail you were
about to include is not lost, put it in your reply to Matt instead.

Full guide: ~/Projects/personal/ai-brain/me/mr-description-voice.md
If Matt explicitly asked for a long description, re-run with MR_STYLE_SKIP=1 set."""


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

    body = extract_description(command)
    if not body or not body.strip():
        allow()

    problems = check(body)
    if problems:
        deny(REASON % "\n".join("  - " + p for p in problems))
    allow()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # A broken style hook must never block real work.
        allow()
