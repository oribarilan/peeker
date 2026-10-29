# Preview++ platform research

Date: 2026-10-29. Local test machine: macOS 27.0.1, Swift 6.4. Source tags: [official] Apple/Homebrew docs, [primary-ish] vendor repos/blogs, [community] forums, [memory] my own knowledge, unverified this session.

## 1. Becoming the default app

- Declare formats in Info.plist `CFBundleDocumentTypes` with `LSItemContentTypes` and `LSHandlerRank` (Owner / Default / Alternate / None) [memory]. Rank only influences the system's pick when nobody is the user's explicit default. Preview ships as the system PDF handler, so rank alone will not displace it. Markdown is not a system-owned type everywhere, so declare `net.daringfireball.markdown` under `UTImportedTypeDeclarations` (conforming to `public.plain-text`, extension `md`, `markdown`) [memory].
- Programmatic: `NSWorkspace.setDefaultApplication(at:toOpen:completion:)`, macOS 12+. Apple: "If a change requires user consent, the system asks the user for consent asynchronously before invoking the completion handler." [official](https://developer.apple.com/tutorials/data/documentation/appkit/nsworkspace/setdefaultapplication(at:toopen:completion:).md). The scheme variant has the same wording [official](https://developer.apple.com/tutorials/data/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:).md).
- Recent restriction: from macOS 26.4, changing the default app for any file type prompts the user (Use / Keep). Before, only the `http` browser scheme prompted (since 10.13). Apple did not document it; the Finder Get Info "Change All" path does not prompt. Article dated 2026-03-24, updated 03-27, and the author says behavior changed during the beta [community](https://scriptingosx.com/2026/03/macos-26-4-brings-more-default-app-confirmation-prompts/). Design for one prompt per content type and a completion handler that can report "kept".
- `LSSetDefaultRoleHandlerForContentType` is the pre-macOS-12 API [community](https://developer.apple.com/forums/thread/705966). I did not find an Apple deprecation statement or its 26.4 behavior; assume it is gated like the NSWorkspace call (unverified).

## 2. Homebrew cask policy and cost

- Homebrew 5.0.0 (2025-11-12): "Casks without codesigning are deprecated"; "We will disable all Homebrew/homebrew-cask casks that fail Gatekeeper checks in September 2026"; `--no-quarantine` and `--quarantine` deprecated [official](https://brew.sh/2025/11/12/homebrew-5.0.0/). Workbrew summary: developers "must now ensure their apps are signed and notarized" [secondary](https://workbrew.com/blog/what-homebrew-5-0-0-means-for-your-mac-fleet).
- Enforcement happened: GitHub issues report official casks (Flycast, Sioyek, TomatoBar, CopyQ, Alacritty) disabled as of 2026-09-01 [community](https://github.com/flyinghead/flycast/issues/2461), [tracking issue](https://github.com/Homebrew/brew/issues/20755). Unsigned apps now need your own tap.
- Acceptable Casks: artifacts "must pass Homebrew's Gatekeeper checks" and must not need Gatekeeper/SIP bypassed; no numeric notability threshold, but a new app needs "substantial, independently verifiable public interest" or an established maintainer [official](https://docs.brew.sh/Acceptable-Casks). Expect to start in a personal tap, then upstream once notable.
- Gatekeeper: macOS 15 removed Control-click Open for unnotarized apps; users must go to System Settings > Privacy & Security [community](https://www.macrumors.com/2024/08/06/macos-sequoia-gatekeeper-security-change/). I found nothing new for macOS 26 specifically.
- Cost: Developer ID and notarization require the paid Apple Developer Program, 99 USD/year [official](https://developer-mdn.apple.com/support/compare-memberships). Fee waivers only for nonprofits, schools, government.

## 3. Hardened runtime, notarization, plugins

- Library validation (on by default with hardened runtime) only loads libraries signed by Apple or with the same Team ID. `com.apple.security.cs.disable-library-validation` lifts that for plug-ins from other developers. Apple warns "Gatekeeper runs extra security checks on programs that have it disabled." [official](https://developer.apple.com/tutorials/data/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation.md)
- Notarization accepts the entitlement (it is a normal hardened-runtime exception, as shipped by many DAWs and editors) [memory]; no source in this session states otherwise. Developer reports mix up this with plug-ins failing to load for other reasons [community](https://developer.apple.com/forums/thread/119801).
- Unsigned code: on Apple silicon every Mach-O must carry at least an ad-hoc signature; a fully unsigned dylib fails with "mapped file has no cdhash" even with the entitlement [community](https://developer.apple.com/forums/thread/694873). Plugins therefore need `codesign -s -` at minimum.
- Quarantine: a quarantined plugin folder triggers Gatekeeper checks on dlopen of quarantined binaries [community](https://book.hacktricks.xyz/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-gatekeeper). A non-sandboxed host can clear it; a sandboxed one reportedly cannot (one forum report, unverified). Safest: ship first-party plugins inside the notarized app (same Team ID, no entitlement needed) and treat third-party plugins as out-of-process.
- Helper executables from plugins: same rules apply (signed, not quarantined, hardened runtime if spawned from the notarized app is not required but Gatekeeper still assesses quarantined files). Recommend an XPC/helper process per third-party plugin so the host keeps library validation on. No authoritative source found; this is design advice.

## 4. Naming

- "Preview" and "Quick Look" are not on Apple's trademark list; "QuickTime", "QuickType" etc. are [official](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html). Not being listed does not rule out common-law rights, and I am not a lawyer.
- Guidelines bar use of Apple marks or "a variation, phonetic equivalent... takeoff, or abbreviation" in product names; referential use ("for Mac") is allowed if less prominent [official](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html). "Preview++" reads as a takeoff of a generic app name, which is a lower risk than a listed mark, but confusion with the bundled Preview.app and poor search findability are real. Also "Mac" in App Store names has been rejected [community](https://developer.apple.com/forums/thread/97847), irrelevant off-store.
- Rename precedents: App4mac (2011) [community](https://9to5mac.com/2011/06/02/apple-goes-after-app4mac-company-forces-to-change-names/), iPodRip (2009) [community](https://www.smartcompany.com.au/business-advice/20091126-steve-jobs-tells-australian-developer-change-your-app-name/). Both involved listed marks. Found no case of Apple forcing a "Preview"-named app to rename. Check GitHub/Homebrew name clashes and run a USPTO search before launch.

## 5. PDFKit

- Strengths: render, search, selection, outline, thumbnails, annotations (highlight, underline, strikeOut, ink, text, link, widgets), AcroForm widget editing, `PDFDocument.write`. Gaps:
  - No redaction subtype; `.redact` cannot be set [community](https://developer.apple.com/forums/thread/718332). True redaction needs rebuilding page content (rasterize or rewrite content streams) or another engine.
  - Radio-group annotation bug on macOS 26.3: exclusivity logic clears other annotations; workaround add selected one first (FB22167174) [community](https://developer.apple.com/forums/tags/pdfkit).
  - Widget annotations rendered pixelated/rasterized, report on a 27.0 build [community](https://developer.apple.com/forums/thread/847155), annotations outside page bounds mis-render [community](https://developer.apple.com/forums/thread/802744).
  - Preview-on-Tahoe user reports: can't highlight on some PDFs, strike-through broken, owner-password PDFs can't be annotated [community](https://discussions.apple.com/thread/256139925), [2](https://discussions.apple.com/thread/256233168). Skim saw page jump on double-click in 26.2 [community](https://sourceforge.net/p/skim-app/bugs/1593/). Preview-level reports hint at PDFKit regressions but are not proven to be PDFKit.
  - Nothing authoritative found on huge-PDF performance or annotation save fidelity; measure with a 1000+ page PDF.
- Alternatives: PDFium (BSD-3 plus Apache-2 text in LICENSE; which applies is unclear, ask a lawyer) [official](https://pdfium.googlesource.com/pdfium/+/refs/heads/master/LICENSE); MuPDF is AGPL or paid Artifex commercial, so an open-source AGPL app is compatible but it limits others reusing under permissive terms [official](https://mupdf.readthedocs.io/en/1.27.0/license.html); pdf.js is Apache-2.0 but needs WKWebView. Recommendation: PDFKit for view and annotate; add PDFium only if redaction or fidelity gaps bite.

## 6. Large text files

- No authoritative benchmark found for 50-500 MB in NSTextView. Evidence: TextKit 2 viewport layout is non-contiguous by default; reports (iOS 16/17 era) of poor scrolling and high memory with ~1M characters, fixed by falling back to TextKit 1; slowdown worse with no line wrap [community](https://developer.apple.com/forums/thread/729491). Touching `.layoutManager` permanently downgrades the view to TextKit 1.
- CotEditor warns above 100 MB; its notes mention non-contiguous layout workarounds [community](https://coteditor.com/releasenotes/3.2.4.en). BBEdit and Sublime: nothing found in sources; from memory, Sublime uses its own renderer and a piece/rope buffer, BBEdit uses a custom text engine (unverified).
- Recommendation: do not put 500 MB into NSTextStorage. Use `mmap` (`Data(contentsOf:options:.alwaysMapped)`), a line-offset index built in a background pass, and a custom virtualized view (NSView/CoreText drawing only visible lines, or NSTextView over a windowed slice). Use NSTextView only below roughly 10 MB (my guess; benchmark).

## 7. Markdown

Tested locally (macOS 27.0.1, Swift 6.4) with `AttributedString(markdown:, options: .init(interpretedSyntax: .full))`:
- Tables: yes, `PresentationIntent` kinds table / tableHeaderRow / tableRow / tableCell with alignment.
- Task lists: no. `- [ ] todo` comes back as list item with literal text "[ ] todo".
- Inline HTML: not interpreted; `<b>` and `</b>` appear as literal text carrying inline-code-like intent (raw 256).
- Strikethrough: yes. Bare URLs: not linkified. Code blocks: yes with language hint.
- No source ranges back to the original text, so write-back is impossible from this API. SwiftUI `Text` ignores `presentationIntent` [community](https://sitapix.github.io/apple-text/skills/apple-text-markdown).
Options:
- apple/swift-markdown (cmark-gfm underneath): AST with source ranges, tables, task lists, strikethrough. Best fit for edits.
- MarkdownUI is in maintenance mode, new work in Textual (gonzalezreal) [community](https://github.com/gonzalezreal/textual). Renderers only, no source mapping.
- WKWebView + cmark-gfm: best fidelity (HTML, tables, images) but heavier launch and weaker native feel.
Recommendation: swift-markdown to parse, use `SourceRange` of each `ListItem` checkbox to patch the source string on tick, then re-render with your own SwiftUI/AppKit renderer (or HTML via cmark-gfm in WKWebView if HTML blocks matter). Write-back is a text splice at the checkbox range, so no round-trip serializer is needed.

## 8. Quick Look

Based on memory plus a failed doc fetch; verify against Apple docs. A preview extension (`QLPreviewingController`, macOS 10.15+ view-based, `QLPreviewProvider` data-based macOS 12+) is a sandboxed app extension in a separate process with time and memory limits, read-only, no long life. Plugins that render to a view or HTML can be reused if built as a Swift package linked into both the app and the extension; plugins that are third-party out-of-process bundles cannot easily be loaded in the extension. Avoid big-file previews in the extension; give it a head slice (first N KB) for text.

## 9. Launch benchmarking

From memory (not verified this session): Instruments "App Launch" template and `os_signpost` / `OSSignposter` points (`main`, first window, first frame); `log stream --predicate 'subsystem == "..."'` for signpost timestamps; poll `CGWindowListCopyWindowInfo` from an external harness until the app's window appears (works for Preview and TextEdit without source access). Fairness: Preview and TextEdit are system apps with prewarmed shared-cache dependencies, so a first run after reboot or `sudo purge` (cold) differs from relaunch (warm); report both, discard the first run, use 20+ runs, same document, same display, AC power, quit helpers, and note that Preview restores windows (disable via `defaults`/clear saved state to compare equal).

## Open items
- Real behavior of `LSSetDefaultRoleHandlerForContentType` on 26.4+.
- Sandboxed-host quarantine clearing; XPC helper approach needs a spike.
- PDFKit huge-file and save-fidelity numbers; TextKit large-file benchmark.
- BBEdit / Sublime internals.
- Whether Homebrew relaxed anything after 2026-09-01 (only third-party reports seen).
