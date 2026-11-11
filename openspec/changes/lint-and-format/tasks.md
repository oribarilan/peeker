# Tasks

## 1. Formatter

- [x] 1.1 `.swift-format` matched to the house style; `scripts/format.sh`; one reformat commit whose diff is whitespace, line breaks and trailing commas only (checked by comparing the code with whitespace removed), with the build and all unit tests passing; the commit listed in `.git-blame-ignore-revs`.

## 2. Checks

- [x] 2.1 `scripts/lint.sh`: swift-format lint in strict mode, the 500-line limit with `scripts/long-files.txt`, the prose and privacy check, ShellCheck on bash scripts, plugin imports; reports all problems before failing. Verify: it passes on the repo, and fails when a capped file grows by a line.
- [x] 2.2 `.shellcheckrc` and fixes for every ShellCheck finding in the bash scripts; `bash -n` passes on each.
- [x] 2.3 `scripts/build.sh test` runs the lint first; on CI it passes `PEEKER_WARNINGS_AS_ERRORS=YES`, which `project.yml` maps to `SWIFT_TREAT_WARNINGS_AS_ERRORS` for Peeker's targets only. Verify: `CI=1 scripts/build.sh test` passes with the flag on all ten Peeker modules and none of the packages.
- [x] 2.4 `tests.yml` and `bench.yml` install ShellCheck and OpenSpec and run `openspec validate --all`.

## 3. Docs

- [x] 3.1 AGENTS.md: a Style and checks section, the format script under Build and test, the file-length rule pointing at the check; `openspec validate --all` passes.

## Workflow follow-up

- Commit, bump `MARKETING_VERSION` to the next patch `-dev`, archive.
