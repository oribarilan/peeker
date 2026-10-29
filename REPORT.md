# Preview++: product fit and technical feasibility

October 2026. Sources: three research passes ([market](research/market.md), [plugin models](research/plugin-models.md), [platform](research/platform.md)) and a working POC in this repo, measured on an Apple M6 Mac running macOS 27.0.1 ([raw results](bench/results/results.md)).

## Verdict

**Product: go, with a sharper pitch.** Nobody ships an open-source, Mac-native viewer where third parties add a format with its own UI. Your first no-go doesn't trigger. But "Preview plus Markdown" is crowded: more than a dozen native Mac Markdown viewers launched on Hacker News in 2026 alone. The opening is the plugin host itself. Pitch it as "the open, plugin-based viewer for Mac", with text, Markdown and PDF as first-party plugins that prove the API works.

**Platform: no blockers, three real costs.** You need the 99 USD/year Apple Developer Program, because Homebrew started disabling casks that fail Gatekeeper on 2026-09-01. Since macOS 26.4, becoming the default app prompts the user once per file type. Loading native plugins signed by other developers needs an entitlement that weakens the app's protections. None of these block the idea; the third one shapes the plugin design.

**Technical: feasible, and fast where it counts.** The POC host opens text, Markdown, PDF and CSV through one plugin API, in four runtimes. First-party plugins compiled into the app reach content in 50 to 85 ms after the open call, including an 86 MB log and a 2,000-page PDF. They also put their window on screen sooner than Preview and TextEdit on every test file except large Markdown (section 5). The one slow case, an 844 KB Markdown file at about 820 ms, comes from my naive renderer, not the architecture.

**Plugin architecture: split.** Compile first-party plugins into the app. Run community plugins out of process, with a UI description the host renders natively and a web view for content that needs HTML. Raycast (AppKit) and Tinycast (SwiftUI) already prove this UI model in shipping Mac apps (section 3). Don't load third-party native code into the app. The POC shows why: a crashing in-process plugin killed the host every time, while a crashing process plugin or a hung web plugin left it running.

## 1. Product fit

### Who else is here

