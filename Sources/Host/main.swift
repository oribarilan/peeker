import AppKit

Bench.markMain()
// A process plugin that dies mid-write must not take the host down with it.
signal(SIGPIPE, SIG_IGN)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
