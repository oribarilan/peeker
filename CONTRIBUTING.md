# Contributing to Peeker

Thanks for helping. Bug reports, fixes, new plugins and improvements to existing ones are all welcome. For anything bigger than a fix, open an issue first so we can agree on what it should do before you build it: what a plugin shows, what the UI says and what gets saved are product calls the maintainer makes.

AI coding agents should read [AGENTS.md](AGENTS.md), which has the same rules in more detail.

## This repository is public

Commits, branches, pull requests, issue comments and CI logs are all public, and anything committed stays in history. Before you push:

- No secrets: API keys, tokens, signing certificates or passwords, anywhere.
- No personal data: no home-folder paths (`/Users/<name>/…`), machine names, emails or contents of your own files. Use paths relative to the repo and generated test files.
- No material you can't share, and no code or dependency under a license that isn't compatible with MIT.
- Write for strangers: commit messages, comments and docs should make sense to someone with none of your context.

## Set up

You need macOS 26 or later, Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh          # Release build into build/dd; the log is build/build.log
scripts/build.sh test     # all unit tests, plus the check on what plugins import
open build/dd/Build/Products/Release/Peeker.app
```

The Xcode project is generated from `project.yml`. Edit `project.yml`, never `Peeker.xcodeproj`, which stays out of git.

## How the code fits together

The app is a host, and every format is a plugin. The host owns windows, tabs, routing, menus, the Peek panel, save prompts and crash recovery, and knows nothing about formats. Each plugin is a Swift module in `Plugins/<id>/` that opens, shows and saves its own files through the contract in `Sources/PeekerKit/Plugin.swift`. A plugin may import only `PeekerKit` and Apple frameworks (plus its declared packages), never another plugin; code two plugins need goes into `PeekerKit`. The README's [Plugins](README.md#plugins) section and the code layout in [AGENTS.md](AGENTS.md#code-layout) say more.

A few rules hold everywhere:

- Reading, decoding and saving happen off the main thread.
- Anything read from a file is untrusted: the config, recovery records and the files users open. Never weaken the safe-write path in `Sources/PeekerKit/FileReplacement.swift`.
- Opening has to beat Preview and TextEdit, so measure before adding work to the open path.
- Keep it simple: reuse what's here, then the standard library and Apple frameworks, before adding a dependency.

## Making a change

Planning runs through [OpenSpec](https://github.com/Fission-AI/OpenSpec). `openspec/specs/` describes what the app does today, and a new feature starts as a change in `openspec/changes/` with a proposal, spec deltas, a design and a task list. A small fix doesn't need one. If your work changes what a spec says, update the spec, and run `openspec validate --all` before you open the pull request.

### Tests

Write tests with Swift Testing, next to the existing suites in `Tests/`. For a bug, add a test that fails first, then fix it. Files named `PDF*.swift` run in their own test bundle, `PDFTests`. The build is warning-free; fix any warning you add.

### Screen tests

`scripts/screen-test.sh` drives the real app through Finder, menus, Settings and each plugin's edits, checking every step. It takes over the mouse and keyboard for about four minutes, and needs Accessibility and Screen Recording for your terminal. Run it after changing the host UI or a plugin's views. A change users can see should add or update a step in `scripts/screen/`, or say in the pull request why it doesn't.

### Benchmarks

`scripts/bench-ab.sh main` compares your branch with `main` on your Mac and fails on a clear slowdown. CI runs it on every pull request, so you only need it locally when you change the open path or the Peek panel.

### Changelog

A change users can see adds a line under Unreleased in `CHANGELOG.md`, written for the people who use Peeker. Those lines become the release notes on GitHub, in the update window and in the "Updated to Peeker" window.

### Version

Peeker has one version number to maintain: `MARKETING_VERSION` in `project.yml`. It's the version shown in About Peeker, Settings and the update window. Between releases it holds the next planned version with `-dev` added, such as `0.10.0-dev`, and a `-dev` build never checks for updates.

Bump it in a commit of its own after your change. A change that adds something users see bumps the minor version (`0.9.0-dev` becomes `0.10.0-dev`). A change that only fixes things bumps the patch (`0.10.0-dev` becomes `0.10.1-dev`).

macOS also needs a build number (`CFBundleVersion`), which the updater compares to tell which version is newer. Nobody edits it. Development builds use 0, and a release computes it from its tag as major × 10000 + minor × 100 + patch, so `v0.10.0` gets 1000. That's why minor and patch stay under 100.

## Commits and pull requests

- Branch from `main` and open a pull request. CI must pass.
- One logical change per commit. Write the subject as an imperative sentence ("Show every page of a multi-page TIFF") and use the body to say why.
- Keep generated files out: `build/`, `Peeker.xcodeproj/`, `bench/fixtures/` and `bench/results/raw/`.

## Releases

The maintainer tags releases. A version tag builds, signs, notarizes and publishes Peeker, then updates the update feed and the Homebrew cask. [docs/releasing.md](docs/releasing.md) has the setup and the steps.

## License

Peeker is under the [MIT license](LICENSE). By contributing, you agree that your contributions are licensed under it too.
