# Preview++ market and product fit

Research date: 2026-10-29. GitHub stars, release dates and Homebrew install counts were pulled live on that date (GitHub API, `brew info`, whose analytics mirror formulae.brew.sh). Reddit could not be fetched by my tools, so the demand section leans on Hacker News, Apple Community and GitHub.

## 1. Competitors

"Plugins" means third-party code can add a format or a viewer, not just themes or scripts.

### PDF viewers

| Name | OSS (license) | Price | Formats | Plugin system | Latest release / activity | Stars | Note |
|---|---|---|---|---|---|---|---|
| [Preview](https://en.wikipedia.org/wiki/Preview_(Apple)) (Apple) | No | Bundled | PDF, images | None for third parties | Preview 11 on macOS 26; came to iOS/iPadOS 26 ([MacRumors](https://www.macrumors.com/2025/06/06/ios-26-and-ipados-26-preview-app/)) | n/a | The incumbent. No Markdown or plain text rendering found in any source, including macOS 27 coverage ([search note](https://applemagazine.com/preview-pdf/)). |
| [Skim](https://skim-app.sourceforge.io/) | Yes, BSD ([SourceForge](https://sourceforge.net/projects/skim-app/)) | Free | PDF | No. AppleScript, SyncTeX | 1.7.17 ([site](https://skim-app.sourceforge.io/), [cask](https://formulae.brew.sh/cask/skim)) | n/a (SourceForge) | Active academic PDF reader. 14,123 brew installs/yr. |
| [PDF Expert](https://pdfexpert.com/pricing) | No | Yearly or lifetime; lifetime regular $139.99 ([Macworld, 2026-10-20](https://macworld.com/article/3263057/edit-sign-and-convert-pdfs-on-your-mac-with-pdf-expert-for-79-99.html)) | PDF | No | Active | n/a | Polished paid editor. 4,047 brew installs/yr ([cask](https://formulae.brew.sh/cask/pdf-expert)). |
| [PDFgear](https://www.pdfgear.com/) | No | Free | PDF plus conversion to/from Office, images | No | Active ([App Store](https://apps.apple.com/app/id6469021132)) | n/a | Free editor with AI features. |
| [Highlights](https://apps.apple.com/us/app/highlights-extract-pdf-notes/id1498912833) | No | Free; Pro $29.99 or $4.99/mo | PDF; exports notes to Markdown, HTML | No | 2026.3.1, Oct 19 2026 | n/a | Annotation and note export niche. |
| [Sioyek](https://github.com/ahrm/sioyek) | Yes, GPL-3.0 | Free | PDF (research papers) | Partial: external commands and Python scripts ([site](https://sioyek.info/)) | Stable v2.0.0 2022-12-16; sioyek3-alpha0 2024-09-11; main branch pushed 2026-10-29 | 9,970 | Runs on macOS ([cask](https://formulae.brew.sh/cask/sioyek)), Qt UI. |
| [Zathura](https://github.com/pwmt/zathura) | Yes, Zlib | Free | PDF, DjVu, PostScript, comic books via backends | Yes: format backends as plugins ([tap README](https://github.com/homebrew-zathura/homebrew-zathura)) | Tag 2026.10.23 | 3,380 | Runs on macOS only via an unofficial Homebrew tap. GTK, keyboard driven, page-based documents only. |
| [Okular](https://okular.kde.org/) | Yes (KDE, GPL family; [LICENSES](https://github.com/KDE/okular/tree/master/LICENSES)) | Free | PDF, PS, DjVu, EPUB, XPS, images, TIFF, comics, Markdown, txt ([generators dir](https://github.com/KDE/okular/tree/master/generators)) | Yes: "generator" backends | v26.08.2 | 1,554 (mirror) | macOS only as "untested nightly builds" ([download page](https://okular.kde.org/download/)). |
| [MuPDF viewer](https://mupdf.com/) | Yes, AGPL-3.0 ([repo](https://github.com/ArtifexSoftware/mupdf)) | Free (commercial license available) | PDF, XPS, EPUB, CBZ, images, Markdown input | No | Homebrew 1.28.5 ([formula](https://formulae.brew.sh/formula/mupdf)) | 3,033 | Bare viewer (`mupdf-gl`); really a library. |
| [open-pdf-studio](https://github.com/OpenAEC-Foundation/open-pdf-studio) | Yes (custom) | Free | PDF | No | Created 2026-01-22, pushed 2026-10-29 | 968 | New OSS PDF editor with its own Rust engine. |

### Markdown viewers and editors

| Name | OSS (license) | Price | Formats | Plugin system | Latest release / activity | Stars | Note |
|---|---|---|---|---|---|---|---|
| [MarkEdit](https://github.com/MarkEdit-app/MarkEdit) | Yes, MIT | Free | Markdown | Yes: CSS, JS and CodeMirror extensions with a built-in extension manager | v1.37.0, 2026-10-18 | 5,914 | Native Mac editor with extensions. 17,704 brew installs/yr ([cask](https://formulae.brew.sh/cask/markedit)). |
| [Marked 3](https://markedapp.com/) | No | $2.99/mo or $69.99 one-time | Markdown (preview only) | Partial: custom processors, AppleScript, CLI | Marked 3 is out (no date on page) | n/a | Pairs with any editor. |
| [MacDown](https://github.com/MacDownApp/macdown) | Yes | Free | Markdown | No | v0.7.3, 2020-01-03 | 9,845 | Dead. Cask disabled 2026-09-01 for failing Gatekeeper ([cask](https://formulae.brew.sh/cask/macdown)). |
| [MacDown 3000](https://github.com/schuyler/macdown3000) | Yes | Free | Markdown | No | v3000.0.7, 2026-07-13 | 500 | Revived fork. 6,821 brew installs/yr ([cask](https://formulae.brew.sh/cask/macdown-3000)). |
| [Typora](https://typora.io/) | No | $14.99 | Markdown | No (CSS themes) | 1.14.9 | n/a | 12,107 brew installs/yr ([cask](https://formulae.brew.sh/cask/typora)). |
| [Obsidian](https://obsidian.md/pricing) | No | Free; paid Sync/Publish | Markdown, PDF, images inside a vault | Yes: 9,628 community plugins ([registry](https://github.com/obsidianmd/obsidian-releases/blob/master/community-plugins.json)) | Active | n/a | Plugin prior art, but vault-centric; users call the vault "limiting" for viewing loose files ([HN, 2026-04-16](https://news.ycombinator.com/item?id=47795468)). 203,781 brew installs/yr ([cask](https://formulae.brew.sh/cask/obsidian)). |
| [Markdown Preview (pluk-inc)](https://github.com/pluk-inc/markdown-preview) | Yes, MIT | Free | Markdown | No | v0.0.70, 2026-10-28; repo created 2026-04-28 | 2,682 | Native Swift, macOS 15+, notarized, brew cask. Basically the Preview++ Markdown plugin as a standalone app. |
| [MarkText](https://github.com/marktext/marktext) | Yes, MIT | Free | Markdown | No | v0.23.0, 2026-10-21 | 63,262 | Cross-platform editor. |

### Quick Look extensions (macOS)

| Name | OSS (license) | Price | Formats | Plugin system | Latest release / activity | Stars | Note |
|---|---|---|---|---|---|---|---|
| [QLMarkdown](https://github.com/sbarex/QLMarkdown) | Yes, GPL-3.0 | Free | Markdown | n/a (is an extension) | 1.5.7, 2026-10-02 | 3,699 | 34,116 brew installs/yr ([cask](https://formulae.brew.sh/cask/qlmarkdown)), the clearest demand number in this report. |
| [SourceCodeSyntaxHighlight / Syntax Highlight](https://github.com/sbarex/SourceCodeSyntaxHighlight) | Yes, GPL-3.0 | Free | Source code | n/a | 2.1.32, 2026-09-16 | 4,322 | 7,969 brew installs/yr ([cask](https://formulae.brew.sh/cask/syntax-highlight)). |
| [Glance (chamburr fork)](https://github.com/chamburr/glance) | Yes, MIT | Free | Code, Markdown, notebooks, archives | n/a | v1.6.0, 2026-09-08 | 839 | Not notarized; its cask was deprecated Sept 2026 ([Typefire, 2026-10-10](https://typefire.app/blog/best-quick-look-plugins-mac-2026)). |
| [Peek](https://apps.apple.com/us/app/peek-a-quick-look-extension/id1554235898?mt=12) (Big Z Labs) | No | $7.99 | Markdown, code, PostScript | n/a | 2.6.4, 2022-04-02 | n/a | Stale. Listing says it cannot preview plain text, RTF, HTML, PDF or Office "due to system limitations". |
| [Looq](https://parcse.com/looq) | No | From $10 | Markdown, code, SQLite, archives, app bundles | n/a | Show HN 2026-05-04 ([HN](https://news.ycombinator.com/item?id=48009463)) | n/a | "The capabilities macOS Quick Look should have shipped with." |
| [FluxMarkdown](https://github.com/xykong/flux-markdown) | Yes, GPL-3.0 | Free | Markdown | n/a | Pushed 2026-10-29 | 1,293 | Another Markdown Quick Look extension. |
| [QLStephen](https://github.com/whomwah/qlstephen) | Yes, MIT | Free | Extensionless text files | n/a | Last push 2023-05-20 | 2,842 | Still the go-to for README-style files ([Typefire](https://typefire.app/blog/best-quick-look-plugins-mac-2026)). |

### Universal and plugin-hosting viewers (any OS)

| Name | OSS (license) | Price | Formats | Plugin system | Latest release / activity | Stars | Note |
|---|---|---|---|---|---|---|---|
| [QuickLook (QL-Win)](https://github.com/QL-Win/QuickLook) | Yes, GPL-3.0 | Free | Images, text, PDF, media, archives; more via plugins | Yes: .NET DLL implementing [`IViewer`](https://github.com/QL-Win/QuickLook.Common/blob/master/Plugin/IViewer.cs) (`Priority`, `CanHandle`, `Prepare`, `View`, `Cleanup`), shipped as `.qlplugin`; 53 current plugins ([wiki](https://github.com/QL-Win/QuickLook/wiki/Available-Plugins)) | 4.5.0, 2026-04-14; pushed 2026-10-28 | 25,570 | Windows only. Best prior art for the plugin contract. |
| [Seer](https://1218.io/) | No (GitHub repo is an [issue tracker](https://github.com/ccseer/Seer)) | About $12 to $13 lifetime ([Windows Central](https://windowscentral.com/seer-vs-quicklook-who-wears-crown-best-preview-app), [AlternativeTo](https://alternativeto.net/software/seer/about)) | PDF, images, code, video, archives, Markdown | Yes, details not public | 4.7.10, 2026-10-29 | 497 | Windows only. |
| [PowerToys Peek](https://learn.microsoft.com/en-us/windows/powertoys/peek) | Yes, MIT ([repo](https://github.com/microsoft/PowerToys)) | Free | Images, Office, video, web, Markdown, text, SQLite, code, folders | No third-party API in docs | PowerToys v0.102.3001, 2026-10-27 | 140,201 | Windows only. Docs updated 2026-10-14. |
| [File Viewer Plus](https://fileviewerplus.com/) | No | Paid, 14-day trial | 400+ formats | Not mentioned | Version 6 | n/a | Windows only. |
| [yazi](https://github.com/sxyazi/yazi) | Yes, MIT | Free | Anything a previewer handles | Yes: Lua previewer plugins with `peek`/`seek` and preloaders ([docs](https://yazi-rs.github.io/docs/plugins/overview)) | v26.9.1, 2026-09-01 | 43,099 | Terminal file manager. 99,020 brew installs/yr ([formula](https://formulae.brew.sh/formula/yazi)). |
| [ranger](https://github.com/ranger/ranger) | Yes, GPL-3.0 | Free | Anything `scope.sh` handles | Shell script previews ([scope.sh](https://github.com/ranger/ranger/blob/master/ranger/data/scope.sh)) | Tag v1.9.4 (2024-11-04); pushed 2026-09-09 | 17,442 | Terminal. |
| [Raycast](https://developers.raycast.com/) | App no; extensions MIT ([repo](https://github.com/raycast/extensions)) | Free core | n/a (launcher) | Yes: TypeScript/React/Node extensions with a Store; 3,480 extensions in the repo | Repo pushed 2026-10-29 | 7,820 (extensions repo) | Prior art for a native Mac host with a curated community store. 116,360 brew installs/yr ([cask](https://formulae.brew.sh/cask/raycast)). |

### Closest "one app for every file" on Mac

| Name | OSS (license) | Price | Formats | Plugin system | Latest release / activity | Stars | Note |
|---|---|---|---|---|---|---|---|
| [Glim](https://github.com/glimapp/glim) | Yes, MIT | Free | Markdown, HTML, text, JSON, CSV, YAML, SQLite, code, PDF, images, Office, iWork, EPUB, XMind, media | No; formats are built-in readers ([architecture](https://github.com/glimapp/glim/blob/main/docs/architecture.md)) | v0.2.14, 2026-10-29; repo created 2026-10-09 | 29 | Closest match. Rust (GPUI) UI with Swift/PDFKit/Quick Look bridges, folder workspace with tabs. Not notarized yet. |
| [Telescopo](https://apps.apple.com/us/app/telescopo-universal-viewer/id6747908871?mt=12) | No | Free; $4.99/mo, $29.99/yr, $49.99 Markdown Studio | 70+ formats as of Aug 2025 ([HN](https://news.ycombinator.com/item?id=44975814)) | No | 7.1.3, Sep 8 2026 | n/a | Native Swift/AppKit universal viewer with tabs. Closed and built-in only. |
| [Simple Viewers](https://www.ryanlitalien.com/simple/) | Not stated | Viewers free; $9.99 manager | Text, JSON, Markdown, 3D, YAML, CSV, images, audio | No; separate tiny apps sharing a core | Show HN 2026-02-26 ([HN](https://news.ycombinator.com/item?id=47166806)) | n/a | "One mini-app per format" shipped as separate apps. Validates the mini-app idea. |
| [Open Everything](https://github.com/mhartwellyen-droid/open-everything-macos) | Yes, GPL-3.0 | Free | Whatever Quick Look supports, hex fallback | No | v1.17.0, 2026-09-28 | 0 | Swift wrapper around Quick Look. |

## 2. No-go criterion 1: does an active OSS plugin-based Mac viewer exist?

No. Nothing found is open source, actively maintained, Mac native, and lets third parties add a format with its own UI.

The near misses each fail one test:

- **Glim** is the closest: OSS, active, Mac, multi-format, with a Preview-like reading UX. But formats are compiled-in readers with no plugin contract, the UI is Rust/GPUI rather than SwiftUI/AppKit, and it is 3 weeks old with 29 stars and unsigned builds. It is a direct competitor on "one viewer for everything", not on "plugin host".
- **Zathura** and **Okular** are OSS and plugin based, but their plugins are rendering backends for page-based documents, not mini-apps. On macOS, Zathura needs an unofficial tap and Okular ships only untested nightlies.
- **QL-Win QuickLook** has the plugin model Preview++ wants (and 25k stars), but it is Windows only.
- **MarkEdit**, **Obsidian** and **Raycast** prove Mac users will install community extensions, but none is a general file viewer.
- **Telescopo** covers the universal viewer job on Mac, but it is closed and has no plugins.

The criterion does not trigger.

## 3. Demand signals

**Preview bugs on recent macOS**
- "it shows a blue outline box around the text, but it doesnt allow text selection or highlighting." macOS 26 Preview, 463 "me too", thread closed without a fix. Apple support reportedly said engineers were "investigating an issue when opening a PDF that has two columns of texts." ([Apple Community, 2025-09-18](https://discussions.apple.com/thread/256139925))
- "Preview cannot scroll, is very slow to change windows by clicking on them." Tahoe, 14 "me too". ([Apple Community, 2026-02-13](https://discussions.apple.com/thread/256245123))
- "PDFs saved via Print → Save as PDF no longer allow annotation if the original document has an owner password". ([Apple Community, 2026-01-28](https://discussions.apple.com/thread/256233168))
- Text markup fails over tables since macOS 26. ([Apple Community](https://discussions.apple.com/thread/256210420))
- Tahoe 26.0.1 Preview drops light backgrounds and faint text in Illustrator PDFs. ([Adobe Community](https://community.adobe.com/t5/acrobat-discussions/macos-tahoe-26-0-1-pdfs-from-illustrator-showing-missing-beige-backgrounds-faint-text-in-preview/m-p/15547315))
- "macOS Sequoia Preview app adds random passwords to PDFs upon Saving", a regression of an earlier fix. ([HN, 2024-10-23](https://news.ycombinator.com/item?id=41929248))
- Annotation loss on save is a long-running complaint across versions ([2021](https://discussions.apple.com/thread/253093013), [2024](https://discussions.apple.com/thread/255428351)).

**Markdown has no native home**
- "how can I get [Quick Look] to work for markdown? ... they still don't render with the preview which is a mild annoyance." ([HN, 2026-04-24](https://news.ycombinator.com/item?id=47891519))
- "Is there a good way to view Markdown (*.md) files in quickview?" Answer: install a third-party extension. ([Apple Community, 2025-03-03](https://discussions.apple.com/thread/255993123))
- AI coding agents produce a lot of Markdown to read: "it seems that I spend more time reading markdown than code." ([Marky, HN, 2026-04-16](https://news.ycombinator.com/item?id=47795468), 75 points). Another dev built a viewer because cmd+clicking a plan opened Xcode ([HN, 2026-02-26](https://news.ycombinator.com/item?id=47166806)).
- Supply is flooding in. In 2026 alone, Show HN had at least a dozen native Mac Markdown viewers ([example 1](https://news.ycombinator.com/item?id=49809267), [2](https://news.ycombinator.com/item?id=47210261), [3](https://news.ycombinator.com/item?id=48200226), [4](https://news.ycombinator.com/item?id=47015111), [5](https://news.ycombinator.com/item?id=49932913)), and pluk-inc Markdown Preview reached 2,682 stars in six months.
- Install numbers: QLMarkdown 34,116 per year ([cask](https://formulae.brew.sh/cask/qlmarkdown)), MarkEdit 17,704 ([cask](https://formulae.brew.sh/cask/markedit)), Skim 14,123 ([cask](https://formulae.brew.sh/cask/skim)).

**"One app for all files" interest**
- Telescopo's pitch: "tired of keeping different apps around for different file types. Preview for PDFs, Marked for Markdown, Xcode for code files." ([HN, 2025-08-21](https://news.ycombinator.com/item?id=44975814)). It got 2 points, so interest in the pitch exists but is not proven.
- "Fixing QuickLook" got 240 points and 67 comments, which shows how much people care about the built-in preview path ([HN, 2024-06-25](https://news.ycombinator.com/item?id=40792740)).

**Counter-signals**
- "Preview is the easiest way to sign anything sent as PDF." ([HN, 2026-01-22](https://news.ycombinator.com/item?id=46717548))
- Preview on iPad is praised as "Finally a good native PDF tool" ([AppleInsider forums](https://forums.appleinsider.com/discussion/240647)); Apple is investing in Preview, not dropping it.
- The standard answer to "how do I view Markdown" is a free Quick Look extension (QLMarkdown) plus your editor ([HN, 2026-01-10](https://news.ycombinator.com/item?id=46562612)). For many users, Quick Look plus an editor is enough.
- Typora users say they "don't really need another viewer" ([HN, 2026-04-16](https://news.ycombinator.com/item?id=47800008)).
- Most Mac viewer Show HNs get under 10 points. Single-format viewers are easy to build and hard to get noticed with.
- Apple bugs get fixed over time; one user says 26.3.1 fixed the highlight bug ([Apple Community](https://discussions.apple.com/thread/256139925)).

## 4. Gaps Preview++ could own

1. **An open plugin contract for viewers on Mac.** QL-Win has one on Windows (`CanHandle`/`View`, 53 plugins). On Mac, the only extension point is Quick Look, which is a read-only preview pane that cannot take over system types such as plain text, PDF or HTML ([Peek listing](https://apps.apple.com/us/app/peek-a-quick-look-extension/id1554235898?mt=12)) and loses old plugins when Apple changes APIs ([Sequoia dropped qlgenerators](https://mjtsai.com/blog/2024/11/05/sequoia-no-longer-supports-quicklook-generator-plug-ins)). A host where each format is a full mini-app with its own toolbar, search and settings does not exist.
2. **One default handler for the "loose files" developers open all day.** Markdown, plain text, logs, JSON, CSV and code currently open in Xcode or an editor. The Markdown-viewer flood shows the itch; nobody bundles it with PDF in a native, notarized, OSS app.
3. **Annotation you can trust.** Skim is the OSS answer but looks dated and is PDF only. A PDF plugin that never silently loses annotations and saves standard PDF annotations would target the loudest Preview complaints.
4. **Plugin distribution that does not hurt.** Glance and MacDown were pulled from Homebrew for notarization or Gatekeeper problems ([MacDown cask](https://formulae.brew.sh/cask/macdown), [Typefire](https://typefire.app/blog/best-quick-look-plugins-mac-2026)). A host that ships signed and handles plugin install/update (as Raycast and Obsidian do) removes that friction for plugin authors.
5. **Native feel.** Glim uses GPUI and Obsidian uses a web stack; SwiftUI/AppKit with Liquid Glass on macOS 26 is open ground for a multi-format OSS viewer.

## 5. Verdict: go, but reshape the pitch

The no-go criterion does not trigger: no active, open-source, plugin-based Mac viewer exists. Glim (October 2026) is the one to watch, because it is OSS and multi-format and could add plugins.

Reshape for three reasons:

- **Markdown viewing is now a commodity.** Dozens of native viewers shipped in 2026. Leading with "Preview plus Markdown" puts Preview++ in a crowded field. Lead with "the open, plugin-based viewer for Mac" and treat text, Markdown and PDF as first-party plugins that prove the API.
- **PDF is the hardest part and Preview is good enough for most people.** Ship a solid reader first and leave editing for later; aim annotation at the reliability gap rather than PDF Expert's feature list.
- **Plugin authors are the real users early on.** The project wins if writing a viewer is as easy as QL-Win's `IViewer` or a yazi Lua previewer and installing one is as easy as Raycast. Design and document the plugin contract before adding formats.

Platform notes I came across (not a full blocker review): Quick Look extensions cannot override system types, so Preview++ should be an app and default handler, not just a Quick Look extension. Apple's ExtensionKit `EXHostViewController` "hosts remote views provided by an app extension" on macOS 13+ ([Apple docs](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller)), which may suit out-of-process plugins with their own UI.
