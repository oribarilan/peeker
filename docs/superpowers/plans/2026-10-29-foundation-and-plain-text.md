# Foundation and Plain Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Preview++ POC into a daily-usable codebase: a typed plugin protocol, robust plugin processes, a plain text plugin with view, edit and save, PDF saving through the plugin, and crash recovery of unsaved edits.

**Architecture:** The host (AppKit app) renders everything with its own components. Each format is a separate plugin executable in `Contents/Helpers`, spoken to over JSON lines on stdin/stdout, now with typed `Codable` messages shared by both sides. Large payloads (pixels, text) cross through mapped temp files. Edits live in the host until Cmd+S sends them to the plugin, which writes the file.

**Tech Stack:** Swift 6 (main-actor default isolation), AppKit, TextKit 2, PDFKit, CoreGraphics, ImageIO, Swift Testing, XcodeGen, `scripts/build.sh`, `bench/ppbench.py`.

**Spec:** `docs/superpowers/specs/2026-10-29-foundation-and-plain-text-design.md`. Read it before starting any task.

## Global Constraints

- macOS deployment target 26.0, `SWIFT_VERSION` 6.0, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`. No new package dependencies.
- Plugins never draw; the host renders. Plugins own reading and writing their files. One process per plugin, started on demand, stopped after `plugin.idle`.
- Timeouts: 10 s for `open` and `command`, 30 s for `save`. On timeout the process is killed with SIGKILL.
- Text files over 10 MB (10 × 1,048,576 bytes) open read-only.
- Recovery copies live in `~/Library/Application Support/<bundle id>/Recovery/` and are refreshed 2 s after the last edit.
- Performance: `small.txt` content no slower than TextEdit's window; warm Space on `small.txt` under 20 ms; `medium.log` and `large.log` show their first screen no slower than TextEdit's window, with no beachball.
- The CI gate (`scripts/bench-ab.sh`, worse by more than 15% and 10 ms, or 5 MB) must pass against `main`.
- Host logging uses `Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.previewpp", category: …)`. No `FileHandle.standardError.write` in the host. No `try?` that hides a failure a user or the log should see.
- No new compiler warnings (`scripts/build.sh` prints them).
- Git: work on branch `foundation`. The owner's rules gate every commit: each task ends by staging (`git add`). Commit only after the owner explicitly asks, and ask again for each later commit unless they said otherwise.
- User-visible copy, used verbatim (`NAME` is the file name, `PLUGIN` the plugin name):
  - Close/quit: "Save changes to “NAME”?" / "Your changes will be lost if you don't save them." / Save, Don't Save, Cancel
  - Newer on disk: "“NAME” changed on disk since you opened it." / "Saving will replace the newer version." / Save Anyway, Cancel
  - Encoding: plugin's failure message / "Some characters can't be represented in the file's encoding." / Save as UTF-8, Cancel
  - Timeout: "The PLUGIN plugin didn't respond within N seconds and was stopped. The rest of the app is unaffected."
  - Malformed: "The PLUGIN plugin sent a reply the app couldn't read and was stopped. The rest of the app is unaffected."
  - Not writable: "You don't have permission to save “NAME”."
  - Not text: "This doesn't look like a text file."
  - Read-only note: "Read-only: files over 10 MB open for viewing only."
  - Recovery, file gone: "“NAME” no longer exists. Your unsaved text was copied to the clipboard."
  - Recovery, file changed: "“NAME” changed on disk after these edits were made. Saving will replace the newer version."

## Review Focus

1. **A file replaced while open** (vim, git checkout and most editors save by writing a new file and renaming it): the watcher must keep firing after the rename, and the tab reloads. Test in Task 8 (`FileWatcherTests.keepsWatchingAfterAtomicReplace`).
2. **Saving a file the user can't write** (`/etc/hosts`, a 0444 file): the save fails with the not-writable message, the file is untouched, the edits stay. Test in Task 5 (`TextPluginTests.refusesToSaveReadOnlyFile`).
3. **An empty file**: opens as empty UTF-8, editable, saves. Test in Task 5 (`TextCodecTests.emptyFileIsUTF8`).
4. **Saving through a symlink**: writes the target, and the link stays a link. Test in Task 5 (`TextPluginTests.savingThroughSymlinkWritesTarget`).
5. **Mostly-UTF-8 text with a few invalid bytes** (an old log with one Latin-1 name): opens via the legacy-encoding fallback and an unedited save leaves the bytes identical. Test in Task 5 (`TextCodecTests.invalidUTF8FallsBackAndRoundTrips`).

---

## File Map

```
Sources/Shared/            compiled into host, SDK and plugins
  Protocol.swift           Request, Call, Response, Outcome, Reply, View, Panel, CommandSpec, SavePayload, Highlight, PluginFailure, PluginManifest
  MarkdownBlock.swift      MarkdownBlock, ListItem, Span, SpanStyle
  SharedFile.swift         SharedFileRef, SharedFile.create / map, MappedFile
Sources/PluginSDK/PluginMain.swift   PluginHandler, PluginMain.run
Sources/Host/
  App/          main.swift, AppDelegate.swift, MainMenu.swift, Config.swift, LoginItem.swift
  Plugins/      PluginCatalog.swift, PluginProcess.swift
  Documents/    DocumentViewController.swift, DocumentWindowController.swift, Edits.swift, SavePrompts.swift, FileWatcher.swift, RecoveryStore.swift
  Components/   Component.swift, TextComponent.swift, MarkdownComponent.swift, PDFComponent.swift, BitmapComponent.swift, Sidebar.swift
  QuickLook/    QuickLookPanel.swift, HotkeyMonitor.swift, FinderBridge.swift
  Bench/        Bench.swift, BenchRunner.swift
Plugins/<id>/   manifest.json, main.swift (one line: PluginMain.run(...)), <Id>Plugin.swift, helpers
  text/         TextPlugin.swift, TextCodec.swift
Tests/
  TestPlugin/main.swift    misbehaving plugin for process tests
  TestSupport.swift        TestProducts (locates built plugin executables), temp file helpers
  ConfigTests.swift, RoutingTests.swift, ProtocolTests.swift, SharedFileTests.swift, PluginProcessTests.swift,
  TextCodecTests.swift, TextPluginTests.swift, TextSaveIntegrationTests.swift, FileWatcherTests.swift,
  PDFSaveTests.swift, RecoveryStoreTests.swift, MarkdownTreeTests.swift
```

---

### Task 1: Reorganize the host by area

Pure move, no behavior change, so later diffs stay readable.

