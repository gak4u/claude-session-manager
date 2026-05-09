# Agent instructions

Quick orientation for an AI coding agent (or a human contributor) dropped
into this repo. Read [README.md](README.md) for end-user details; this file
focuses on **how to build, run, and modify** the project.

## Repo layout

```
.
├── csm                # single-file Python CLI; also hosts the web server
├── index.html         # single-page dashboard served by `csm server`
├── install.sh         # symlinks ./csm into ~/.local/bin
├── mac/               # SwiftUI app (SPM, no .xcodeproj)
│   ├── Package.swift
│   ├── Sources/CSMMac/*.swift
│   ├── Resources/Info.plist
│   └── build-app.sh   # `swift build` + bundles into CSM.app
├── README.md
├── LICENSE
└── AGENTS.md          # this file
```

All three frontends share `~/.csm/sessions.json`. Atomic writes via
`.tmp` → `replace`.

## Run the CLI / web dashboard from source (no build)

The CLI is a single Python file with stdlib-only imports — no `pip install`,
no compile step.

```sh
chmod +x csm install.sh
./install.sh                       # symlinks ./csm into ~/.local/bin
csm --help                         # confirm it's on PATH
csm save my-session                # bookmark the current Claude session
csm server                         # localhost web UI on :7337
```

Requires **Python 3.10+** (uses `str | None` and `list[…]` PEP-585/604
annotations evaluated at runtime).

To run without installing: `./csm <subcommand>` works the same way from
within the repo.

## Run the native app — pre-built (no build)

```sh
gh release download v0.1.0 -p 'CSM.app.zip'   # or download from the Releases page
unzip CSM.app.zip
xattr -dr com.apple.quarantine CSM.app        # only if Gatekeeper blocks
open CSM.app
```

The app is ad-hoc signed; first launch may need a one-time right-click →
Open → Open.

## Build the native app from source

Requires **Xcode 16+** (Swift 6.0 toolchain) and **macOS 14+** as
deployment target.

```sh
cd mac
./build-app.sh release             # produces ./CSM.app, ad-hoc signed
open CSM.app
```

For fast iteration without bundling:

```sh
cd mac
swift build                        # checks compile only; no bundle
swift run                          # boots the executable, but menu-bar &
                                   # iTerm automation prompts behave better
                                   # when launched as a real .app bundle
```

To open in Xcode: `open mac/Package.swift`. SPM-based packages open as a
project with no `.xcodeproj` clutter to maintain.

## Tests / smoke checks

There's no formal test suite. Manual smoke for a refactor:

```sh
# CLI happy path (in a Claude-active project dir)
./csm save smoke && ./csm list && ./csm rename smoke smoke2 && ./csm delete smoke2 -y

# Web server happy path
./csm server &
SERVER_PID=$!
until curl -fsS http://127.0.0.1:7337/api/sessions >/dev/null; do sleep 0.2; done
curl -fsS http://127.0.0.1:7337/api/active
curl -X POST http://127.0.0.1:7337/api/sessions/save \
  -H 'Content-Type: application/json' \
  -d '{"name":"smoke","path":"'$PWD'"}'
kill $SERVER_PID

# Native app
cd mac && swift build              # must compile cleanly
./build-app.sh release             # must produce a launchable .app
```

For `resume` testing without spawning a real Claude session, put a fake
`superclaude` and a fake `osascript` (Python server only) ahead on PATH and
have them log args.

## Releasing

```sh
cd mac && ./build-app.sh release
ditto -c -k --keepParent CSM.app CSM.app.zip
shasum -a 256 CSM.app.zip                # for the release notes
gh release create vX.Y.Z mac/CSM.app.zip --title "..." --notes "..."
```

Bump `CFBundleShortVersionString` in `mac/Resources/Info.plist` first.

## Things to watch when modifying

- The path-flattening (`/Users/x/y` → `-Users-x-y`) is shared with Claude
  Code itself. Don't try to make it lossless — it isn't, by design.
- `current_session_id()` picks the **most recently modified** `.jsonl`. If
  you change that heuristic, also update `discover_active()` and the
  README "Caveats" section.
- The Swift app and Python both write `~/.csm/sessions.json` — atomic
  writes are the only synchronization. Don't introduce a long-held lock.
- The web server's `Host` header check rejects DNS-rebinding attempts; if
  you add features that need access from non-localhost hosts, the check
  needs to evolve, not just be removed.
- `superclaude` is preferred over `claude --dangerously-skip-permissions`,
  but the fallback must keep working — detect `superclaude` via
  `command -v` inside the spawned shell, not in the parent process, so the
  user's interactive `PATH` is honored.

## Storage schema

```json
{
  "sessions": {
    "<name>": {
      "session_id": "<uuid>",
      "project_path": "<absolute path>",
      "saved_at": "<ISO 8601 with offset>"
    }
  }
}
```

Treat it as a forward-compatible target: keep unknown keys when reading,
write only the schema above. Hand-edits are supported and expected.
