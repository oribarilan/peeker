# AGENTS.md

Peeker is an open-source replacement for Preview.app on macOS 26+, written in Swift and AppKit. The app is a host; each format (text, Markdown, PDF, images) is a built-in plugin the user can turn off or give other file extensions.

## This repository is public

Everything that leaves your machine is public at <https://github.com/oribarilan/peeker>: commits and their messages, every pushed branch, PR descriptions, issue and review comments, CI logs and release notes. Anything committed stays in history even after a later commit deletes it. Before you commit, push or post:

- **No secrets.** No API keys, tokens, signing certificates, passwords or notarization credentials, in code, config, scripts or logs. CI secrets live in GitHub Actions secrets only.
- **No personal data.** No home-folder paths (`/Users/<name>/…`), machine or host names, emails, or contents of the user's own files. Use paths relative to the repo root, and generated or synthetic test files.
- **No private material.** Nothing copied from work projects, private chats, paid sources or other people's unpublished code. Quote public sources briefly and link them.
- **Licenses.** A new dependency or copied snippet must have a license compatible with the project's.
- **Write for strangers.** Commit messages, comments and docs are read by people with none of your context. No session notes, agent chatter or internal shorthand.

Generated files stay out of git: `build/`, `Peeker.xcodeproj/` (XcodeGen output), `bench/fixtures/` and `bench/results/raw/`. Agent scratch folders such as `.superpowers/`, and reference clones of other projects in `.refs/`, stay local.

## Core principles

- **Plan, then code.** Read the code you're changing and the tests that cover it first. Break bigger work into steps.
- **Ask, don't assume.** Product calls (what a plugin does, what the UI says, what gets saved) belong to the maintainer. Ask when unsure.
- **Keep it simple.** Write the least code that works: reuse what's here, then the standard library and Apple frameworks, then an existing dependency. If you pick a more complex path, say why.
- **Don't repeat yourself, but don't abstract early.** Wait for the third copy before extracting.
- **One job per file.** Most files are under 300 lines; split a file that grows past about 500.
- **Security.** Validate everything that comes from a file: config, recovery records, the files users open. Never weaken the safe-write path in `Sources/PeekerKit/FileReplacement.swift`.

## Architecture rules

- **Plugins are modules.** Each plugin is a Swift module in `Plugins/<id>/`, built into the app. It owns its views and reads and writes its own files. It may import only `PeekerKit`, Apple frameworks and its declared packages, and `scripts/build.sh test` checks that. Code two plugins need goes into `PeekerKit`, never from one plugin into another.
- **The host knows no formats.** Windows, tabs, routing, on/off toggles, the Space panel, menus, save prompts and crash recovery live in the host. Anything specific to a format lives in its plugin. The contract is `Sources/PeekerKit/Plugin.swift`.
- **Slow work stays off the main thread.** Plugins read, decode and save off the main thread, and the host cancels an open when its tab closes. A crash in plugin code quits the app, so unsaved edits must always be in the recovery copy.
- **The plugin that owns a format writes it.** Saving hands the plugin its own unsaved edits, and it writes the file through `FileReplacement`, keeping the encoding, line endings and permissions.
- **Speed is a feature.** Opening must beat Preview and TextEdit head to head. The Space panel must be at least as fast as Finder's Quick Look on every file, so measure before adding work to the open path.

## Code layout

```
Sources/Host/        the app: App/, Plugins/ (catalog and routing), Documents/ (save, recovery, file watching),
                     Components/ (sidebar and containers), QuickLook/ (Space panel), Bench/
Sources/PeekerKit/   what plugins may use: the plugin contract, safe file writes, the info sidebar panel
Plugins/<id>/        one plugin each: <Id>Plugin.swift (entry point and default extensions) and its document views
Tests/               Swift Testing suites
bench/, scripts/     benchmark and build scripts
decisions/           decision records
openspec/            specs of current behavior, changes in progress, roadmap (config.yaml), known gaps
```

## Specs and planning

Planning runs through [OpenSpec](https://github.com/Fission-AI/OpenSpec). `openspec/specs/` describes what the app does today, one folder per capability; `openspec/config.yaml` holds the product direction and the roadmap; `openspec/gaps.md` lists what the specs found missing. New work starts as a change: interview the maintainer first (the `grill-me` skill), then `/opsx:propose` writes the proposal, delta specs, design and tasks, `/opsx:apply` implements them, and `/opsx:archive` folds the deltas into the specs. While applying, use the superpowers skills for test-first work, debugging and verification, but not their brainstorming, spec or plan documents. Run `openspec validate --all` before handing work back.

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