**Files:**
- Move: every file in `Sources/Host/` into the folders in the File Map. `HotkeyMonitor.swift` splits: `FinderBridge` goes to `QuickLook/FinderBridge.swift`. `Components/Components.swift` splits into `Component.swift`, `PDFComponent.swift`, `BitmapComponent.swift`, `Sidebar.swift` (`SharedBitmapReader` and `HolderViewController` go with `BitmapComponent.swift` and `Component.swift`).
- Create: `App/MainMenu.swift` (the `makeMainMenu` and commands-menu code from `AppDelegate`), `Bench/BenchRunner.swift` (`runBench` and `closeBenchDocument` from `AppDelegate`).
- Split: each `Plugins/<id>/main.swift` into `<Id>Plugin.swift` (the handler class) and `main.swift` (only `PluginMain.run(<Id>Plugin())`).
- Split: `Tests/HostTests.swift` into `ConfigTests.swift`, `RoutingTests.swift`, `MarkdownTreeTests.swift`.
- Modify: `project.yml` (HostTests excludes `Plugins/*/main.swift` and manifests).

**Interfaces:**
- Produces: `MainMenu.make(target: AppDelegate) -> NSMenu`, `MainMenu.rebuildCommands(_ menu: NSMenu, for: DocumentWindowController)`, `BenchRunner(bench: Bench, catalog: PluginCatalog, config: Config, panel: QuickLookPanel).start(url: URL)`.

- [ ] **Step 1:** `git switch -c foundation` (`decisions/naming.md` and the docs stay uncommitted and come along).
- [ ] **Step 2:** Move and split the files as listed, with `git mv` where a file moves whole.
- [ ] **Step 3:** Run `scripts/build.sh test && scripts/build.sh`. Expected: `** TEST SUCCEEDED **`, 13 tests pass, `** BUILD SUCCEEDED **`, no warnings.
- [ ] **Step 4:** Open `bench/fixtures/small.md`, `small.pdf` and `photo.jpg` with `open -a build/dd/Build/Products/Release/PreviewPP.app <file>`. Each shows content.
- [ ] **Step 5:** Stage: `git add -A Sources Plugins Tests project.yml`.

---

### Task 2: Typed protocol and shared files

**Files:**
- Rewrite: `Sources/Shared/Protocol.swift`
- Create: `Sources/Shared/MarkdownBlock.swift`, `Sources/Shared/SharedFile.swift`
- Test: `Tests/ProtocolTests.swift`, `Tests/SharedFileTests.swift`

**Interfaces:**
- Produces (these are the contract every later task uses; declare exactly these names):

