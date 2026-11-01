import AppKit

// A write to a closed pipe, such as stdout after the script that launched the app has exited, must fail rather than
// kill the app.
signal(SIGPIPE, SIG_IGN)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
