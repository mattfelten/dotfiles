#!/usr/bin/env python3
"""Render the aggregate MR review report from state.

Usage:
    glab api "projects/<id>/merge_requests?reviewer_username=<me>&state=opened" \
      | python3 render-report.py --mode manual|auto --session "$CLAUDE_CODE_SESSION_ID"

Reads ~/.claude/mr-review-state.json for what is known about each MR, and the live
open-queue JSON on stdin for what is still actionable. Prints the report.

Rules this encodes (see review-rules.md):
  - Sections are omitted when empty; all-empty prints one line.
  - Entries are multi-line: title on its own line, details indented.
  - URLs appear only in the section that needs Matt to act.
  - Receipt lines drop once first_shown_session is set and differs from the
    current session, i.e. Matt saw it and has since cleared the conversation.
"""
import argparse
import json
import os
import sys

STATE = os.path.expanduser("~/.claude/mr-review-state.json")

SECTIONS = {
    "manual": ["needs_human", "pending_ok", "waiting_on_changes", "approved"],
    "auto": ["needs_human", "waiting_on_changes", "approved", "shipped"],
}
HEADINGS = {
    "needs_human": "Need Human Review",
    "pending_ok": "Pending your OK",
    "waiting_on_changes": "Waiting on Changes",
    "approved": "Approved",
    "shipped": "Shipped without you",
}
# the section where Matt has to do something, so it carries the URL
ACTIONABLE = {"manual": {"needs_human", "pending_ok"}, "auto": {"needs_human"}}


def entry_lines(e, section, mode):
    out = [f"- !{e['iid']}: {e.get('title') or '(no title)'}"]
    pad = "  "
    if section == "needs_human":
        for label, key in [
            ("Recommendation", "recommendation"),
            ("Why you", "escalation"),
            ("Look at", "look_at"),
            ("UX read", "ux_read"),
        ]:
            if e.get(key):
                out.append(f"{pad}{label}: {e[key]}")
        for sb in e.get("storybook") or []:
            if sb.get("main_url"):
                out.append(f"{pad}Storybook: [MR] {sb['mr_url']}")
                out.append(f"{pad}           [main] {sb['main_url']}")
            else:
                out.append(f"{pad}Storybook: {sb['mr_url']}")
        if e.get("question"):
            out.append(f"{pad}Question: {e['question']}")
    elif section == "pending_ok":
        out.append(f"{pad}{e.get('pending') or 'verified clean, approve?'}")
    elif section == "waiting_on_changes":
        out.append(f"{pad}{e.get('waiting') or 'comment posted, waiting on author'}")
    else:
        out.append(f"{pad}{'auto-approved' if e.get('auto') else 'approved by you'}")
        if e.get("note_tier"):
            out.append(f"{pad}{e['note_tier']}")
    if section in ACTIONABLE[mode] and e.get("web_url"):
        out.append(f"{pad}{e['web_url']}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["manual", "auto"], required=True)
    ap.add_argument("--session", default=os.environ.get("CLAUDE_CODE_SESSION_ID", ""))
    args = ap.parse_args()

    state = json.load(open(STATE)) if os.path.exists(STATE) else {}
    live = json.load(sys.stdin) if not sys.stdin.isatty() else []
    open_iids = {str(m["iid"]): m for m in live}

    buckets = {k: [] for k in SECTIONS[args.mode]}
    for iid, m in open_iids.items():
        e = dict(state.get(iid, {}))
        e.update({"iid": iid, "title": m.get("title"), "web_url": m.get("web_url")})
        st = e.get("status", "needs_human")
        # stale or foreign state on a still-open MR means re-review, never drop.
        # pending_ok is the manual skill's section, so the auto skill re-reviews
        # it rather than letting it vanish when Matt switches modes.
        stale = {"merged", "reviewed", "shipped"}
        if args.mode == "auto":
            stale.add("pending_ok")
        if st in stale:
            st = "needs_human"
        if st in buckets:
            buckets[st].append(e)

    # the receipt is history, not the live queue: only MRs acted on without Matt,
    # and only until he has both seen them and cleared the conversation
    if "shipped" in buckets:
        for iid, e in state.items():
            if iid in open_iids or e.get("status") != "merged" or not e.get("auto"):
                continue
            shown = e.get("first_shown_session")
            if shown and shown != args.session:
                continue
            buckets["shipped"].append({**e, "iid": iid})

    blocks = []
    for key in SECTIONS[args.mode]:
        items = buckets[key]
        if not items:
            continue
        lines = [f"## {HEADINGS[key]}"]
        for e in sorted(items, key=lambda x: -int(x["iid"])):
            lines += entry_lines(e, key, args.mode)
        blocks.append("\n".join(lines))

    print("\n\n".join(blocks) if blocks
          else "Queue clear. Nothing waiting on you and nothing in flight.")


if __name__ == "__main__":
    main()
