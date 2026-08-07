#!/usr/bin/env python3
"""Regression tests for the hook's command parsing. No model calls.

The judge is validated separately against real MRs (validate.py). What this
covers is the fiddly part: getting the description out of a shell command.
"""
import importlib.util, os, shlex, sys, tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "symlinks", ".claude", "hooks", "checks", "mr-description-style.py")
spec = importlib.util.spec_from_file_location("h", HOOK)
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)

q = shlex.quote
BODY = "Adds the ignored-sum field.\nCrux is the reducer."
NOVEL = "## Why\n\nSome long thing.\n\n## What\n\nMore."

fd, TMP = tempfile.mkstemp(suffix=".md")
os.write(fd, BODY.encode())
os.close(fd)

CASES = [
    ("unrelated command", "npm test && git push", None, None),
    ("gh --body", "gh pr create --title 'T' --body %s" % q(BODY), "T", BODY),
    ("glab --description", "glab mr create --description %s" % q(BODY), None, BODY),
    ("glab mr update", "glab mr update 2501 --description %s" % q(BODY), None, BODY),
    ("gh pr edit", "gh pr edit 42 --body %s" % q(BODY), None, BODY),
    ("--body= inline", "gh pr create --body=%s" % q(BODY), None, BODY),
    ("-d short flag", "glab mr create -d %s" % q(BODY), None, BODY),
    ("--body-file", "gh pr create --body-file %s" % TMP, None, BODY),
    ("$(cat file)", 'glab mr create --description "$(cat %s)"' % TMP, None, BODY),
    ("heredoc", "gh pr create --title 'T' --body \"$(cat <<'EOF'\n%s\nEOF\n)\"" % BODY, "T", BODY),
    ("body-file stdin", "gh pr create --body-file -", None, None),
    ("no body flag", "gh pr create --fill", None, None),
    # a commit heredoc must not be mistaken for the description
    ("commit heredoc then pr",
     "git commit -m \"$(cat <<'EOF'\n%s\nEOF\n)\" && gh pr create --body %s" % (NOVEL, q(BODY)),
     None, BODY),
    # literal \n escapes must become real lines so heading logic works
    ("literal backslash-n", 'gh pr create --body "%s"' % NOVEL.replace("\n", "\\n"), None, NOVEL),
]

fails = 0
for name, cmd, want_title, want_body in CASES:
    title, body = h.extract(cmd)
    norm = body.rstrip('\n') if body else body
    ok = norm == want_body and (want_title is None or title == want_title)
    fails += not ok
    print("%s  %-24s" % ("PASS" if ok else "FAIL", name), end="")
    print("" if ok else "  got title=%r body=%r" % (title, body))

# ticket detection drives how much "why" the judge expects
TICKETS = [
    ("jira url", "", "See https://mission-engineering.atlassian.net/browse/RND-4809", True),
    ("bare key in title", "fix(x): thing (RND-4777)", "", True),
    ("Fixes: line", "", "Fixes: RND-1234", True),
    ("no ticket", "fix: tooltip", "Pointer events don't fire.", False),
]
for name, title, body, want in TICKETS:
    got = h.has_ticket(title, body)
    fails += got != want
    print("%s  ticket:%-17s" % ("PASS" if got == want else "FAIL", name))

os.unlink(TMP)
print("\n%d/%d passed" % (len(CASES) + len(TICKETS) - fails, len(CASES) + len(TICKETS)))
sys.exit(1 if fails else 0)
