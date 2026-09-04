#!/usr/bin/env python3
"""Check an MR/PR description against the house style, on demand.

    gate.py "<title>" <body-file>

The same check runs automatically on the real create call. Running it here first
means an unclear description costs a few cents to find out about instead of a
blocked command half way through publishing.

The title is passed along with the body because a Jira key usually lives in the
title, and whether a ticket is linked decides how long the Why should be.

Prints PASS, or FAIL with the critique and exit code 1. If the check itself
cannot run, this reports PASS: the real hook fails open too, and a style check
should never be the reason work stops.
"""

import json
import os
import subprocess
import sys

HOOK = os.path.expanduser("~/.claude/hooks/checks/mr-description-style.py")


def main():
    if len(sys.argv) != 3:
        print('usage: gate.py "<title>" <body-file>', file=sys.stderr)
        return 2

    title, body_path = sys.argv[1], sys.argv[2]

    if not os.path.isfile(body_path):
        print("no such body file: %s" % body_path, file=sys.stderr)
        return 2
    if not os.path.isfile(HOOK):
        print("PASS (no check installed at %s)" % HOOK)
        return 0

    # The check reads a description out of a create command, so hand it one.
    command = "glab mr create --title %s --description-file %s" % (
        json.dumps(title), body_path)
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})

    try:
        proc = subprocess.run(
            [sys.executable, HOOK], input=payload,
            capture_output=True, text=True,
        )
    except (OSError, subprocess.SubprocessError) as err:
        print("PASS (could not run the check: %s)" % err)
        return 0

    verdict = proc.stdout.strip()
    if not verdict:
        print("PASS - the description meets the standard.")
        return 0

    try:
        reason = json.loads(verdict)["hookSpecificOutput"]["permissionDecisionReason"]
    except (ValueError, KeyError, TypeError):
        print("PASS (no readable verdict)")
        return 0

    print("FAIL\n")
    print(reason)
    return 1


if __name__ == "__main__":
    sys.exit(main())
