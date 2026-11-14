# Tasks

## 1. The panel

- [x] 1.1 Update `Tests/PeekPanelTests.swift`: the title bar holds no `NSButton` beside Open in Peeker; Show in Finder's menu item shows its key, and none when the key is off; only the main button gets a caption; the long name ends before Open in Peeker. See them fail.
- [x] 1.2 Remove the folder button from `PeekPanel.swift` and its caption from `OpenWith.swift`; lay the name out up to Open in Peeker; give the menu item the key. Verify the tests pass.

## 2. Screen flow

- [x] 2.1 In `scripts/screen/record-flows.sh`, drop the folder button's step (Cmd+R's step covers the reveal) and measure the long name against Open in Peeker; update the `run-peeker` skill.
- [x] 2.2 Run `scripts/screen-test.sh flows` with the maintainer's go (queue it in `.local/screen-queue.md` otherwise).

## 3. Wrap-up

- [x] 3.1 Update the CHANGELOG lines that named the folder button; `scripts/build.sh test` passes with no warnings; `openspec validate --all` passes.
