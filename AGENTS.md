# AGENTS.md

Peeker is an open-source replacement for Preview.app on macOS 26+, written in Swift and AppKit. The app is a host; each format (text, Markdown, PDF, images) is a built-in plugin the user can turn off or route file types to.

## This repository is public

Everything that leaves your machine is public at <https://github.com/oribarilan/peeker>: commits and their messages, every pushed branch, PR descriptions, issue and review comments, CI logs and release notes. Anything committed stays in history even after a later commit deletes it. Before you commit, push or post:

- **No secrets.** No API keys, tokens, signing certificates, passwords or notarization credentials, in code, config, scripts or logs. CI secrets live in GitHub Actions secrets only.
- **No personal data.** No home-folder paths (`/Users/<name>/…`), machine or host names, emails, or contents of the user's own files. Use paths relative to the repo root, and generated or synthetic test files.
- **No private material.** Nothing copied from work projects, private chats, paid sources or other people's unpublished code. Quote public sources briefly and link them.
- **Licenses.** A new dependency or copied snippet must have a license compatible with the project's.
- **Write for strangers.** Commit messages, comments and docs are read by people with none of your context. No session notes, agent chatter or internal shorthand.

Generated files stay out of git: `build/`, `Peeker.xcodeproj/` (XcodeGen output), `bench/fixtures/` and `bench/results/raw/`. Agent scratch folders such as `.superpowers/` stay local.

## Core principles

- **Plan, then code.** Read the code you're changing and the tests that cover it first. Break bigger work into steps.
- **Ask, don't assume.** Product calls (what a plugin does, what the UI says, what gets saved) belong to the maintainer. Ask when unsure.
- **Keep it simple.** Write the least code that works: reuse what's here, then the standard library and Apple frameworks, then an existing dependency. If you pick a more complex path, say why.
- **Don't repeat yourself, but don't abstract early.** Wait for the third copy before extracting.
- **One job per file.** Most files are under 300 lines; split a file that grows past about 500.
- **Security.** Validate everything that crosses a process or file boundary: plugin replies, shared memory files, config, the files users open. Never weaken the safe-write path in `Sources/PluginSDK/FileReplacement.swift`.

## Architecture rules

- **Plugins never draw.** A plugin runs as its own process (`Contents/Helpers/<id>-plugin`) and answers with a description of what to show; the host renders it with native views. A plugin crash or hang must never take the app down or lose unsaved edits.
- **The protocol is typed.** Messages are defined in `Sources/Shared/Protocol.swift`, and the comment at its top documents them. No `[String: Any]` in protocol or plugin code.
- **The plugin that owns a format writes it.** Saving sends the edited content to the plugin, which keeps the file's encoding, line endings and permissions.
- **Speed is a feature.** Opening must beat Preview and TextEdit head to head. The Space panel targets under 20 ms warm, and the margin is thin, so measure before adding work to the open path.

## Code layout

```
Sources/Host/        the app: App/, Plugins/ (catalog, process), Documents/ (save, recovery, file watching),
                     Components/ (native views per content type), QuickLook/ (Space panel), Bench/
Sources/Shared/      protocol types shared by host and plugins
Sources/PluginSDK/   plugin main loop and safe file replacement
Plugins/<id>/        one plugin each: <Id>Plugin.swift, main.swift, manifest.json (supported file types)
Tests/               Swift Testing suites; Tests/TestPlugin misbehaves on purpose (crash, hang, garbage)
bench/, scripts/     benchmark and build scripts
decisions/, docs/    decision records, design specs and plans
```

## Build and test

Needs Xcode 26+ and XcodeGen (`brew install xcodegen`). The project file is generated from `project.yml`; edit that, never the `.xcodeproj`.

```sh
scripts/build.sh          # Release build into build/dd; log in build/build.log
scripts/build.sh test     # all unit tests
open build/dd/Build/Products/Release/Peeker.app
```

Fix new warnings before you finish; the build is currently warning-free. Write tests with Swift Testing, next to the existing suites in `Tests/`. For bugs, add a failing test first.

## Benchmarks

`scripts/bench-ab.sh <base-ref>` compares your branch with a base on the same machine and fails on clear regressions (worse by more than 15% and 10 ms). CI runs it on every pull request (`.github/workflows/bench.yml`). A full run takes several minutes, so run it once per change, not after every edit. Published README numbers come only from a reference Mac through the `publishing-benchmarks` skill, never from CI.

## Git

- Branch from `main`, then open a pull request; CI must pass. Don't push to `main` directly and never force-push it.
- One logical change per commit. The subject is an imperative sentence; the body says why.
- Agents commit, push, open or merge PRs, tag or release only when the maintainer asks for that specific action.
