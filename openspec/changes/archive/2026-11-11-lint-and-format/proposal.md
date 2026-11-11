# Proposal

## Why

The repo's style and its public-repo rules lived only in AGENTS.md: nothing formatted Swift, no linter ran, a file could grow past the 500-line guideline, an em dash or a home-folder path could slip into a commit, and CI didn't fail on compiler warnings or invalid specs. Agents write most of the code, so rules a machine checks hold better than rules it has to remember.

## What Changes

- swift-format (it ships with Xcode) formats and lints every Swift file as `.swift-format` sets it: 4-space indents, 150-character lines, existing line breaks kept, and the rules that would fight the house style (several declarations per line, semicolons in one-line guards) off. One commit reformats the codebase, listed in `.git-blame-ignore-revs`.
- `scripts/format.sh` formats; `scripts/lint.sh` checks swift-format's formatting and lint rules, a 500-line limit on Swift files (older long files capped at their size in `scripts/long-files.txt`), em dashes, section signs and home-folder paths in tracked files, ShellCheck on the bash scripts (`.shellcheckrc`), and plugin imports.
- `scripts/build.sh test` runs `scripts/lint.sh` first, and on CI builds Peeker's targets with warnings as errors (`PEEKER_WARNINGS_AS_ERRORS`, so the packages keep their own settings).
- CI (`tests.yml` and `bench.yml`) installs ShellCheck and OpenSpec and runs `openspec validate --all`.
- The bash scripts' ShellCheck findings are fixed; AGENTS.md gets a Style and checks section.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Tooling only; the app's behavior doesn't change.

## Impact

Every Swift file's layout (whitespace, line breaks and trailing commas only; the build and all unit tests pass unchanged). `scripts/`, `.github/workflows/`, `project.yml` (one build setting), `AGENTS.md`. New tool for contributors: ShellCheck (`brew install shellcheck`).
