# CSM — Claude Session Manager

A small macOS toolkit for naming, browsing, and resuming Claude Code sessions.
Three interfaces share one storage file: a Python CLI, a localhost web
dashboard, and a native SwiftUI app with a menu-bar item.

## Why

Claude Code identifies every session with a UUID stored under
`~/.claude/projects/<flattened-cwd>/<uuid>.jsonl`. After a Mac restart (or just
a tab close) you've lost track of which UUID belonged to which project. CSM
lets you bookmark sessions by a human-readable name and resume them with one
command (or one click).

## What's in here

| Surface       | Entry point             | What it's for                                       |
|---------------|-------------------------|-----------------------------------------------------|
| CLI           | `csm <subcommand>`      | Terminal-native save/resume from the project's tab |
| Web dashboard | `csm server` → :7337    | Browser dashboard with active-session discovery    |
| Native app    | `mac/CSM.app`           | SwiftUI window + menu-bar quick-pick               |

All three read/write the same `~/.csm/sessions.json`.

## Install

CLI:

```sh
./install.sh                 # symlinks ./csm into ~/.local/bin
./install.sh /usr/local/bin  # or pick another target dir
```

Requires Python 3 (stdlib only). For the resume command, CSM uses
`superclaude` if it's on `PATH`; otherwise it falls back to
`claude --dangerously-skip-permissions`. So you need at least one of those
installed.

Native app:

```sh
cd mac
./build-app.sh               # builds ./CSM.app via swift build + bundle
open CSM.app
```

Requires Xcode 15+ (Swift 6, macOS 14 deployment target). The first time you
hit Resume, macOS will prompt for permission to control iTerm2 — that's the
`NSAppleEventsUsageDescription` in `Info.plist`.

## CLI

### `csm save <name>`

Detects the most-recently-modified session under
`~/.claude/projects/<flattened-cwd>/` and stores it.

```sh
$ cd ~/projects/claude-session-manager
$ csm save csm-dev
saved 'csm-dev' -> c53cae35... in /Users/you/projects/claude-session-manager
```

`--force` overwrites an existing entry.

### `csm list`

```sh
$ csm list
NAME       PROJECT                            SESSION     SAVED
csm-dev    ~/Personal/claude-session-manager  c53cae35    2m ago
xpat-api   ~/Work/xpat                        9f1d2a04    3h ago
```

### `csm resume <name>`

`cd`s into the saved project path, renames the **current** iTerm2 tab to
`<name>`, then `exec`s `superclaude --resume <session-id>` so the shell is
replaced by the resumed Claude session.

### `csm rename <old> <new>` / `csm delete <name>`

```sh
$ csm rename csm-dev csm
$ csm delete csm -y
```

### `csm server [--host 127.0.0.1] [--port 7337]`

Starts the web dashboard. Bound to localhost, requires
`Content-Type: application/json` on writes, validates the `Host` header
(rejects DNS-rebinding attempts).

## Web dashboard

`csm server` then open <http://127.0.0.1:7337>. Dark theme, vanilla JS, no
frameworks, single `index.html`.

- **Save form** at the top: name + path → POST `/api/sessions/save`
- **Active now** section: shows unsaved sessions whose `.jsonl` has been
  touched in the last 8 hours, with a "Save as…" button per card
- **Saved** section: cards with Resume / Rename / Delete buttons
- Auto-refreshes every 5s

Resume from the web UI behaves differently from the CLI: instead of replacing
the current shell, it uses AppleScript to **open a new iTerm2 tab**, set its
title to the session name, and run `cd <path> && superclaude --resume <id>`.

### API

| Method | Path                                | Body                | Behavior                                  |
|--------|-------------------------------------|---------------------|-------------------------------------------|
| GET    | `/api/sessions`                     | —                   | All saved entries                         |
| GET    | `/api/active`                       | —                   | Live sessions touched in the last 8h      |
| POST   | `/api/sessions/save`                | `{name, path}`      | Detects current session id, stores it     |
| POST   | `/api/sessions/resume`              | `{name}`            | Spawns iTerm tab via osascript            |
| PATCH  | `/api/sessions/<name>/rename`       | `{new_name}`        | Renames an entry                          |
| DELETE | `/api/sessions/<name>`              | —                   | Removes an entry                          |