```swift
typealias DocumentID = String

struct Request: Codable, Sendable { let id: Int; let doc: DocumentID; let call: Call }
enum Call: Codable, Sendable {
    case open(path: String, maxPixels: Int)
    case command(id: String, args: [String: Int])
    case save(SavePayload)
    case close                                   // no reply
}
enum SavePayload: Codable, Sendable, Equatable {
    case text(SharedFileRef, convertToUTF8: Bool)
    case pdfHighlights([Highlight])
}
struct Highlight: Codable, Sendable, Equatable { let page: Int; let rect: CGRect; let color: RGBA }   // page is 0-based, rect in page space
struct RGBA: Codable, Sendable, Equatable { let red, green, blue, alpha: Double }

struct Response: Codable, Sendable { let id: Int; let outcome: Outcome }
enum Outcome: Codable, Sendable { case reply(Reply), failure(PluginFailure) }
struct PluginFailure: Error, Codable, Sendable, Equatable {
    enum Code: String, Codable, Sendable { case general, notText, notWritable, cannotEncode }
    let message: String
    let code: Code
    init(_ message: String, code: Code = .general)
}

struct Reply: Codable, Sendable { var view: View? = nil; var sidebar: [Panel]? = nil; var commands: [CommandSpec]? = nil }
enum View: Codable, Sendable {
    case markdown([MarkdownBlock])
    case pdf(path: String)
    case bitmap(SharedBitmap)
    case text(SharedText)
}
struct SharedBitmap: Codable, Sendable { let file: SharedFileRef; let width: Int; let height: Int; let bytesPerRow: Int }
struct SharedText: Codable, Sendable { let file: SharedFileRef; let editable: Bool; let note: String? }   // UTF-8 bytes
enum Panel: Codable, Sendable { case outline([OutlineItem]), thumbnails, info([InfoRow]) }
struct OutlineItem: Codable, Sendable, Equatable { let title: String; let level: Int; let line: Int }
struct InfoRow: Codable, Sendable, Equatable { let label: String; let value: String }
struct CommandSpec: Codable, Sendable, Equatable { let id: String; let title: String; var symbol: String? = nil; var shortcut: String? = nil; var verb: String? = nil }
struct PluginManifest: Codable, Equatable { let id: String; let name: String; let types: [String]; let executable: String }   // unchanged

// MarkdownBlock.swift
indirect enum MarkdownBlock: Codable, Sendable, Equatable {
    case heading(level: Int, spans: [Span], line: Int)
    case paragraph([Span])
    case list(ordered: Bool, start: Int, items: [ListItem])
    case code(text: String, language: String?)
    case quote([MarkdownBlock])
    case rule
    case table([[[Span]]])
}
struct ListItem: Codable, Sendable, Equatable { let blocks: [MarkdownBlock]; let line: Int; let checked: Bool? }
struct Span: Codable, Sendable, Equatable { let text: String; let style: SpanStyle; let link: String? }
struct SpanStyle: OptionSet, Codable, Sendable, Hashable { … }          // existing bits

// SharedFile.swift
struct SharedFileRef: Codable, Sendable, Equatable { let path: String; let byteCount: Int }
enum SharedFile {
    static let prefix = "ppp-shared-"
    static let maxBytes = 1 << 32
    static func create(byteCount: Int, fill: (UnsafeMutableRawBufferPointer) throws -> Void) throws(PluginFailure) -> SharedFileRef
    static func create(_ data: Data) throws(PluginFailure) -> SharedFileRef
    static func map(_ ref: SharedFileRef) throws(PluginFailure) -> MappedFile
}
final class MappedFile: @unchecked Sendable { let bytes: UnsafeRawBufferPointer }   // munmap in deinit
```

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct ProtocolTests {
    @Test func requestRoundTrips() throws {
        let request = Request(id: 7, doc: "d1", call: .save(.text(SharedFileRef(path: "/tmp/x", byteCount: 3), convertToUTF8: true)))
        let decoded = try JSONDecoder().decode(Request.self, from: JSONEncoder().encode(request))
        #expect(decoded.id == 7)
        guard case .save(.text(let ref, let convert)) = decoded.call else { Issue.record("wrong call"); return }
        #expect(ref.byteCount == 3 && convert)
    }
    @Test func failureCarriesItsCode() throws {
        let response = Response(id: 1, outcome: .failure(PluginFailure("no", code: .cannotEncode)))
        let decoded = try JSONDecoder().decode(Response.self, from: JSONEncoder().encode(response))
        guard case .failure(let failure) = decoded.outcome else { Issue.record("wrong outcome"); return }
        #expect(failure == PluginFailure("no", code: .cannotEncode))
    }
    @Test func markdownTreeRoundTrips() throws {
        let blocks: [MarkdownBlock] = [.heading(level: 1, spans: [Span(text: "T", style: .strong, link: nil)], line: 1),
                                       .list(ordered: false, start: 1, items: [ListItem(blocks: [.paragraph([])], line: 2, checked: true)])]
        #expect(try JSONDecoder().decode([MarkdownBlock].self, from: JSONEncoder().encode(blocks)) == blocks)
    }
    @Test func unknownCallIsRejected() {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Request.self, from: Data(#"{"id":1,"doc":"d","call":{"explode":{}}}"#.utf8)) }
    }
}

@Suite struct SharedFileTests {
    @Test func createThenMapReturnsTheBytesAndRemovesTheName() throws {
        let ref = try SharedFile.create(Data("hello".utf8))
        let mapped = try SharedFile.map(ref)
        #expect(Data(mapped.bytes) == Data("hello".utf8))
        #expect(!FileManager.default.fileExists(atPath: ref.path))
    }
    @Test func refusesPathsOutsideTheTempDirectory() {
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: "/etc/hosts", byteCount: 1)) }
    }
    @Test func refusesAByteCountLargerThanTheFile() throws {
        let ref = try SharedFile.create(Data("hi".utf8))
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: ref.path, byteCount: 4096)) }
    }
    @Test func refusesSymlinks() throws {
        let link = FileManager.default.temporaryDirectory.appending(path: SharedFile.prefix + UUID().uuidString)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/etc/hosts")
        defer { try? FileManager.default.removeItem(at: link) }
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: link.path, byteCount: 1)) }
    }
}
```

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: compile failure (types don't exist).
- [ ] **Step 3:** Implement the types above. `Codable` is synthesized everywhere. `SharedFile.create` uses the logic in today's `SharedBitmap.write` (O_CREAT|O_EXCL, 0600, ftruncate, mmap). `SharedFile.map` uses today's `SharedBitmapReader` checks: parent directory equals the standardized temp directory, name has `prefix`, `O_RDONLY|O_NOFOLLOW`, `fstat` size ≥ `byteCount`, `byteCount` ≤ `maxBytes`, unlink after open, `MAP_PRIVATE`. A zero-byte ref maps to an empty buffer without calling `mmap`. Remove `SharedBitmapFormat.prefix` (keep `maxDimension` as `SharedBitmap.maxDimension = 16_384`). Nothing uses these types yet, so the old code keeps compiling: put the new `PluginFailure` in Shared and delete the SDK's copy, adjusting its two call sites.
- [ ] **Step 4:** Run `scripts/build.sh test`. Expected: all tests pass.
- [ ] **Step 5:** Stage: `git add Sources/Shared Tests project.yml`.

---

### Task 3: Move host, SDK and existing plugins to the typed protocol

No user-visible change. This is the step most likely to cost speed, so it ends with an A/B run.

**Files:**
- Rewrite: `Sources/PluginSDK/PluginMain.swift`
- Modify: `Plugins/markdown/{MarkdownPlugin,MarkdownTree}.swift`, `Plugins/pdf/PDFPlugin.swift`, `Plugins/image/ImagePlugin.swift`
- Modify: `Sources/Host/Plugins/PluginProcess.swift`, `Sources/Host/Documents/DocumentViewController.swift`, `Sources/Host/Components/*.swift`, `Sources/Host/Bench/BenchRunner.swift`
- Test: `Tests/MarkdownTreeTests.swift` (assert on typed blocks)

**Interfaces:**
- Consumes: Task 2 types.
- Produces:

```swift
// SDK
protocol PluginHandler {
    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply
    func command(_ doc: DocumentID, id: String, args: [String: Int]) throws(PluginFailure) -> Reply   // default: throws "unknown command"
    func save(_ doc: DocumentID, _ payload: SavePayload) throws(PluginFailure) -> Reply              // default: throws "This plugin can't save."
    func close(_ doc: DocumentID)                                                                    // default: no-op
}
enum PluginMain { static func run(_ handler: any PluginHandler) -> Never }   // keep the existential and its comment

// Host
final class PluginProcess {
    func request(_ call: Call, doc: DocumentID, timeout: Duration) async throws(PluginFailure) -> Reply
    func notifyClose(_ doc: DocumentID)                // replaces notify("close", …)
    // attach, detach, isRunning, pid, lastLaunch, stopAndWait, footprintMB: unchanged
}
enum PluginTimeout { static let open = Duration.seconds(10), command = Duration.seconds(10), save = Duration.seconds(30) }
protocol Component: AnyObject { var view: NSView { get }; func perform(_ verb: String) -> Bool }   // unchanged in this task
// DocumentViewController.load() becomes: func load() async   (returns once content or the failure view is showing)
```

- [ ] **Step 1:** Update `MarkdownTreeTests` to the typed tree, e.g. `#expect(blocks[0] == .heading(level: 1, spans: [Span(text: "Title", style: [], link: nil)], line: 1))`, task items' `checked == [false, true, nil]` and `line == [3, 4, 5]`, `taskCounts` unchanged, outline returns `[OutlineItem]`.
- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: compile failure in `MarkdownTree`.
- [ ] **Step 3:** Port `MarkdownTree` to build `[MarkdownBlock]` and `[OutlineItem]`, and the three plugins to return `Reply` (info rows become `InfoRow`, commands become `CommandSpec`). `SharedBitmap.write(CGImage)` in the SDK now returns `SharedBitmap` built on `SharedFile.create(byteCount:fill:)`.
- [ ] **Step 4:** Port the host: `PluginProcess` encodes `Request` and decodes `Response` (keep the `memchr` line scan), and `request` wraps the pending table in a `CheckedContinuation`. The timeout parameter is accepted but not enforced until Task 4. `DocumentViewController` switches on `View` and `Panel`. `MarkdownComponent` renders `[MarkdownBlock]`, `BitmapComponent` maps `SharedBitmap` through `SharedFile.map` with no pixel copy: keep the `MappedFile` alive for the `CGDataProvider`'s lifetime via its release callback. Delete every `[String: Any]` in host and SDK: `grep -rn "String: Any" Sources Plugins` must print nothing.
- [ ] **Step 5:** Run `scripts/build.sh test && scripts/build.sh`. Expected: pass, no warnings.
- [ ] **Step 6:** Run `scripts/bench-ab.sh main` (head is the working tree, base is a worktree of `main`). Expected: no gated regression. If `large.md` regresses, give `Span` and `ListItem` a compact unkeyed encoding (`[text, style, link?]`, the old wire shape) with hand-written `init(from:)`/`encode(to:)`, add a round-trip test for it, and rerun.
- [ ] **Step 7:** Stage: `git add -A Sources Plugins Tests`.

---

### Task 4: Robust plugin processes

**Files:**
- Modify: `Sources/Host/Plugins/PluginProcess.swift`, `Sources/Host/App/Config.swift`, `Sources/Host/Plugins/PluginCatalog.swift`
- Create: `Tests/TestPlugin/main.swift`, `Tests/TestSupport.swift`
- Modify: `project.yml` (new `TestPlugin` tool target, PRODUCT_NAME `test-plugin`, sources `Tests/TestPlugin` + `Sources/Shared` + `Sources/PluginSDK`; HostTests gets build-only dependencies on `TestPlugin`; HostTests sources exclude `Tests/TestPlugin`)
- Test: `Tests/PluginProcessTests.swift`

**Interfaces:**
- Consumes: `PluginProcess.request(_:doc:timeout:)` from Task 3.
- Produces: `TestProducts.helpers: URL` (directory holding built executables, i.e. the test bundle's parent), `TestProducts.entry(id: String, executable: String, types: [String]) -> PluginEntry`. `PluginProcess.init(entry:idleSeconds:)` unchanged.

`test-plugin` behavior is keyed by the `open` path: `"echo"` replies `Reply(sidebar: [.info([InfoRow(label: "pid", value: "\(getpid())")])])`; `"crash"` calls `abort()`; `"hang"` sleeps forever; `"garbage"` prints `not json` and a newline; `"stderr"` writes `hello from plugin` to stderr, then echoes.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite(.serialized) struct PluginProcessTests {
    let process = PluginProcess(entry: TestProducts.entry(id: "test", executable: "test-plugin", types: []), idleSeconds: 0.2)

    @Test func repliesToARequest() async throws {
        let reply = try await process.request(.open(path: "echo", maxPixels: 1), doc: "a", timeout: .seconds(5))
        #expect(reply.sidebar?.isEmpty == false)
    }
    @Test func crashFailsThePendingRequestAndNotifiesAttachedDocuments() async {
        var crashed: String?
        process.attach("a") { crashed = $0 }
        await #expect(throws: PluginFailure.self) { try await process.request(.open(path: "crash", maxPixels: 1), doc: "a", timeout: .seconds(5)) }
        #expect(crashed?.contains("stopped") == true)
    }
    @Test func hangIsKilledAtTheTimeout() async {
        let started = ContinuousClock.now
        do { _ = try await process.request(.open(path: "hang", maxPixels: 1), doc: "a", timeout: .milliseconds(300)); Issue.record("no timeout") }
        catch { #expect(error.message.contains("didn't respond")) }
        #expect(ContinuousClock.now - started < .seconds(2))
        #expect(!process.isRunning)
    }
    @Test func malformedReplyFailsInsteadOfWaitingForever() async {
        do { _ = try await process.request(.open(path: "garbage", maxPixels: 1), doc: "a", timeout: .seconds(5)); Issue.record("accepted garbage") }
        catch { #expect(error.message.contains("couldn't read")) }
    }
    @Test func restartsAfterACrash() async throws {
        _ = try? await process.request(.open(path: "crash", maxPixels: 1), doc: "a", timeout: .seconds(5))
        _ = try await process.request(.open(path: "echo", maxPixels: 1), doc: "b", timeout: .seconds(5))
        #expect(process.isRunning)
    }
    @Test func stopsWhenIdleAndStartsAgainOnDemand() async throws {
        process.attach("a") { _ in }
        _ = try await process.request(.open(path: "echo", maxPixels: 1), doc: "a", timeout: .seconds(5))
        process.detach("a")
        try await Task.sleep(for: .seconds(1))
        #expect(!process.isRunning)
        _ = try await process.request(.open(path: "echo", maxPixels: 1), doc: "b", timeout: .seconds(5))
        #expect(process.isRunning)
    }
}
```

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: the timeout, malformed and crash-message tests fail.
- [ ] **Step 3:** Implement in `PluginProcess`: a per-request deadline (a `Task.sleep` raced against the continuation, or a `DispatchSourceTimer`) that sends `SIGKILL` and records the timeout message so `exited` uses it for every pending request and attached document. A line that doesn't decode as `Response` kills the process with the malformed message. Stderr gets its own `Pipe`, split into lines and logged at `.info` to category `plugins` as `"\(entry.id): \(line)"`. Replace the `FileHandle.standardError.write` calls in `Config` and `PluginCatalog` with `Logger` warnings.
- [ ] **Step 4:** Run `scripts/build.sh test`. Expected: all pass. Run the app, open `small.md`, and check `log show --last 1m --predicate 'subsystem == "dev.previewpp.PreviewPP"'` runs without errors.
- [ ] **Step 5:** Stage: `git add -A Sources Tests project.yml`.

---

### Task 5: Plain text plugin

**Files:**
- Create: `Plugins/text/manifest.json`, `Plugins/text/main.swift`, `Plugins/text/TextPlugin.swift`, `Plugins/text/TextCodec.swift`
- Modify: `project.yml` (target `TextPlugin`, PRODUCT_NAME `text-plugin`, embedded in `Contents/Helpers` with its manifest copied to `Resources/Plugins/text`; HostTests compiles `Plugins/text` minus `main.swift`/`manifest.json` and depends on `TextPlugin` build-only. Info.plist `CFBundleDocumentTypes`: add `public.plain-text`, `public.json`, `public.xml`, `public.yaml`, `public.toml`, keep `LSHandlerRank: Alternate`, set `CFBundleTypeRole: Editor` for text and PDF)
- Modify: `Tests/TestSupport.swift` (add `TempFile.make(_ bytes: Data, name: String = "f.txt") throws -> URL`, a fresh temp directory per call, and `TempFile.makePDF(pages: Int) throws -> URL` for Task 9)
- Test: `Tests/TextCodecTests.swift`, `Tests/TextPluginTests.swift`

**Interfaces:**
- Consumes: `PluginHandler`, `SharedFile`, `SavePayload.text`, `PluginFailure.Code`.
- Produces:

```swift
enum LineEnding: String, Sendable { case lf = "LF", crlf = "CRLF", cr = "CR" }
struct TextFormat: Equatable, Sendable { let encoding: String.Encoding; let hasBOM: Bool; let lineEnding: LineEnding }
enum TextCodec {
    static func decode(_ data: Data) throws(PluginFailure) -> (text: String, format: TextFormat)
    static func encode(_ text: String, as format: TextFormat) throws(PluginFailure) -> Data
}
enum TextLimits { static let editableBytes = 10 * 1_048_576 }
final class TextPlugin: PluginHandler { init() }
```

Manifest: `{ "id": "text", "name": "Plain Text", "types": ["public.plain-text", "public.json", "public.xml", "public.yaml", "public.toml"], "executable": "text-plugin" }`.

Decode order: UTF-8 BOM, UTF-16 LE/BE BOM, then NUL byte anywhere → `.notText` with the not-text message, then strict UTF-8, then `NSString.stringEncoding(for:encodingOptions:…)` limited to `.windowsCP1252` and `.macOSRoman` with lossy conversion disallowed, otherwise `.notText`. Line ending = most frequent of CRLF, lone LF, lone CR; ties and no breaks → LF. Encode normalizes every line break to the format's ending, encodes without lossy conversion (failure → `.cannotEncode`, message "“NAME” can't be saved as <localized encoding name>." where the plugin fills NAME), and prepends the BOM when `hasBOM`.

`TextPlugin.open`: reads with `Data(contentsOf:options: .alwaysMapped)`, decodes, writes the UTF-8 to a `SharedFile`, replies `.text(SharedText(file:, editable: size <= TextLimits.editableBytes, note: editable ? nil : <read-only note>))` and an info panel: Lines, Encoding (localized name, plus " with BOM"), Line endings, Size. It keeps `(path, format, original text)` per document, and the original text only when editable.

`TextPlugin.save(.text(ref, convertToUTF8))`: maps the ref, decodes UTF-8. If the text equals the original, it returns without writing. Otherwise: resolve symlinks; if the target isn't writable, throw `.notWritable` with the not-writable message; encode (format with `.utf8`, no BOM, when `convertToUTF8`); write to a temp file in the target's directory, then `FileManager.replaceItemAt(target, withItemAt:)`; set the target's POSIX permissions back to what they were. Update the stored format and original. Reply with a fresh info panel.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct TextCodecTests {
    @Test func detectsEncodingsAndBOMs() throws {
        #expect(try TextCodec.decode(Data("héllo\n".utf8)).format == TextFormat(encoding: .utf8, hasBOM: false, lineEnding: .lf))
        #expect(try TextCodec.decode(Data([0xEF, 0xBB, 0xBF]) + Data("a\r\nb\r\n".utf8)).format == TextFormat(encoding: .utf8, hasBOM: true, lineEnding: .crlf))
        #expect(try TextCodec.decode(Data([0xFF, 0xFE, 0x61, 0x00])).format.encoding == .utf16LittleEndian)
        #expect(try TextCodec.decode(Data([0xFE, 0xFF, 0x00, 0x61])).format.encoding == .utf16BigEndian)
        #expect(try TextCodec.decode(Data([0x63, 0x61, 0x66, 0xE9])).format.encoding == .windowsCP1252)   // "café" in Windows-1252
    }
    @Test func emptyFileIsUTF8() throws {
        let decoded = try TextCodec.decode(Data())
        #expect(decoded.text.isEmpty && decoded.format.encoding == .utf8)
    }
    @Test func nulBytesMeanNotText() {
        #expect(throws: PluginFailure("This doesn't look like a text file.", code: .notText)) { try TextCodec.decode(Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])) }
    }
    @Test func uniformFilesRoundTripByteForByte() throws {
        for bytes in [Data("a\nb\n".utf8), Data([0xEF, 0xBB, 0xBF]) + Data("a\r\nb".utf8), Data([0x63, 0x61, 0x66, 0xE9, 0x0D])] {
            let decoded = try TextCodec.decode(bytes)
            #expect(try TextCodec.encode(decoded.text, as: decoded.format) == bytes)
        }
    }
    @Test func editsKeepTheFilesLineEnding() throws {
        let format = TextFormat(encoding: .utf8, hasBOM: false, lineEnding: .crlf)
        #expect(try TextCodec.encode("a\r\nb\nc", as: format) == Data("a\r\nb\r\nc".utf8))
    }
    @Test func invalidUTF8FallsBackAndRoundTrips() throws {
        let bytes = Data("2024-01-01 user ".utf8) + Data([0x4A, 0xF6, 0x72, 0x67]) + Data(" logged in\n".utf8)   // "Jörg" in Latin-1
        let decoded = try TextCodec.decode(bytes)
        #expect(decoded.text.contains("Jörg"))
        #expect(try TextCodec.encode(decoded.text, as: decoded.format) == bytes)
    }
    @Test func unrepresentableCharactersThrowCannotEncode() {
        let format = TextFormat(encoding: .windowsCP1252, hasBOM: false, lineEnding: .lf)
        let error = #expect(throws: PluginFailure.self) { try TextCodec.encode("smile 🙂", as: format) }
        #expect(error?.code == .cannotEncode)
    }
}

@Suite struct TextPluginTests {
    @Test func unchangedSaveLeavesMixedLineEndingsAlone() throws { /* bytes "a\nb\r\nc\n"; open; save same text; file bytes unchanged */ }
    @Test func editSavesInTheOriginalEncodingAndBOM() throws { /* UTF-8 BOM + CRLF file; save "x\ny\n"; bytes == BOM + "x\r\ny\r\n" */ }
    @Test func convertToUTF8WritesUTF8WithoutBOM() throws { /* CP1252 file; save "🙂" with convertToUTF8: true; bytes == "🙂".utf8 */ }
    @Test func refusesToSaveReadOnlyFile() throws { /* chmod 0444; save edited text throws .notWritable; bytes unchanged */ }
    @Test func savingThroughSymlinkWritesTarget() throws { /* link -> target; open link; save; target has new text; link is still a symlink */ }
    @Test func keepsPermissions() throws { /* chmod 0640; save edit; permissions still 0640 */ }
    @Test func largeFilesOpenReadOnly() throws { /* 10 MB + 1 byte file; reply .text has editable == false and note == read-only note */ }
}
```

Each `TextPluginTests` comment states the exact setup and assertion; write them as code in the same style as `TextCodecTests`.

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: compile failure (`TextCodec` missing).
- [ ] **Step 3:** Implement `TextCodec`, `TextPlugin`, the manifest and the project changes.
- [ ] **Step 4:** Run `scripts/build.sh test && scripts/build.sh`. Expected: all pass, no warnings. `ls build/dd/Build/Products/Release/PreviewPP.app/Contents/Helpers` lists `text-plugin`.
- [ ] **Step 5:** Stage: `git add -A Plugins/text Tests project.yml`.

---

### Task 6: Text component and viewing

**Files:**
- Create: `Sources/Host/Components/TextComponent.swift`
- Modify: `Sources/Host/Documents/DocumentViewController.swift` (install `.text`), `bench/ppbench.py` (`FILES` gains `small.txt`, `medium.log`, `large.log`; `APPLE` maps `txt` and `log` to TextEdit; labels "Text, 10 KB", "Log, 11 MB", "Log, 86 MB")
- Test: `Tests/TextSaveIntegrationTests.swift` (the open half here, the save half in Task 8)

**Interfaces:**
- Consumes: `View.text(SharedText)`, `SharedFile.map`.
- Produces: `final class TextComponent: NSObject, Component, NSTextViewDelegate { init(text: String, editable: Bool, note: String?); func update(text: String) }`, verbs `zoom-in`, `zoom-out`, `toggle-wrap`. The text plugin's reply lists commands Zoom In (`cmd+=`), Zoom Out (`cmd+-`), Wrap Lines (`opt+cmd+w`) with those verbs.

The component is an `NSTextView.scrollableTextView()` (TextKit 2 by default on macOS 26, checked), `NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)`, `usesFindBar = true`, `isIncrementalSearchingEnabled = true`, wrap on, rich text and smart substitutions off (quotes, dashes, links, spelling). A non-nil `note` shows as a slim label above the text. `update(text:)` keeps the scroll position.

- [ ] **Step 1: Write the failing test**

```swift
@Suite(.serialized) struct TextSaveIntegrationTests {
    @Test func openThroughTheRealPluginDeliversTheText() async throws {
        let file = try TempFile.make(Data("one\ntwo\n".utf8))
        let process = PluginProcess(entry: TestProducts.entry(id: "text", executable: "text-plugin", types: ["public.plain-text"]), idleSeconds: 5)
        let reply = try await process.request(.open(path: file.path, maxPixels: 0), doc: "d", timeout: PluginTimeout.open)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        #expect(String(decoding: try SharedFile.map(shared.file).bytes, as: UTF8.self) == "one\ntwo\n")
        #expect(shared.editable)
    }
}
```

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: PASS already if Task 5 is right; this is the end-to-end guard. Then confirm the host can't show it yet: open `bench/fixtures/small.txt` in the app. Expected: "sent something the app can't show".
- [ ] **Step 3:** Implement `TextComponent` and the `.text` case in `DocumentViewController.install`.
- [ ] **Step 4: Measure.** In `bench/ppbench.py`: add `--files` to `run` (comma-separated subset of `FILES`; `publish` still refuses partial results), and make `ab` report a file the base can't open as "new, not compared" instead of failing, since `main` has no text plugin. Then `scripts/build.sh` and `python3 bench/ppbench.py run --files small.txt,medium.log,large.log --out build/text-measure.json` (never the default `--out`, which is the committed reference). This needs Preview and TextEdit closed: ask the owner first. Compare `launch.<file>.content` with `apple.<file>.textedit_window`. Also open a generated 5 MB single-line JSON file and scroll it.
- [ ] **Step 5:** If `large.log` misses its target or beachballs: (a) first try setting the text after the window is on screen with layout limited to the viewport (`NSTextLayoutManager` does this when the text storage is filled before the view lays out); (b) if still missing, have the plugin send only the first `TextLimits.displayBytes = 16 * 1_048_576` bytes, cut at a line break, with the note "Showing the first 16 MB of SIZE. Read-only." Add a `TextPluginTests.hugeFilesAreTruncatedAtALineBreak` test if (b) is taken. Record the before and after numbers in the task summary.
- [ ] **Step 6:** Check by hand: Space in Finder on `small.txt` shows it, Cmd+F finds text, Wrap Lines toggles, the sidebar shows Lines, Encoding, Line endings and Size.
- [ ] **Step 7:** Stage: `git add -A Sources bench Tests Plugins`.

---

### Task 7: Routing for untyped files and Reload Config

**Files:**
- Modify: `Sources/Host/Plugins/PluginCatalog.swift`, `Sources/Host/App/Config.swift`, `Sources/Host/App/AppDelegate.swift`, `Sources/Host/App/MainMenu.swift`
- Test: `Tests/RoutingTests.swift`, `Tests/ConfigTests.swift`

**Interfaces:**
- Produces: `PluginCatalog.config` becomes `var`; `PluginCatalog.reload(config: Config)`. A config route key `open.none` means "files with no extension" and is stored as `routes[""]`.

Rule: when the file's type is dynamic (`UTType.isDynamic`) or exactly `.data`, `candidates(for:)` returns the routed plugin (if enabled) and nothing else, and `defaultPlugin(for:)` returns it. Typed files keep today's behavior.

- [ ] **Step 1: Write the failing tests** (add to `RoutingTests`, whose catalog fixture already includes `text`)

```swift
@Test func untypedExtensionsUseTheConfigRoute() {
    #expect(catalog("open.conf = text").defaultPlugin(for: URL(filePath: "/tmp/nginx.conf"))?.id == "text")
    #expect(catalog("").defaultPlugin(for: URL(filePath: "/tmp/nginx.conf")) == nil)
}
@Test func extensionlessDotfilesUseTheNoneRoute() throws {
    let file = try TempFile.make(Data("export A=1\n".utf8), name: ".zshrc")   // Finder reports public.data
    #expect(catalog("open.none = text").defaultPlugin(for: file)?.id == "text")
    #expect(catalog("open.none = text\ndisable = text").defaultPlugin(for: file) == nil)
}
@Test func typedFilesStillIgnoreRoutesToPluginsThatDontSupportThem() {
    #expect(catalog("open.md = image").defaultPlugin(for: URL(filePath: "/tmp/notes.md"))?.id == "markdown")
}
```

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: the first two fail.
- [ ] **Step 3:** Implement the rule and the `open.none` key. Add "Reload Config" to the app menu: re-read `Config.load()`, call `catalog.reload(config:)`, restart the hotkey monitor if `quickLookKey` changed. It applies to documents opened afterwards.
- [ ] **Step 4:** Run `scripts/build.sh test`. Expected: all pass.
- [ ] **Step 5:** Stage: `git add -A Sources Tests`.

---

### Task 8: Editing and saving

**Files:**
- Create: `Sources/Host/Documents/Edits.swift`, `Sources/Host/Documents/SavePrompts.swift`, `Sources/Host/Documents/FileWatcher.swift`
- Modify: `Tests/TestSupport.swift` (add `waitUntil(seconds: Double, _ condition: () -> Bool) async throws`, polling every 20 ms and failing on timeout)
- Modify: `Component.swift`, `TextComponent.swift`, `DocumentViewController.swift`, `DocumentWindowController.swift`, `QuickLookPanel.swift`, `AppDelegate.swift`, `MainMenu.swift`
- Test: `Tests/FileWatcherTests.swift`, `Tests/TextSaveIntegrationTests.swift`

**Interfaces:**
- Consumes: `PluginProcess.request`, `SavePayload`, `PluginFailure.Code`.
- Produces:

```swift
enum Edits: Codable, Equatable { case text(String), pdfHighlights([Highlight]) }

