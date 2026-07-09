---
name: vscode
description: Open the current working directory in VS Code via the `code` CLI. Use when the user runs `/vscode` or asks to open the current folder/project in VS Code.
metadata:
  version: "1.0.0"
---

# code — Open cwd in VS Code

Run the `code` CLI against the current working directory:

```bash
code .
```

Notes:
- If arguments are passed to the skill, treat them as a path and run `code <path>` instead of `code .`.
- If `code` is not found on the PATH, tell the user to install the CLI via VS Code's Command Palette → "Shell Command: Install 'code' command in PATH".
- Report success tersely; there is nothing more to do once VS Code opens.
