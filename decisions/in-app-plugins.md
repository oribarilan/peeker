# In-app plugins

Status: decided on 2026-10-30. Supersedes [plugin-architecture.html](plugin-architecture.html).

## Decision

Plugins are Swift modules compiled into the app, not separate processes. Each plugin (text, Markdown, PDF, image) owns its views and its file reading and writing, and can import only `PeekerKit`, the small shared kit. It can't see the host's internals or another plugin's code, and `scripts/build.sh test` checks that. Users still turn plugins on and off and route file types to them.

## Why

The earlier decision ran every plugin as its own process so a crash could never take the app down. That worked, and the benchmarks showed the process hop was cheap. But a process has no window, so plugins could only describe what to show while the host drew it. Every editing feature then needed a new host view, a protocol message and shared-memory plumbing before a plugin could use it, and the editors on the roadmap (PDF fill and sign, image editing) would each pay that cost.

What the project wanted from "plugins" turned out to be code isolation and a user toggle, not process isolation. Plugins come only from contributions to this repo, so they're reviewed code built with the app, the same as the host.

## What we give up

A crash in plugin code now quits the app. A malformed PDF that crashes PDFKit, or an image that crashes ImageIO, used to fail only its tab. Unsaved edits still come back on the next launch through the recovery copy, which already covered crashes of the app itself.

A plugin stuck in a loop can't be killed. File work runs off the main thread, so the app stays usable and closing the tab drops the result.

## Alternatives

- **Keep processes, with the host drawing.** Safest against crashes, but it makes every editor expensive to build, as above.
- **ExtensionKit, with plugins drawing remote views.** Keeps crash isolation and lets plugins draw, but needs a sandbox and file-access grants, and its open speed was never measured. Ruled out on 2026-10-29.
- **Plugins as folders in the app target.** Simplest, but nothing would stop one plugin from reaching into another.