protocol Component: AnyObject {
    var view: NSView { get }
    func perform(_ verb: String) -> Bool
    var onEdit: (() -> Void)? { get set }      // extension default: get nil, set ignored
    func pendingEdits() -> Edits?              // default nil
    func restore(_ edits: Edits)               // default no-op
    func didSave()                             // default no-op
}

protocol SavePrompts: AnyObject {
    func confirmOverwriteNewerFile(named: String) async -> Bool
    func confirmSaveAsUTF8(reason: String) async -> Bool
}
enum SaveOutcome: Equatable { case saved, cancelled, failed(String) }

// DocumentViewController
init(url: URL, entry: PluginEntry, process: PluginProcess, config: Config, allowsEditing: Bool)
private(set) var isEdited: Bool
private(set) var component: Component?          // readable so tests can drive edits
var onEditedChanged: ((DocumentViewController) -> Void)?
func save(prompts: any SavePrompts) async -> SaveOutcome
func discardEdits()

final class FileWatcher { init(url: URL, onChange: @escaping () -> Void); func stop() }
```

Behavior:
- `TextComponent` is editable only when `allowsEditing && shared.editable`. The panel passes `allowsEditing: false`; windows pass `true`. Text view changes call `onEdit`. `pendingEdits()` returns `.text(string)` when the text differs from the last loaded or saved baseline.
- `DocumentViewController` sets `isEdited` from `onEdit`, mirrors it to `view.window?.isDocumentEdited`, and records the file's `contentModificationDate` at load and after each save as `knownModification`.
- `save(prompts:)`: no pending edits → `.saved`. If the file's modification date is newer than `knownModification`, ask `confirmOverwriteNewerFile`; no → `.cancelled`. Build the payload (text: `SharedFile.create(Data(string.utf8))`), request `.save` with `PluginTimeout.save`. On `.cannotEncode`, ask `confirmSaveAsUTF8(reason: failure.message)` and retry once with `convertToUTF8: true`, or return `.cancelled`. Other failures → `.failed(message)` with edits untouched. Success → `component.didSave()`, `isEdited = false`, refresh `knownModification`, apply the reply's sidebar.
- `FileWatcher`: `DispatchSource.makeFileSystemObjectSource` on an `O_EVTONLY` descriptor for `.write, .extend, .delete, .rename`, on the main queue. On delete or rename it reopens the path (retrying for up to 1 s, for atomic saves) and fires `onChange`. Changes are coalesced over 200 ms. The document reloads (re-sends `.open`, then `TextComponent.update`) when the change isn't its own save (modification date differs from `knownModification`) and `isEdited` is false.
- `DocumentWindowController` implements `SavePrompts` with sheets using the Global Constraints copy, adds `@objc saveDocument(_:)` (File > Save, Cmd+S, enabled only when `current?.isEdited == true` via `validateMenuItem`), and asks Save / Don't Save / Cancel in `windowShouldClose` and before an Open With switch when edited. Failed saves show an alert with the failure message.
- `AppDelegate.applicationShouldTerminate` returns `.terminateLater` when any window is edited, asks for each in turn (bringing it to front), and replies `false` on the first Cancel.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite(.serialized) struct FileWatcherTests {
    @Test func firesOnWrite() async throws { /* write → onChange within 2 s */ }
    @Test func keepsWatchingAfterAtomicReplace() async throws {
        let file = try TempFile.make(Data("a".utf8))
        var count = 0
        let watcher = FileWatcher(url: file) { count += 1 }
        defer { watcher.stop() }
        try Data("b".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { count == 1 }
        try Data("c".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { count == 2 }
    }
}

// TextSaveIntegrationTests, added
final class StubPrompts: SavePrompts { var overwrite = true; var utf8 = true; var asked: [String] = [] /* records which prompt ran */ }

@Test func saveWritesThroughThePluginAndClearsEditedState() async throws {
    /* DocumentViewController on a temp CRLF file with allowsEditing: true; await load(); component.restore(.text("x\ny\n"));
       isEdited == true; await save(prompts:) == .saved; file bytes == "x\r\ny\r\n"; isEdited == false */
}
@Test func newerFileOnDiskAsksBeforeOverwriting() async throws {
    /* load; edit; touch the file with a newer date and other content; prompts.overwrite = false;
       save == .cancelled; file content is the other content; isEdited still true */
}
@Test func unencodableTextOffersUTF8() async throws {
    /* CP1252 file; restore(.text("🙂")); prompts.utf8 = true; save == .saved; asked == ["utf8"]; bytes == "🙂".utf8 */
}
@Test func pluginCrashDuringSaveKeepsTheEdits() async throws {
    /* load; edit; kill(process.pid!, SIGKILL) right before save; save returns .failed(_); component.pendingEdits() == .text(edited) */
}
```

