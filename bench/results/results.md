# Benchmark results

Machine: Apple M6, macOS 27.0.1. Median of 5 runs after one warm-up unless noted.

## Time to content (in-app, direct launch)

| variant | file | plugin | runtime | process start to ready (ms) | open to ready (ms) | discovery (ms) | footprint (MB) |
|---|---|---|---|---|---|---|---|
| bundled | small.txt | text | builtin | 131.4 | 53.7 | 0.8 | 28.5 |
| bundled | medium.log | text | builtin | 132.5 | 56 | 0.8 | 50.6 |
| bundled | large.log | text | builtin | 147.5 | 71.8 | 0.8 | 207.6 |
| bundled | small.md | markdown | builtin | 132.7 | 54.6 | 0.8 | 28.6 |
| bundled | large.md | markdown | builtin | 896.7 | 816.9 | 0.8 | 65.5 |
| bundled | small.pdf | pdf | builtin | 135.8 | 60.2 | 0.8 | 94.1 |
| bundled | large.pdf | pdf | builtin | 143.6 | 69.2 | 0.8 | 80.5 |
| bundled | small.csv | csv | builtin | 124.2 | 49.1 | 0.8 | 34.7 |
| bundled | large.csv | csv | builtin | 157.5 | 82.2 | 0.8 | 51.8 |
| external | small.txt | text | bundle | 132.1 | 54 | 2.9 | 28.6 |
| external | medium.log | text | bundle | 134.5 | 56.6 | 2.9 | 50.7 |
| external | large.log | text | bundle | 149.4 | 71.1 | 2.9 | 207.6 |
| external | small.md | markdown | bundle | 135 | 55 | 3 | 28.6 |
| external | large.md | markdown | bundle | 929.9 | 846 | 3 | 65.5 |
| external | small.pdf | pdf | bundle | 142.9 | 61.1 | 2.9 | 94 |
| external | large.pdf | pdf | bundle | 149.4 | 69.7 | 3.1 | 80.6 |
| external | small.csv | csv | bundle | 129.2 | 50.5 | 3 | 34.8 |
| external | large.csv | csv | bundle | 163.3 | 83.8 | 2.9 | 51.9 |
| split:csv@bundle | small.csv | csv@bundle | bundle | 126.3 | 50.1 | 0.8 | 34.6 |
| split:csv@bundle | large.csv | csv@bundle | bundle | 161.4 | 82.8 | 0.8 | 51.9 |
| split:csv-web | small.csv | csv-web | web | 220.9 | 138 | 0.8 | 32.2 |
| split:csv-web | large.csv | csv-web | web | 1145.2 | 1059.3 | 0.8 | 34 |
| split:csv-proc | small.csv | csv-proc | process | 131.2 | 55.5 | 0.8 | 34.7 |
| split:csv-proc | large.csv | csv-proc | process | 720.5 | 640.1 | 0.8 | 55.5 |
| bundled+textkit1 | large.log | text | builtin | 176.4 | 101.7 | 0.8 | 206.9 |
| bundled+textkit1 | medium.log | text | builtin | 139.9 | 59.4 | 0.8 | 50 |

## Head to head: launch to first document window (LaunchServices `open -F`)

| file | app | window (ms) | runs |
|---|---|---|---|
| small.pdf | Preview | 375.3 | 5 |
| small.pdf | Preview++ | 267.7 | 5 |
| large.pdf | Preview | 627.3 | 3 |
| large.pdf | Preview++ | 271.6 | 3 |
| small.txt | TextEdit | 268.5 | 5 |
| small.txt | Preview++ | 246.6 | 5 |
| medium.log | TextEdit | 281.1 | 5 |
| medium.log | Preview++ | 238.5 | 5 |
| large.log | TextEdit | 434.8 | 3 |
| large.log | Preview++ | 255.8 | 3 |
| small.md | TextEdit | 248.1 | 5 |
| small.md | Preview++ | 235.1 | 5 |
| large.md | TextEdit | 258.0 | 3 |
| large.md | Preview++ | 1002.4 | 3 |

## Memory with large.csv open (RSS, 3 s after launch)

| plugin | host (MB) | helpers (MB) | helper processes |
|---|---|---|---|
| csv | 118.1 | 0.0 | - |
| csv@bundle | 117.8 | 0.0 | - |
| csv-web | 107.8 | 1032.1 | com.apple.WebKit.GPU, com.apple.WebKit.Networking, com.apple.WebKit.WebContent |
| csv-proc | 121.8 | 44.2 | Python |

## Crash and hang isolation

| plugin | command | host survived | detail |
|---|---|---|---|
| csv | simulate-crash | no | host exited with -5 |
| csv@bundle | simulate-crash | no | host exited with -5 |
| csv-proc | simulate-crash | yes | The plugin process exited (status 3). The rest of the app is unaffected. |
| csv-web | simulate-hang | yes | host survived simulate-hang |

## Sizes (MB on disk)

| item | MB |
|---|---|
| PreviewPP.app | 1.3 |
| PreviewPPLean.app | 0.91 |
| PPCSV.pppplugin | 0.1 |
| PPMarkdown.pppplugin | 0.15 |
| PPPDF.pppplugin | 0.07 |
| PPText.pppplugin | 0.08 |
| PreviewPPKit.framework | 0.19 |
