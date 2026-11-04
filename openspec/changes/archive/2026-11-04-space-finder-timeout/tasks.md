# Tasks

## 1. A bounded selection read

- [x] 1.1 Write failing tests for `FinderBridge`: a reply list of file aliases becomes file URLs in order; an empty or missing reply becomes an empty selection; a bridge aimed at a bundle id that isn't running returns an empty selection well under its timeout.
- [x] 1.2 Replace the `NSAppleScript` in `FinderBridge` with a get-data Apple Event for Finder's `selection` as an alias list, sent with `sendEvent(options: .waitForReply, timeout:)` (default 0.5 s, injectable along with the target bundle id); verify the 1.1 tests pass and `scripts/build.sh test` passes with no new warnings.
- [x] 1.3 Remove the "Space waits on Finder" risk from `openspec/gaps.md`, add a CHANGELOG line under Unreleased, and verify `openspec validate --all` passes.

## 2. In the real app

- [x] 2.1 After the maintainer's go: Space and the arrow keys still show Finder's selection in the Peek panel (the `flows` screen test), and with Finder made busy Space falls through to Quick Look within about half a second.

## Workflow follow-up

- Commit when the maintainer asks, then bump the patch version in its own commit.
- Archive with `/opsx:archive`.
