# Plugin models for Preview++ (macOS 26+, Swift host, notarized outside the App Store)

Researched 2026-10-29. Legend: **[doc]** Apple/official docs fetched, **[src]** project source or blog by the project, **[blog]** community write-up, **[bg]** background knowledge not re-verified this session (treat as a TODO to test).

## Bottom line

1. **Best fit for community plugins: external process (stdio JSON-RPC) with a declarative UI tree rendered natively by the host (Raycast model), plus an optional WKWebView surface for content that needs HTML.**
2. **Second: WKWebView-hosted plugins** (HTML/JS UI, host-served files over a custom scheme). Lowest author barrier, strong isolation for free, weaker on "feels native" and large-file speed.
3. First-party text/Markdown/PDF stay **compiled into the app** behind the same Swift plugin protocol. Do not use in-process dynamic loading for community code.

Rejected for v1: ExtensionKit (author friction, sandbox, approval UX), JSC (no isolation, JS-only, weak ecosystem), WASM (UI story unsolved, Swift runtimes immature).

---

## a) Native in-process bundles / dylibs

**Loading.** `Bundle(url:).load()` then `principalClass`, or `dlopen`. Plugin conforms to a protocol from a shared framework. Unloading Swift/ObjC code is not practically supported [bg].

**Swift ABI / module stability.** ABI stability (Swift 5.0) means the runtime ships in the OS, so a plugin and host share `libswiftCore` regardless of compiler. That alone does not make *your* types safe. Module stability (5.1) lets modules built with different compilers interoperate, and **requires library evolution** [src: https://www.swift.org/blog/library-evolution/]. For a shared plugin-API framework:
- Build it with `-enable-library-evolution` / `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`; this emits a `.swiftinterface` that plugin authors on other Xcode versions compile against.
- Enabling it later is itself a binary-breaking change, so turn it on from day one. Costs: some performance, non-frozen enums need `@unknown default`, limited allowed API changes (no changing signatures, removing public API).
- Cross-compiler binary compatibility is guaranteed **only on Apple platforms** [src, same link]. Fine here.
- Keep the plugin-API surface small and mostly protocols, structs marked `@frozen` only if truly final, `@objc` protocols are an even more stable fallback [bg].
- Host and plugin must resolve to the **same framework image** (`@rpath` to the host's embedded copy), or type identity and protocol conformance break [bg]. Plugin must not embed its own copy.

**Isolation / crash.** None. Plugin runs with the host's memory, TCC grants and entitlements. A crash or hang takes down every tab. Data races with host main thread are on the author.

**Performance.** Best possible: zero IPC, direct `NSView`/SwiftUI, shared memory, mmap of large files, Metal. Startup is a `dlopen` per plugin, lazy-loadable by file type.

**UI.** Full native (AppKit/SwiftUI/Metal). Most expressive.

**Author experience.** Swift/ObjC only, Xcode required, debugging by attaching to host. High barrier; every author must keep up with the API framework.

**Signing.** Hardened runtime enables **library validation**: loaded code must be Apple-signed or share the host's team ID. Third-party plugins have other team IDs, so the host needs `com.apple.security.cs.disable-library-validation` [doc: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation, page body did not render; semantics from bg and widely documented]. Notarization still accepts that entitlement. Consequences: any dylib dropped in the plugins folder runs with the host's privileges, and the plugin supply chain becomes your security problem. Each plugin should be Developer ID signed and notarized by its author. Quarantine: browser-downloaded plugins carry `com.apple.quarantine`; a host that downloads plugins itself can avoid that, a user-dragged bundle may trigger Gatekeeper checks [bg, test it].

**Maturity/risk.** Mature mechanism (Xcode, many DAWs, Sketch historically). Highest security and stability risk for an open ecosystem.

---

## b) ExtensionKit / app extensions

**Loading.** Host declares an extension point in an `.appextensionpoint` plist in its bundle's `Extensions` folder; extensions set `EXExtensionPointIdentifier`; host enumerates with `AppExtensionIdentity` matching; process launched by the system; UI via `EXHostViewController` showing a view owned by the extension process [blog: https://github.com/insidegui/TextTransformer, https://www.massicotte.org/extensionkit-intro].

**Can third parties ship extensions for another developer's extension point?** Yes in principle. Apple's framework lets third-party apps define custom extension points, and other developers can build extensions for them [blog: https://mjtsai.com/blog/2022/06/28/creating-custom-extension-points-for-mac-apps-with-extensionkit; https://www.massicotte.org/extensionkit-intro]. Constraints:
- The extension **must ship inside a `.app`** (a minimal wrapper app is fine) [Massicotte]. No standalone extension distribution.
- Only metadata is host bundle + extension point ID; API versioning between host and extension is entirely the host's job [Massicotte].
- **Sandbox is mandatory** on macOS; extensions without it will not load [Massicotte]. Cross-boundary file access needs bookmarks over XPC.
- **Disabled by default** when shipped separately from the host; user must enable in System Settings > Login Items & Extensions or via `EXAppExtensionBrowserViewController`; only bundled extensions are auto-approved [doc: https://developer.apple.com/documentation/extensionkit/displaying-the-app-extensions-available-to-your-app.md]. Apple says the browser shows extensions for "all of your app's extension points".
- Apple's docs on defining custom points were historically thin (FB10140097) [blog]. I could not fetch the current EXHostViewController page; verify API details.

**Isolation / crash.** Separate sandboxed process; host survives extension crashes, "largely depends on how hosting is implemented" [blog].

**Performance.** Process launch per extension, XPC per call, remote view with resize lag [Massicotte]. Large files: pass bookmark/URL, not bytes.

**UI.** Native SwiftUI rendered remotely, near-full SwiftUI feature set [Massicotte]. Host cannot introspect the view, so host-owned toolbar, command palette entries, keybindings need an explicit XPC contract.

**Author experience.** Swift + Xcode + a containing app + sandbox + approval step. Debugging via System Settings approval dance is painful [Massicotte]. App Store optional (Developer ID works).

**Signing.** Each extension+wrapper app is separately signed and notarized by its author; no `disable-library-validation` needed on the host since nothing is loaded into the host. That is the main advantage.

**Maturity/risk.** Sparse docs, small ecosystem of hosts, Apple-controlled user flow. Good isolation, worst author and user onboarding of all models.

---

## c) JavaScriptCore in-process

**Loading.** `JSContext` per plugin; host exposes bridged native objects (`JSExport`) or a command API. Same engine as Nova and Sketch [bg/src below].

**Isolation.** Sandboxing is only what you expose; a context cannot touch the OS unless the host bridges it. But same process: infinite loops hang the host unless run on a background queue, memory unbounded, no per-plugin kill [bg].

**Crash.** JS exceptions are contained; native bridge bugs and OOM are not.

**Performance.** No IPC; bridge crossing has marshalling cost. JSC JIT in a hardened-runtime app needs `com.apple.security.cs.allow-jit` or it falls back to the interpreter [bg, verify]. Large files: use ArrayBuffer or host handles, not strings.

**UI.** Only what the host exposes (declarative or imperative bridge to native views). No DOM.

**Author experience.** Plain JS, no npm/Node APIs; Raycast's first attempt on JSC failed because npm packages and OS APIs needed polyfilling [src: https://www.raycast.com/blog/how-raycast-api-extensions-work]. Weak debugging unless you wire Web Inspector.

**Signing.** Plugins are text, so no library validation or notarization issue. 

**Maturity.** Very mature engine; Nova and Sketch ship it.

---

## d) WKWebView plugins

**Loading.** Each plugin gets a `WKWebView` (own `WKWebViewConfiguration`, ideally non-persistent data store) loading from a host scheme handler, e.g. `ppp-plugin://<id>/index.html`. WebContent runs in a separate process managed by WebKit [bg].

**Host bridge.** `WKScriptMessageHandler` (JS to native, structured-clone-ish payloads) and `evaluateJavaScript`/`callAsyncJavaScript` back. Content-world isolation (`WKContentWorld`) separates host-injected scripts from page scripts [bg].

**File access.** `WKURLSchemeHandler` serves bytes for a custom scheme (cannot override http/https/file/data/blob; registered before web view creation) [bg, Apple page body did not render: https://developer.apple.com/documentation/webkit/wkurlschemehandler]. Stream with ranged responses so a 2 GB file never sits in JS memory. Never allow `file://` access.

**Network block.** `WKContentRuleList` with a block-all rule (plus a CSP `default-src 'self' ppp-plugin:`) stops exfiltration [bg]. Needs testing for WebSocket and `fetch` to custom scheme.

**Isolation / crash.** WebContent process is sandboxed; its crash triggers `webViewWebContentProcessDidTerminate`, host reloads that tab only. Good.

**Performance.** One WebContent process spin-up per view (tens of ms, memory heavy, ~tens of MB each) [bg]. Large files need virtualized rendering in JS. IPC cost is JSON-ish serialization on message handler; fine for UI events, bad for bulk data. macOS 26 added SwiftUI-native `WebView`/`WebPage` APIs [bg, verify at https://developer.apple.com/documentation/webkit].

**UI.** Anything the web can do: huge ecosystem (pdf.js, CodeMirror, Monaco, markdown-it). Not native look unless you ship a CSS kit. Host-owned toolbar and panels still need a message contract.

**Author experience.** Best of all: web stack, npm, hot reload, Safari Web Inspector (`isInspectable = true`).

**Signing.** Plugin is just files; no library validation problem. Hash/sign the plugin bundle yourself if you want integrity.

**Maturity.** Very mature. VS Code uses the same idea for webviews (sandboxed iframes) [src: https://code.visualstudio.com/api/extension-guides/webview, not fetched this session].

---

## e) External process (stdio JSON-RPC or XPC), UI as declarative tree or HTML

**Loading.** Host spawns `Process` (or XPC service for first-party helpers) per plugin or per plugin-session, speaks JSON-RPC over stdio. Runtime (Node/Bun/Deno/Python/native binary) can be host-managed. Lazy start on first matching file, kill on idle.

**Isolation.** OS process boundary. Real sandboxing is possible by launching through a small signed helper with `com.apple.security.app-sandbox` + `com.apple.security.inherit` [bg, prototype first]; Raycast considered per-extension sandboxes "too costly" for Node and instead isolates by capability: extensions can only send registered messages (render, setClipboard...), each runs in its own Node worker thread with memory limits [src: https://www.raycast.com/blog/how-raycast-api-extensions-work]. Note Raycast's actual isolation is thread plus message allowlist, not a hard security sandbox: plugin code in Node can still use `fs` and `child_process`. For Preview++ decide whether community plugins are "trusted code" (review + signature) or need an OS sandbox.

**Crash.** Excellent: plugin dies, host shows error in that tab, restarts it.

**Performance.** Process spawn 20-100 ms for Node, near zero for a native binary [bg]. Pass **paths or file descriptors**, and let plugin read/mmap itself; do not ship file bytes over JSON. Raycast diffs render trees with JSON Patch and gzips large trees [Raycast]. For pixel content (PDF page, image) use shared memory (IOSurface/mmap'd file) or a `CALayer`-hosting handoff rather than serializing frames [bg].

**UI.** Two options:
- *Declarative tree*, host renders natively. Raycast: React custom reconciler emits a JSON render tree, diffed with JSON Patch, mapped to AppKit components; they chose AppKit over SwiftUI for crash-rate and performance fears [Raycast]. Pros: native feel, host-owned toolbar/commands/side panels/keybindings are first-class. Cons: limited to the component vocabulary; **a document-viewer canvas (PDF, image) is not expressible as a tree**, so you need a "content surface" escape hatch.
- *HTML*: plugin serves or sends HTML to a host WKWebView (model d with a process behind it).

**Author experience.** Any language that can speak JSON-RPC; TS/React SDK gives Raycast-grade DX [Raycast]. Debug with normal Node tooling. Ecosystem access (npm) was Raycast's reason for leaving JSC [Raycast].

**Signing.** Child processes are not governed by library validation. A host-bundled runtime (Node) is signed with the host's team ID. Plugin JS is data. If a plugin ships a native binary, it must be signed/notarized by its author or be ad-hoc under quarantine rules [bg, test]. No `disable-library-validation` required unless the runtime loads native Node addons (`.node` files are dylibs and **would** trip library validation) [bg, verify].

**Maturity.** The most proven pattern for rich ecosystems: VS Code extension host, Raycast, LSP.

---

## f) WebAssembly

**Runtimes.**
- **WasmKit** (Swift-native, MIT): core MVP implemented, many proposals (threads, multi-memory, tail call, relaxed SIMD); **Component Model only at Phase 1 on `main`**; WASI 0.1 "majority" implemented, no WASI 0.2 mentioned; "reasonably fast" interpreter, no JIT; Apple platforms macOS 15+; min Swift 6.3; community-maintained [src: https://github.com/swiftwasm/WasmKit].
- **wasmtime C API**: full component model and WASI 0.2 [bg]; call from Swift via a C module. JIT (Cranelift) on hardened runtime needs `allow-jit`; an interpreter mode (Pulley) may avoid it [bg, unverified; see open Wasmtime macOS JIT-memory issue thread https://bytecodealliance.github.io/zulip-archive/stream/225357-git-wasmtime/topic/wasmtime.20.2F.20issue.20.2311989.20Support.20mmap.20flag.20MAP_JIT.20for.20MACOS.html]. Binary size adds several MB.
- **Extism**: plugin framework over wasm runtimes with host SDKs; the official host SDK list covers Browser, C, C++, Go, .NET, Node, Python, Rust, Zig and others, **Swift not listed** (you would bind the C runtime yourself) [src: https://extism.org/docs/concepts/host-sdk]. Byte-in/byte-out model suits RPC, not rich types.
- **WIT / component model**: typed interfaces and codegen for Rust/JS/etc. Zed uses it via Wasmtime.

**Isolation / crash.** Best capability-based sandbox of any in-process option: no ambient authority, memory-safe, fuel/epoch limits for hangs, traps instead of crashes. 

**Performance.** Near-native for compute in JIT runtimes, slower under interpreters. Copies across the boundary. Large files: WASI preopens or host-function reads in chunks; linear memory is 4 GB (wasm32) [bg].

**UI.** Unsolved natively. Zed's own post: extensions currently cover language support, themes, snippets, slash commands, with **no way to add UI panels** [src: https://zed.dev/blog/zed-decoded-extensions]. You would still need a declarative tree or a webview on top.

**Author experience.** Rust/Go/C/AssemblyScript/JS-in-wasm; no npm-style ecosystem, large binaries for JS, immature debuggers. Zed chose it explicitly because they wanted extensions in Rust, and only after the component model made typed APIs practical [Zed].

**Signing.** `.wasm` is data; no library validation. Runtime JIT entitlement is the only issue.

**Maturity.** Runtime mature in wasmtime; Swift-side ecosystem and component-model support immature as of this date.

---

## Prior art

| Product | Choice | Why / note | Source |
|---|---|---|---|
| VS Code | Separate Node **extension host** process (local/web/remote kinds); UI in webviews; lazy activation | Keeps extensions from hurting startup or UI thread | https://code.visualstudio.com/api/advanced-topics/extension-host |
| Zed | WASM via **Wasmtime + WIT component model**, versioned API in manifest, async host calls | Wanted Rust extensions; component model gave typed strings/structs; API limited (no UI panels), registry is a Git repo | https://zed.dev/blog/zed-decoded-extensions |
| Raycast | **Node worker threads over stdio JSON-RPC**, React reconciler to JSON tree, JSON Patch diff, AppKit native views | Moved off JSC for npm access; rejected per-process sandbox on cost; AppKit over SwiftUI for stability | https://www.raycast.com/blog/how-raycast-api-extensions-work |
| Tinycast (added later) | Runs unmodified Raycast extensions **in-process in JavaScriptCore** on a private serial queue: generated ~200 KB runtime (React 19 + react-reconciler + `@raycast/api` shim + Node polyfills), JSON render tree rendered in **SwiftUI**, `$fn` callback handles, `__slot` for element props | Zero binary cost and no Node download; stopped at "about 80%" Raycast API coverage and moved to native extensions; no isolation ("An extension can do anything you can do on your Mac") | https://github.com/abue-ammar/tinycast/blob/main/docs/features/extensions.md ; https://github.com/abue-ammar/tinycast/blob/main/docs/not-planned.md |
| Obsidian | In-process JS/TS plugin (`main.js` + `manifest.json`), enabled by user in Community plugins | Simplicity; no security sandbox, docs only warn about vault data safety | https://docs.obsidian.md/Plugins/Getting+started/Build+a+plugin |
| Nova | Extensions in JavaScript on system JavaScriptCore; manifest-declared entitlements (files, subprocess, network, clipboard); heavy work in language-server subprocesses | Native app, JSC for lightweight glue, processes for heavy lifting | https://extensions.panic.com/extensions/ashur/ashur.RunLive/ ; https://github.com/panicinc/icarus ; https://docs.nova.app/extensions/ |
| Sketch | Plugin bundles run JS in **CocoaScript/Mocha on JavaScriptCore**, bridged to ObjC; plus JS API wrapper; native Xcode plugins also possible | Lets plugins call any Cocoa API; bridge is slow-ish; docs flagged stale after 2025.1 | https://developer.sketch.com/plugins/cocoascript |
| Quick Look (macOS) | **App extensions** (`QLPreviewingController` view-based, `QLPreviewProvider` data-based, macOS 12+) inside a containing app; sandboxed | System-owned, isolated; contract is "give me a preview", not an app. Replaced legacy in-process QLGenerator plug-ins. Third-party extensions can silently stop being invoked (iOS 27 report) | https://developer.apple.com/documentation/quicklookui/qlpreviewprovider.md ; https://developer.apple.com/forums/thread/843292 |
| BBEdit / TextMate | Data-driven extension: language modules (SDK), clippings, scripts/text filters (shell, AppleScript, Python...), packages; TextMate bundles are plist+scripts | Powerful because the host exposes verbs and plugins are mostly declarative or external scripts | https://www.barebones.com/support/bbedit/ (BBEdit); TextMate bundle docs not fetched |
| QL-Win QuickLook (Windows) | .NET in-process plugins packaged as `.qlplugin` zip unpacked into the app's plugin folder | Simple; no isolation. Language/interface not confirmed from fetched page; repo has HelloWorld template | https://github.com/QL-Win/QuickLook/wiki/Available-Plugins ; https://github.com/QL-Win/QuickLook |

Pattern: every large ecosystem (VS Code, Raycast, Nova's heavy lifting, LSP) puts third-party logic **out of process**, and every in-process one (Obsidian, QL-Win, Sketch) accepted weak isolation as the price of simplicity.

---

## Comparison at a glance

| | Crash isolation | Security isolation | Startup | Large files | Native UI | Author barrier | Lib-validation issue |
|---|---|---|---|---|---|---|---|
| a) in-proc bundle | none | none | fast | best | full | high (Swift/Xcode) | **yes** (needs entitlement) |
| b) ExtensionKit | yes | sandbox | slow-ish | via bookmarks/XPC | remote SwiftUI | highest (wrapper app, approval) | no |
| c) JSC | partial | API-limited | fast | OK with buffers | host-exposed | medium | no |
| d) WKWebView | yes | good | ~per-view process | needs streaming/virtualizing | web only | low | no |
| e) external process | yes | process (+optional sandbox) | spawn cost | best via paths/mmap | declarative or web | low-medium | no (except native addons) |
| f) WASM | trap | strong capabilities | fast | chunked | none built in | medium | no (JIT entitlement) |

## Ranking for Preview++

1. **External process + declarative native tree (e).** Matches the requirement set: host owns toolbar, commands, side panels, keybindings (all expressible as a manifest plus tree), crashes are per-plugin, no `disable-library-validation`, any language, and Raycast proves the React/JSON-patch path. Pass file paths, never bytes.
2. **WKWebView (d).** Use it both as a standalone plugin type for HTML-native formats and as the "content surface" escape hatch for model (e) plugins. Rich renderers exist off the shelf.

Why not (a) for community: forces `disable-library-validation`, a stable-ABI framework you must maintain forever, and one bad plugin kills all tabs. Keep it for first-party only, **statically linked**, so none of that applies.

## UI-layer recommendation

Three tiers behind one Swift `PluginSurface` protocol:
1. **Chrome is declarative and host-rendered** for all plugins: toolbar items, commands, keybindings, side panels (lists, forms, trees, inspectors) as a versioned JSON schema, AppKit-backed (or SwiftUI if you accept the stability risk Raycast declined).
2. **Content view is one of three surfaces:** (i) native Swift view for bundled plugins (PDF via PDFKit, text, image), (ii) host WKWebView fed by plugin HTML or scheme handler, (iii) later, a host-owned bitmap/tile surface fed by shared memory for out-of-process renderers.
3. Version the schema (Zed records API version in the manifest and instantiates matching bindings [Zed]); reject unknown fields rather than guessing.

## Hybrid: core bundled + community external

- **Bundled plugins** (text, Markdown, PDF, image): Swift modules in the app target, registered at launch, implementing the same `Plugin` protocol and the same manifest format as community plugins, so the host never special-cases them (dogfoods the API). No dlopen, no entitlement.
- **Community plugins:** folder `~/Library/Application Support/PreviewPlusPlus/Plugins/<id>/` with `manifest.json` (id, version, API version, UTIs/extensions, permissions, entry), run as external processes via JSON-RPC over stdio, lazy started on first matching file, idle-killed. Host supplies and signs a runtime (Node or similar) so authors ship only JS. Manifest-declared permissions (read opened file, network, spawn) shown at install, Nova style [Nova]; enforce network off in webview via `WKContentRuleList` + CSP, and consider the sandbox-inheriting helper for hard enforcement.
- **Distribution:** registry as a Git repo of manifests with hashes, install via in-app browser or `brew`/CLI; no code loaded into the host, so no entitlement beyond hardened-runtime defaults (plus JIT only if you ever add JSC or wasmtime JIT).
- **Later:** a WASM tier only if the community wants Rust/Go plugins and you can accept the declarative-UI constraint; revisit when WasmKit's component model leaves Phase 1.

## Open items to verify before committing

- Prototype: ExtensionKit custom point from a non-host-team extension on macOS 26, end to end (declaring, approval, `EXHostViewController` + toolbar integration). Docs gave no official statement on cross-team use; evidence is blog-level.
- Hardened-runtime behaviour of: spawning an unsigned/quarantined plugin binary; Node `.node` addons; `WKWebView` content-rule-list vs WebSocket.
- Whether JSC and wasmtime need `allow-jit` on macOS 26.
- Current Apple pages for `EXHostViewController`, `WKURLSchemeHandler`, `QLPreviewingController` returned only titles to the fetch tool; API facts for those come from background knowledge.
- Obtain TextMate bundle and QL-Win plugin API docs (not fetched).