Write each commented test as code with exactly those assertions.

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: compile failure.
- [ ] **Step 3:** Implement `Edits`, the `Component` additions, `TextComponent` editing, `SavePrompts`, `DocumentViewController` save and reload, `FileWatcher`, and the window and app prompts.
- [ ] **Step 4:** Run `scripts/build.sh test && scripts/build.sh`. Expected: all pass, no warnings.
- [ ] **Step 5:** Check by hand: open `small.txt` in a window, type (close button shows the dot), Cmd+W asks, Cancel keeps it, Save writes it; Space on the same file shows it read-only; `echo more >> file` while open with no edits reloads the tab; quitting with an edited window asks.
- [ ] **Step 6:** Stage: `git add -A Sources Tests`.

---

### Task 9: PDF joins the save flow

**Files:**
- Modify: `Plugins/pdf/PDFPlugin.swift` (`save`), `Sources/Host/Components/PDFComponent.swift`, `project.yml` (HostTests compiles `Plugins/pdf` minus `main.swift`/`manifest.json`)
- Test: `Tests/PDFSaveTests.swift`

**Interfaces:**
- Consumes: `SavePayload.pdfHighlights`, `Highlight`, `RGBA`, the `Component` edit API from Task 8.
- Produces: none new.

Behavior: the PDF reply drops its `save` command and keeps Zoom In, Zoom Out and Highlight Selection. `PDFComponent.perform("highlight")` adds the annotation to the view as today, appends a `Highlight` (page index, `line.bounds(for: page)`, `RGBA(red: 1, green: 0.8, blue: 0, alpha: 0.5)`) to its pending list, and calls `onEdit`. `pendingEdits()` returns `.pdfHighlights(pending)` when the list isn't empty. `didSave()` clears it. `restore(.pdfHighlights)` adds the annotations to the view and the pending list. The host no longer writes PDFs: delete `pdfView.document?.write`. `PDFPlugin.save` opens the file with `PDFDocument` (PDFKit is linked; linking adds 0.3 ms to process start, measured, and `open` stays on CoreGraphics), adds one `.highlight` annotation per `Highlight`, checks writability (not-writable failure), writes to a temp file in the same directory, and replaces the original with `FileManager.replaceItemAt`.