| Space | Closest players | Why they don't cover this |
|---|---|---|
| Multi-format Mac viewer | [Glim](https://github.com/glimapp/glim) (MIT, created 2026-10-09, 29 stars), [Telescopo](https://apps.apple.com/us/app/telescopo-universal-viewer/id6747908871?mt=12) (closed, 70+ formats) | All formats are built in, no plugin contract. Glim is the one to watch: open source, active, and it could add plugins. |
| Plugin-based document viewers | [Zathura](https://github.com/pwmt/zathura), [Okular](https://okular.kde.org/) | Plugins only add page formats, not mini-apps. On Mac, Zathura needs an unofficial tap and Okular ships untested nightlies. |
| Plugin-based previewer, other OS | [QL-Win QuickLook](https://github.com/QL-Win/QuickLook) (25.6k stars, 53 plugins) | Windows only. The best prior art for the plugin contract. |
| PDF | Skim (BSD), PDF Expert, PDFgear, Sioyek | PDF only, no format plugins. |
| Markdown | [Markdown Preview](https://github.com/pluk-inc/markdown-preview) (2.7k stars in 6 months), MarkEdit, Typora, Obsidian | Single format. Markdown viewing is now a commodity. |
| Quick Look add-ons | QLMarkdown (34k Homebrew installs a year), Syntax Highlight | Read-only previews. They can't take over system types like plain text or PDF. |

### Demand

- **Preview has visible bugs.** On macOS 26, Preview can't highlight text in some PDFs; the [Apple Community thread](https://discussions.apple.com/thread/256139925) has 463 "me too" replies. Users also report annotation loss on save across versions, and broken markup over tables.
- **Markdown has no native home on Mac.** People keep asking how to view `.md` files, and AI coding tools have added to the pile: ["I spend more time reading markdown than code"](https://news.ycombinator.com/item?id=47795468).
- **Mac users install community extensions.** Obsidian has 9.6k community plugins, Raycast has 3.5k extensions, and QLMarkdown gets 34k Homebrew installs a year.

The counter-signals are real too. Apple keeps investing in Preview (it came to iPad and iPhone in iOS 26). For many people, Preview plus a Quick Look add-on plus their editor is enough. Most single-format Mac viewers on Show HN get under 10 points.

### What to own

1. **An open plugin contract for viewers on Mac.** It exists on Windows (QL-Win) but not on Mac. Quick Look's extension point is a read-only preview pane, and Apple has broken it before (Sequoia dropped `.qlgenerator` plugins).
2. **One default app for the loose files developers open all day:** Markdown, text, logs, JSON, CSV and PDF, all in one native, notarized, open-source app.
3. **Annotations you can trust.** Go after Preview's loudest complaint, losing annotations, rather than PDF Expert's feature list.
4. **Painless plugin distribution.** Glance and MacDown were pulled from Homebrew over notarization. A signed host that installs plugins itself removes that problem for authors.

Early on, plugin authors are the users who matter most. Design and document the plugin contract before adding more formats.

## 2. Platform constraints (blocker check)

| Constraint | Impact | What to do |
|---|---|---|
| Homebrew disables casks that fail Gatekeeper (2026-09-01); `--no-quarantine` is deprecated | Unsigned builds can't ship through the official cask | Pay for the Apple Developer Program (99 USD/yr). Start in your own tap, since the official cask list needs proof of notability. |
| macOS 26.4+ prompts on every change of default app | You can't silently become the PDF handler | Ask once per type from onboarding with `NSWorkspace.setDefaultApplication`, and handle "Keep". |
| Hardened runtime library validation | The app can't load native plugins from other developers without `disable-library-validation`, which Apple says triggers extra Gatekeeper checks | Keep third-party code out of process (section 4 has the measured behavior). |
| PDFKit has no redaction, plus scattered regressions on 26.x | Fine for viewing and annotating, not for true redaction | PDFKit for v1. Add PDFium (permissive license) only when redaction or fidelity gaps bite. MuPDF is AGPL. |
| Foundation's Markdown parser has no task lists, no HTML and no source ranges | Ticking a checkbox can't map back to the source reliably | Use apple/swift-markdown (cmark-gfm, with source ranges) in the real plugin. The POC works around it by counting checkboxes. |
| "Preview" in the name | Not on Apple's trademark list, but Apple's guidelines bar takeoffs of its product names, and the name would be easy to confuse with Preview and hard to search for | Pick a distinct name before launch. Treat "Preview++" as a codename. |

## 3. Plugin models compared

The research compared six models; the POC built the four that matter for Mac.

| Model | Crash isolation | Native UI | Large data | Author barrier | Signing | Verdict |
|---|---|---|---|---|---|---|
| Compiled into app (Swift) | none | full | best | Swift, same repo | none | **First-party plugins** |
| Native bundle loaded at runtime | none | full | best | Swift + matching SDK | other developers need `disable-library-validation` | Not for community code |
| External process + host-rendered UI description | yes | native, limited to the components the host defines | JSON transfer cost; needs paging | any language | none for scripts | **Community plugins, primary** |
| Web view (HTML/JS) | yes, crashes and hangs | web look | DOM cost; needs virtualization | lowest (web stack) | none | **Community plugins, and the content surface for process plugins** |
| ExtensionKit | yes | remote SwiftUI | via bookmarks | highest: wrapper app, sandbox, user approval | per author | Not built; revisit if Apple documents it better |
| JavaScriptCore / WASM | partial / traps | only what the host exposes | OK | medium | JIT entitlement | Rejected: Raycast left JSC over npm access; the WASM UI story is unsolved (Zed still can't add panels) |

Prior art agrees: every large plugin ecosystem (VS Code, Raycast, LSP) runs third-party code out of process, and every in-process one (Obsidian, QL-Win, Sketch) accepted weak isolation in exchange for simplicity.

### Working Mac plugin systems to copy from

Two native Mac apps already run community plugins with host-drawn native UI. They use the same UI model and make opposite runtime bets, which makes them the most useful prior art here.

| | [Raycast](https://www.raycast.com/blog/how-raycast-api-extensions-work) | [Tinycast](https://github.com/abue-ammar/tinycast/blob/main/docs/features/extensions.md) (AGPL-3.0, 8.9k stars) |
|---|---|---|
| Plugin format | TypeScript + React, `package.json` manifest, commands declared as `view` or `no-view` | Runs unmodified Raycast extensions (the prebuilt CommonJS bundles) |
| Where code runs | Separate, host-managed Node process, with each extension in its own worker thread and a per-extension memory limit | Inside the app, in JavaScriptCore on a private serial queue, so extension code never runs on the main thread |
| Bridge | JSON-RPC over stdio. Extensions can only send registered messages (`render`, `setClipboard`, ...). Session ids map references across processes | A ~200 KB generated JS runtime: React 19 + `react-reconciler` + an `@raycast/api` shim + Node polyfills (`fs`, `child_process`, `crypto`, ...) answered by Swift |
| UI | Custom React reconciler, then a JSON render tree, diffed with JSON Patch (gzipped only above a size threshold), then Swift view models, then custom AppKit views | The same reconciler idea, with the JSON tree rendered in SwiftUI. Callbacks become `{"$fn": "node:prop"}` handles; elements passed as props are re-emitted as `__slot` children |
| Components | List, Grid, Detail (Markdown), Form, ActionPanel with keyboard shortcuts | The same surface |
| Isolation | The Node process can crash without taking Raycast down "most of the time". Per-extension process sandboxing was rejected as too costly | None. Its docs say: "An extension can do anything you can do on your Mac. Install only extensions you trust." Extensions are opt-in, with a consent prompt |
| Trust model | Every store extension is open source and reviewed | Install from a catalog or from GitHub |
| How it went | Started on JavaScriptCore over XPC and moved to Node, because authors wanted npm packages and polyfilling Node had no end | Reached "about 80% of what Raycast extensions use", then **stopped compatibility work** in favor of native Tinycast extensions |

Lessons for Preview++:

- **The declarative native UI model is proven twice on Mac**, in AppKit (Raycast) and in SwiftUI (Tinycast). My POC's process plugin is a tiny version of it. The real contract should borrow their mechanics: JSON Patch diffs, function handles for callbacks, and a small component set. List, Detail and Form map directly onto Preview++ side panels, and ActionPanel maps onto commands.
- **Tinycast confirms Raycast's warning about JavaScriptCore.** Embedding JSC costs nothing in binary size and needs no runtime download, but emulating Node is a treadmill: Tinycast stopped at 80%. If Preview++ plugins are JavaScript, either ship a real runtime as Raycast does, or define a small Preview++ API and don't promise Node or npm.
- **In-process JSC isolates hangs from the main thread but not crashes or memory blowups.** Preview++ plugins handle large files, which is where memory blowups happen, so the out-of-process model still fits better.
- **Neither app truly sandboxes plugins.** Both rely on trust: review plus open source for Raycast, explicit consent for Tinycast. Preview++ should plan the same, a reviewed registry plus a consent step, rather than promise sandboxing it hasn't prototyped.
- **Raycast compatibility is a trap for Preview++.** Raycast's components describe launcher screens, not document viewers. Borrow the shape of the API so Raycast authors feel at home, but don't chase compatibility. Tinycast's own retreat shows how that ends.

## 4. Where plugins live: bundled, split, or external

The POC builds the same plugin sources two ways. `PreviewPP` compiles them into the app; `PreviewPPLean` compiles nothing and loads them as `.pppplugin` bundles from `Contents/PlugIns`. Community plugins load from a folder in any runtime. All numbers are medians of 5 launches after a warm-up.

### Speed: where code is loaded doesn't matter; how data crosses does

Time from the host's open call until the content has drawn:

| File | Compiled in | Bundle (runtime load) | Process | Web |
|---|---|---|---|---|
| small.txt (10 KB) | 53.7 ms | 54.0 ms | | |
| large.log (86 MB) | 71.8 ms | 71.1 ms | | |
| large.pdf (2,000 pages) | 69.2 ms | 69.7 ms | | |
| large.md (844 KB) | 816.9 ms | 846.0 ms | | |
| small.csv (100 rows) | 49.1 ms | 50.1 ms | 55.5 ms | 138.0 ms |
| large.csv (50,000 rows) | 82.2 ms | 82.8 ms | 640.1 ms | 1,059.3 ms |

- **Compiled in vs bundle is a wash.** Loading four extra bundles at launch adds about 2 ms (2.9 ms vs 0.8 ms for discovery). Size on disk is under 1 MB either way.
- **Process plugins pay for serialization, not for the process.** A small file costs 6 ms more than native, Python startup included. 50,000 rows cost 8 times more, because the whole table goes over the pipe as one JSON message. The fix belongs in the protocol: send the row count and let the host ask for rows as they scroll into view, the way `NSTableView` already works.
- **Web plugins pay for WebKit startup and the DOM.** That's about 90 ms extra for a small file. For 50,000 rows the naive full-DOM table took 1 second, and WebKit's helper processes held about 1 GB resident (RSS counts shared pages, so it's an overstatement, but the scale is real). Web plugins have to virtualize long content.

### Isolation (measured)

| Plugin | Action | Host survived? |
|---|---|---|
| CSV compiled in | crash | no, the whole app died |
| CSV bundle | crash | no, the whole app died |
| CSV process | crash (`os._exit`) | yes; the tab showed "plugin process exited", other tabs unaffected |
| CSV web | infinite loop | yes; the app stayed responsive |

### Signing (measured)

A copy of `PreviewPPLean` signed with hardened runtime, run against plugins signed in different ways ([script](bench/signing.sh), [output](bench/results/signing.md)):

| Host | Plugin | Loaded? |
|---|---|---|
| Hardened runtime, project's signing identity | first-party bundle, same Team ID | yes |
| same | community bundle, ad-hoc signed | **no**. dyld refused it: "mapping process and mapped file (non-platform) have different Team IDs" |
| same | process plugin (Python script), with and without a quarantine flag | yes. Library validation doesn't apply to child processes, and Gatekeeper doesn't assess a script run through an interpreter |
| + `disable-library-validation` | ad-hoc community bundle, with and without a quarantine flag | yes, with no Gatekeeper prompt |
| + `disable-library-validation` | unsigned bundle | no: "missing code signature" |

So the only way to load community native code is the entitlement. With it on, any ad-hoc-signed bundle dropped in the plugins folder runs inside the app with the app's permissions, even when quarantined. (I set the quarantine flag by hand, which may not match a real browser download exactly.) Process and web plugins avoid the question entirely.

### Recommendation

| Option | For | Against | Verdict |
|---|---|---|---|
| All bundled (compiled in) | Fastest, simplest, nothing to sign | No community ecosystem | Right for first-party, not enough alone |
| **Split: first-party compiled in, community out of process** | Native speed for core formats; community crashes stay contained; host keeps library validation on | Two plugin paths to maintain (mitigated: same manifest and the same `Viewer` contract on the host side) | **Recommended** |
| All external (bundles) | First-party plugins could update on their own schedule | No speed gain, same crash exposure, and community bundles would still need the entitlement | Not worth it |
| All external (processes) | One path for everything | PDF and text can't be described as a UI tree; you'd rebuild them as process-plus-shared-memory renderers | Not for v1 |

One variant worth keeping open is **curated native plugins**. If the project's CI builds and signs vetted community plugins with the project's own Team ID, library validation passes without the entitlement. That gives selected plugins native speed at the cost of running a build service.

## 5. Speed against Preview and TextEdit

Time from `open -F -a <app> <file>` until the app's first document window is on screen, measured the same way for every app by polling the window list ([harness](bench/winwait.swift)). Median of 5 runs, 3 for large files.

| File | Apple's app | Preview++ |
|---|---|---|
| small.pdf | Preview 375 ms | **268 ms** |
| large.pdf (2,000 pages) | Preview 627 ms | **272 ms** |
| small.txt | TextEdit 269 ms | **247 ms** |
| medium.log (11 MB) | TextEdit 281 ms | **239 ms** |
| large.log (86 MB) | TextEdit 435 ms | **256 ms** |
| small.md | TextEdit 248 ms | **235 ms** |
| large.md (844 KB) | **TextEdit 258 ms** | 1,002 ms |

Preview++ wins every row except large Markdown, and that loss is the renderer: it runs on the main thread before the first draw. TextEdit also shows Markdown as raw text, so those two rows compare a rendered view against plain text. All of this is an unoptimized POC; about 50 ms of each open is fixed window and toolbar setup that hasn't been tuned.

## 6. What the POC is

About 1,600 lines of Swift including tests, plus two sample plugins and the benchmark harness.

- **`PreviewPPKit.framework`** is the contract, built with library evolution so that plugins built with other compilers keep working. A plugin declares a manifest (id, name, UTTypes) and returns a `Viewer`: a content view controller, an optional sidebar, and commands with stable ids and default shortcuts. Web and process plugins are adapted to the same contract by the host.
- **The host** owns windows, native tabs, the "Open With" switcher, the Commands menu, Edit and Find, routing and config. Routing prefers an exact UTType match over a supertype match (Markdown beats plain text for `.md`), and the config file overrides it.
- **Config** is a plain `key = value` dotfile: `disable`, `open.<ext>`, `key.<plugin>.<command>`, `plugins.dir`. I picked this format over TOML or JSON to avoid a dependency and keep it diff-friendly, Ghostty-style.
- **First-party plugins:**
  - Text: TextKit 2, editable, save, wrap toggle.
  - Markdown: rendered view, clickable task checkboxes that write back to the file, source toggle for quick edits.
  - PDF: PDFKit with a thumbnail sidebar, highlight, zoom and save.
  - CSV: native table.
- **Community samples:** `csv-web.pppweb` (HTML/JS; it only sees its own folder and the opened file, with network blocked by CSP) and `csv-proc.pppproc` (Python, newline-delimited JSON, returns a table description).
- **Naming trap:** don't call the contract framework `PluginKit`. Apple ships a private framework with that name, and the test runner crashed when ours shadowed it. Hence `PreviewPPKit`.
- **Tests:** unit tests cover config parsing, shortcut parsing, CSV parsing, Markdown checkbox toggling and routing (`xcodebuild test -scheme PreviewPP`).

What it doesn't do yet: a command palette, a settings UI, side panels from process plugins, plugin install, lazy plugin loading (bundles load at launch, which costs 0.5 ms each, so this can wait), and any sandboxing of process plugins. Process plugins currently run with your full user permissions.

## 7. Next steps

1. **Freeze the plugin contract first.** Version the manifest with an API version. Model the process protocol on Raycast's: JSON-RPC over stdio, a render tree updated with JSON Patch, and Tinycast-style function handles for callbacks. Add paging for large data. Define the declarative component set for chrome (toolbar, commands, side-panel lists and forms), shaped like Raycast's so its authors feel at home. Offer a TypeScript/React SDK on top for authors who want it.
2. **Replace the Markdown renderer.** Use swift-markdown with source ranges, parse off the main thread, and render incrementally. The target is under 100 ms for 1 MB.
3. **Prove the content surface for process plugins.** Let a process plugin hand the host HTML (into a host-owned web view) or pixels through shared memory, so a community PDF or image plugin is possible.
4. **Settle permissions for process plugins.** Either curated and trusted, or launched through a sandbox-inheriting helper. Prototype the helper before promising sandboxing.
5. **Pick a name, get a Developer ID, and ship to a personal Homebrew tap.**
6. **Write the "your first plugin in 15 minutes" guide** before adding formats beyond text, Markdown and PDF.

## Caveats

- One machine, warm launches only. Cold launch after a reboot was not measured.
- Head-to-head numbers measure "first document window on screen" for every app the same way. They don't measure "content painted", because that needs screen-recording permission. Preview++'s own content-ready times are in section 4.
- The 86 MB log opens fast because TextKit 2 lays out only the visible part. I did not measure scrolling to the end or searching. The research suggests a custom virtualized view above roughly 100 MB.
- Some research claims come from blog-level sources (ExtensionKit cross-developer use, the macOS 26.4 prompt behavior). The research files tag each claim with its source type.
