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
import textwrap

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


WIDTH = 76
COUNT = {1: "one thing", 2: "two things", 3: "three things", 4: "four things"}


def wrap(text, first, cont):
    """Wrap text to WIDTH with a hanging indent."""
    return textwrap.wrap(
        text, width=WIDTH, initial_indent=first, subsequent_indent=cont
    ) or [first.rstrip()]


def needs_human_lines(e):
    """The 'decision first' shape: what it is, my take, your calls, where to look."""
    iid = e["iid"]
    headline = e.get("headline") or e.get("title") or "(no title)"
    out = [f"**!{iid} — {headline}**"]

    # my take, one line
    take = e.get("take") or e.get("recommendation")
    if take:
        out += wrap(take, "", "")
    elif not e.get("decisions") and not e.get("question"):
        # in the queue but no state yet: reviewing it is this pass's job
        out.append("Not reviewed yet.")

    # the calls that are actually his, numbered so each one is its own decision
    decisions = e.get("decisions")
    if not decisions and e.get("question"):
        decisions = [e["question"]]
    if decisions:
        out.append("")
        out.append(f"Your call, {COUNT.get(len(decisions), f'{len(decisions)} things')}:"
                   if len(decisions) > 1 else "Your call:")
        for i, d in enumerate(decisions, 1):
            out += wrap(d, f"{i}. ", "   ")

    # where to look, and the links on one line
    links = []
    for sb in e.get("storybook") or []:
        label = sb.get("label") or "storybook MR"
        links.append(f"[{label}]({sb['mr_url']})")
        if sb.get("main_url"):
            links.append(f"[main]({sb['main_url']})")
    if e.get("web_url"):
        links.append(f"[!{iid}]({e['web_url']})")
    look = e.get("look_at")
    if look or links:
        out.append("")
        if look:
            out += wrap(f"Look at {look}:", "", "")
        if links:
            out.append(" · ".join(links))
        # the story id is derived, never verified (Storybook sits behind SSO),
        # so a sidebar path keeps a wrong id from costing him a dead end
        if e.get("storybook_path"):
            out += wrap(e["storybook_path"], "sidebar: ", "         ")
    return out


def entry_lines(e, section, mode):
    if section == "needs_human":
        return needs_human_lines(e)
    out = [f"- !{e['iid']}: {e.get('title') or '(no title)'}"]
    pad = "  "
    if section == "pending_ok":
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
        entries = [
            entry_lines(e, key, args.mode)
            for e in sorted(items, key=lambda x: -int(x["iid"]))
        ]
        if key == "needs_human":
            # each entry is a multi-paragraph block; blank lines keep them apart
            for i, block in enumerate(entries):
                if i:
                    lines.append("")
                lines += block
        else:
            for block in entries:
                lines += block
        blocks.append("\n".join(lines))

    print("\n\n".join(blocks) if blocks
          else "Queue clear. Nothing waiting on you and nothing in flight.")


if __name__ == "__main__":
    main()