- [ ] **Step 1: Write the failing test**

```swift
@Suite struct PDFSaveTests {
    @Test func savedHighlightsAreInTheFile() throws {
        let file = try TempFile.makePDF(pages: 1)   // US Letter pages drawn with CGContext(url:mediaBox:), so tests don't need bench fixtures
        let plugin = PDFPlugin()
        _ = try plugin.open("d", path: file.path, maxPixels: 0)
        let highlight = Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: RGBA(red: 1, green: 0.8, blue: 0, alpha: 0.5))
        _ = try plugin.save("d", .pdfHighlights([highlight]))
        let annotations = PDFDocument(url: file)!.page(at: 0)!.annotations.filter { $0.type == "Highlight" }
        #expect(annotations.count == 1)
        #expect(abs(annotations[0].bounds.minX - 72) < 0.5 && abs(annotations[0].bounds.width - 200) < 0.5)
    }
    @Test func refusesReadOnlyPDF() throws { /* chmod 0444; save throws code .notWritable; file bytes unchanged */ }
}
```

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: FAIL ("This plugin can't save.").
- [ ] **Step 3:** Implement as described.
- [ ] **Step 4:** Run `scripts/build.sh test && scripts/build.sh`. Expected: all pass. Check by hand: highlight text in `small.pdf`, see the edited dot, Cmd+S, reopen in Preview++ and in Apple's Preview (ask the owner before opening Preview); the highlight is there.
- [ ] **Step 5:** Stage: `git add -A Plugins/pdf Sources Tests project.yml`.