## Native app (mac/CSM.app)

Native SwiftUI on macOS 14+. Same operations as the web UI, plus:

- **Browse… button** instead of a path text field — uses `NSOpenPanel` to pick
  a folder; auto-fills the name field with the folder's basename if empty
- **Menu-bar icon** (stacked-rectangles symbol) with a dynamic menu of saved
  sessions — click any item to resume in a new iTerm tab
- **Active (unsaved)** section in the menu listing live sessions you haven't
  named yet
- Closing the dashboard window leaves the menu-bar item running; quit via the
  menu's "Quit CSM"

Build/iterate:

```sh
cd mac
swift build              # fast iteration
./build-app.sh           # rebuild CSM.app
open Package.swift       # opens the project in Xcode if you prefer
```

## How `resume` actually works

CSM shells out to whichever Claude launcher you have. In order of preference:

1. **`superclaude`** — a Claude Code wrapper that bypasses permission prompts
   (useful for fully-trusted local sessions). Used if found on `PATH`.
2. **`claude --dangerously-skip-permissions`** — official Claude Code with
   permission prompts disabled. Used as a fallback if `superclaude` isn't
   installed.

In all cases the binary is invoked with `--resume <session-id>` so it picks
up exactly where the saved session left off.

Two launch paths, depending on context:

- **CLI**: `os.execvp(...)` — replaces the current shell, so the session
  resumes in the tab you typed `csm resume` in. The current tab is renamed
  via AppleScript first.
- **Web / native app**: AppleScript creates a **new** iTerm2 tab, names it,
  and writes a small `if command -v superclaude … else claude …` block so the
  detection happens inside the new tab's shell (which may have a different
  `PATH` than the GUI app's).

## Storage

Single JSON file at `~/.csm/sessions.json`, atomic writes via `.tmp` +
`replace`:

```json
{
  "sessions": {
    "csm-dev": {
      "session_id": "c53cae35-5828-428d-9507-c2d70e664b69",
      "project_path": "/Users/you/projects/claude-session-manager",
      "saved_at": "2026-05-08T12:38:00-07:00"
    }
  }
}
```

Hand-edit it if you want; the CLI, server, and Mac app all reload it.

## License

Source-available under a custom Personal Use License — see [LICENSE](LICENSE)
for the full text. Short version:

- **Free for personal, non-commercial use.** Use, modify, fork, share with
  friends, run it on your own machine.
- **Commercial use requires a separate license.** If you want to use CSM at a
  for-profit company, ship it as part of a paid product, or otherwise use it
  to generate revenue, please [open an issue on
  GitHub](https://github.com/gak4u/claude-session-manager/issues) to start a
  commercial-licensing conversation.
- The software is provided as-is, with no warranty.

This is intentionally not OSI-approved "open source" in the strict sense
(which requires unrestricted commercial use). It's source-available with a
clear personal-use grant.

## Caveats

- **Session detection is mtime-based.** `csm save` picks the most recently
  active `.jsonl` in the project's `~/.claude/projects/<flat>/` directory. If
  you have multiple Claude sessions open in the same project, run `csm save`
  immediately after the session you want to bookmark.
- **Path flattening is lossy.** `/` becomes `-`, so a real `-` in a directory
  name is indistinguishable from a path separator. This matches Claude Code's
  own behavior, so we inherit the same limitation.
- **Resume requires the project dir to still exist** at the saved path. Move
  the project, the entry goes stale; just re-save it.
- **Active discovery window is 8 hours** by default — sessions whose
  `.jsonl` mtime is older than that won't appear in the "Active now" list,
  even if their iTerm tab is still open.
