# Code formatting and linting

Which formatter or linter Peeker could run automatically, and how. Researched on 2026-10-31; nothing is set up yet.

## Recommendation

Run [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) in lint-only mode in a small GitHub Actions job, with its wrapping rules turned off so the current dense style stays. Skip SwiftLint for now: the build is warning-free, the compiler catches most of what it would, and `scripts/check-plugin-imports.sh` already enforces the import rule. Apple's swift-format needs no install, but it fights the existing style (see the measurements below).

## The options

| | swift-format (Apple) | SwiftFormat | SwiftLint |
|---|---|---|---|
| Does | Formats and lints | Formats, with a `--lint` check mode | Lints, with `--fix` for some rules |
| Version checked | 604.0.0, 2026-09-16 | 0.64.5, 2026-10-31 | 0.65.1, 2026-08-21 |
| License | Apache 2.0 | MIT | MIT |
| Install | Ships with Xcode (`xcrun swift-format`) | `brew install swiftformat`; already on GitHub's `macos-26` runner (0.64.3) | `brew install swiftlint`; not on the runner |
| Fits the current style | Poorly: an opinionated pretty-printer with few settings | Well: wrapping and spacing are separate rules that can be turned off | Doesn't apply: it checks rules, not layout |

Running any of them as an Xcode build phase is possible through `project.yml`, but a formatter that rewrites files on every build is a poor trade, and SwiftLint's phase needs `ENABLE_USER_SCRIPT_SANDBOXING = NO`. A check in CI is simpler and is the one gate every contributor passes; git hooks aren't shared by a clone.

## How much swift-format would change

Run in lint mode over the 123 Swift files (about 14,000 lines; 632 lines are over 120 characters and 53 over 160), with 4-space indents and existing line breaks respected:

| Line length | Findings | Files | Main rules |
|---|---|---|---|
| 120 | 1,270 | 102 | LineLength 596, Indentation 242, AddLines 145, DoNotUseSemicolons 96, OneVariableDeclarationPerLine 57 |
| 180 | 702 | 78 | Indentation 240, AddLines 200, DoNotUseSemicolons 96, OneVariableDeclarationPerLine 57, OrderedImports 27 |

Turning off the semicolon, one-variable-per-line and one-case-per-line rules still leaves 542 findings at 180 characters. Most of them reject choices the code makes on purpose, such as one-line bodies (`if id == "mark" { marks += 1; onEdit?() }`) and aligned continuation lines. SwiftFormat's churn hasn't been measured yet, since it wasn't installed when this was written.

## Starting SwiftFormat config

Not yet run against the code, so check each option against the installed version before committing it as `.swiftformat`:

```
--swiftversion 6.0
--language-mode 6
--indent 4
--maxwidth none
--wraparguments preserve
--wrapparameters preserve
--wrapcollections preserve
--semicolons inline
--exclude build,.refs,.superpowers,Peeker.xcodeproj,bench/fixtures
# keep one-line `guard ... else { return }` and `if x { a; b }` bodies
--disable wrapConditionalBodies,wrapLoopBodies,wrapSwitchCases,wrapMultilineStatementBraces
```

When a rule disagrees with the existing style, turn it off rather than reformat the code. `swiftformat --infer-options` can suggest values from the code as it is.

## Running it

Locally: `swiftformat --lint .` reports without changing anything (`--lenient` keeps the exit code at zero).

In CI, a separate `.github/workflows/lint.yml` on pull requests, one job on `macos-26`, no XcodeGen or build needed:

```yaml
- uses: actions/checkout@v7
- run: swiftformat --lint . --reporter github-actions-log
```

SwiftFormat changes rule behavior between patch releases, and the runner's copy lags Homebrew's, so the job should check `swiftformat --version` against the version the config was tuned with and fail loudly when they differ.

## Rollout

1. Install SwiftFormat locally, lint with the config above, and count the findings.
2. Tune the config until the findings are near zero, or only in places that are inconsistent anyway.
3. Fix the rest in one formatting commit.
4. Add the CI job in a later commit, so it starts green.
5. Only then consider SwiftLint, with a short opt-in rule list.

## Not verified

- SwiftFormat's and SwiftLint's churn on this code.
- Which swift-format version Xcode 26.6 on the CI runner carries; a swift-format check would need a pinned binary.
- Swift 6.2 syntax support in each tool. SwiftFormat's recent changelog covers new syntax such as `unsafe`, which suggests it keeps up.
- Whether SwiftFormat could run on a cheaper Linux runner.

## Sources

- swift-format: [releases](https://github.com/swiftlang/swift-format/releases), [configuration](https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md)
- SwiftFormat: [README and rules](https://github.com/nicklockwood/SwiftFormat), [releases](https://github.com/nicklockwood/SwiftFormat/releases)
- SwiftLint: [README](https://github.com/realm/SwiftLint), [releases](https://github.com/realm/SwiftLint/releases)
- [GitHub's macOS 26 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md): Xcode 26.6 by default, SwiftFormat 0.64.3, no SwiftLint or XcodeGen