---

### Task 10: Crash recovery

**Files:**
- Create: `Sources/Host/Documents/RecoveryStore.swift`
- Modify: `DocumentViewController.swift`, `AppDelegate.swift`
- Test: `Tests/RecoveryStoreTests.swift`

**Interfaces:**
- Consumes: `Edits`, `Component.restore`, `DocumentViewController.isEdited`, `discardEdits()`.
- Produces:

```swift
struct RecoveryRecord: Codable, Equatable { let id: String; let url: URL; let pluginID: String; let fileModified: Date?; let edits: Edits }
final class RecoveryStore {
    init(directory: URL)
    static let shared: RecoveryStore     // ~/Library/Application Support/<bundle id>/Recovery/
    func write(_ record: RecoveryRecord) throws
    func remove(id: String)
    func all() -> [RecoveryRecord]       // skips and logs unreadable files
}
// DocumentViewController gains: init(…, recovery: RecoveryStore?, recoveryID: String = UUID().uuidString); func restore(_ record: RecoveryRecord)
```

Behavior: after each edit, the document schedules a write 2 s later (each new edit restarts the delay) of `RecoveryRecord(id: recoveryID, url, pluginID, fileModified: knownModification, edits: pendingEdits)`. Save, Don't Save (`discardEdits`), and closing with no edits remove the record. Each record is one JSON file `<id>.json`, written atomically. The quick-look panel and bench mode pass `recovery: nil`. At launch outside bench mode, `AppDelegate` restores each record: if the file is gone, text edits go to the general pasteboard, an alert shows the file-gone copy, and the record is removed. Otherwise it opens a window with the record's plugin (falling back to the default plugin) and `recoveryID: record.id`; after `load()` it calls `restore(record)`, which applies the edits and marks the document edited. If the file's modification date differs from `record.fileModified`, a sheet shows the file-changed copy.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct RecoveryStoreTests {
    let store = RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "ppp-recovery-\(UUID().uuidString)"))
    let record = RecoveryRecord(id: "r1", url: URL(filePath: "/tmp/a.txt"), pluginID: "text", fileModified: Date(timeIntervalSince1970: 1), edits: .text("unsaved"))

    @Test func writeThenReadBack() throws { try store.write(record); #expect(store.all() == [record]) }
    @Test func rewriteReplacesTheRecord() throws {
        try store.write(record)
        try store.write(RecoveryRecord(id: "r1", url: record.url, pluginID: "text", fileModified: nil, edits: .text("newer")))
        #expect(store.all().map(\.edits) == [.text("newer")])
    }
    @Test func removeDeletesIt() throws { try store.write(record); store.remove(id: "r1"); #expect(store.all().isEmpty) }
    @Test func corruptFilesAreSkipped() throws { /* write record, plus "junk.json" containing "{" ; all() == [record] */ }
}
```

Also add to `TextSaveIntegrationTests`: `editsAreJournaledAfterTwoSecondsAndClearedOnSave` (edit, wait 2.5 s, `store.all().count == 1`, save, `store.all().isEmpty`).

- [ ] **Step 2:** Run `scripts/build.sh test`. Expected: compile failure.
- [ ] **Step 3:** Implement the store, the debounced journaling and the launch restore.
- [ ] **Step 4:** Run `scripts/build.sh test && scripts/build.sh`. Expected: all pass.
- [ ] **Step 5:** Check by hand: edit `small.txt` in a window, wait 3 s, `kill -9 $(pgrep -x PreviewPP)`, relaunch. The window comes back with the edits and the edited dot. Do the same with a PDF highlight.
- [ ] **Step 6:** Stage: `git add -A Sources Tests`.

---

### Task 11: Daily use and final verification

**Files:**
- Create: `Sources/Host/App/LoginItem.swift`
- Modify: `MainMenu.swift`, `README.md`

**Interfaces:**
- Produces: `enum LoginItem { static var isEnabled: Bool; static func toggle() throws }` over `SMAppService.mainApp`.

- [ ] **Step 1:** Add "Open at Login" to the app menu with a checkmark from `LoginItem.isEnabled`. A failed toggle shows an alert with the error.
- [ ] **Step 2:** README: add "Use it every day" (build, `cp -R` to /Applications, Get Info > Open With > Change All for `.txt`/`.pdf`/images, grant Accessibility and Finder access, turn on Open at Login), document `open.none`, the text plugin, Cmd+S and crash recovery in Config and Plugins, and update the protocol paragraph for `save` and typed messages. Run the humanizer pass on the new prose.
- [ ] **Step 3:** Full check: `scripts/build.sh test && scripts/build.sh`, no warnings; `grep -rn "String: Any\|try?" Sources Plugins` and justify each remaining `try?` in the task summary; `scripts/bench-ab.sh main` green.
- [ ] **Step 4:** Walk the spec's "Done means" list on the installed copy in /Applications, including Space on a config file, then Open, edit, save, and `git diff` of a CRLF fixture showing only the edited line.
- [ ] **Step 5:** Stage everything and report to the owner: what's ready, the measurements from Task 6, any `try?` kept, and the next gated step (commits on `foundation`, then a merge).
