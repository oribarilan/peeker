# Naming

Status: decided on 2026-10-30: **Peeker**. It replaced MegaPeek, chosen the day before. "Preview++" was the working name. A trademark search is still pending (see Next steps).

## Decision

Peeker is the user's call. It names the Space-bar preview action in one plain word without borrowing Apple's "Preview", which sidesteps the takeoff gray zone below. Checked on 2026-10-30: no Homebrew formula or cask named `peeker`; no Mac App Store app of that name (the closest are "Color Peeker" and "Post Peeker"); 269 GitHub repos have it in their name, none above 44★, and the most-starred ones are unrelated (the largest is [microsoft/peeker](https://github.com/microsoft/peeker), Roslyn analyzers for .NET).

MegaPeek, the previous pick, merged two favorites from later rounds, MegaView and PeekaView. It was clean on GitHub, Homebrew and the App Store as of 2026-10-29.

## What the name should do

- **Promise:** "Preview on steroids." Everything Preview does, with far more power, formats and control.
- **Style:** clear over clever. Evocative brand names (Raycast, Zed, Obsidian, Ghostty) were the starting reference, but every evocative candidate was rejected in favor of names that say plainly what the app is. The one exception that resonated was the "many tools in one" idea (Swiss army knife), expressed through prefixes like Power and Omni rather than metaphors.
- **Practical:** short enough to say and type, searchable, and not colliding with an active product in the same category.

## Legal notes (not legal advice)

The app ships through Homebrew and a DMG, so no App Store name review applies. "Preview" and "Quick Look" are not on [Apple's trademark list](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html), but Apple's [guidelines](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html) discourage names that are takeoffs of its product names. That's a gray zone for "…Preview" names, not a ban. A real trademark search on the finalist is still needed.

## Finalists

All three are clean on GitHub, Homebrew and the App Store as of 2026-10-29.

| Name | Flavor | Watch out |
|---|---|---|
| **PowerPreview** | The user's own pick: the "on steroids" feel | "Power" leans Microsoft (PowerToys, Power BI); one small GitHub repo, [Ericvf/PowerPreview](https://github.com/Ericvf/PowerPreview) (Windows preview handlers, 11★) |
| **OmniPreview** | "Everything", the many-tools idea | Could read as an Omni Group app (OmniFocus) |
| **UltraPreview** | The maximum | Cleanest of all: nothing found anywhere |

Other clean options: AnyPreview, UltraLook, OmniLook, MaxPreview, Lookbox.

## Rejected, and why

| Name | Reason |
|---|---|
| HyperView | [Altair HyperView®](https://altairengineering.fr/hyperview) is a registered trademark in visualization software; [Instawork/hyperview](https://github.com/Instawork/hyperview) has 1.7k★ |
| Peek | Saturated in the exact category: [PowerToys Peek](https://learn.microsoft.com/en-us/windows/powertoys/peek) (Microsoft's Space-bar previewer), [Peek: A Quick Look Extension](https://apps.apple.com/us/app/peek-a-quick-look-extension/id1554235898?mt=12) (paid, closed source, dormant since April 2022, can't preview PDF or plain text), [phw/peek](https://github.com/phw/peek) (10.5k★), ~8,700 repos. Peek-based compounds weren't explored yet |
| PolyView | iPhone app of that name, a discontinued Windows image viewer, 56 repos; "poly" reads as polygons/3D |
| OpenPreview | Existing Mac App Store app plus a 34★ repo |
| PeekPro, Multiview, Allview, Everview, PowerLook | Crowded (several apps or many repos) |
| SuperPreview | Microsoft once shipped Expression Web SuperPreview (from memory, unverified) |
| Facet, Unfold, Glint, Tang, Gimlet, Argus | Evocative direction; the user preferred clear names |
| Preview++ | A takeoff of Apple's product name, and the "++" is unsearchable |

## Later rounds

**Names ending in "View".** None was fully free. Cleanest: KeenView (nothing found), MegaView (14 tiny repos, one iOS app), PeekaView (5 tiny repos, iOS "Peek-a-View"), LookView, PanView. Crowded: OmniView (139 repos, 5 iOS apps; Belkin's KVM line, from memory), UltraView (alibaba/UltraViewPager 4.9k★, iOS app, close to UltraViewer), MaxView, PrimeView. Avoid: PowerView (powerview.py security tool, 1k★), OpenView (existing Mac app, a Quick Look repo, HP OpenView), PeekView (Mac photo browser), OneView (HP).

**Funny names.** Clean: MegaPeek, SwoleView, BeefyView, Peekosaurus, Peekzilla, Peekatron, Lookatron, Roidview. Nearly clean: PeekaBoost, Glancelot. Risky: Peekasso (Picasso estate), Peekachoo (Pikachu), the "-zilla" names (Toho has challenged them, from memory). Avoid: Gander (an existing Mac app, "Gander: Quick Look Preview"), Lookie, Peeksy.

## Next steps

1. Run a trademark registry search (USPTO, EUIPO) on Peeker.
2. Create the GitHub repository under the new name and push (the local repo has no remote yet).

The app, bundle ID (`dev.peeker`), config path (`~/.config/peeker`) and current docs were renamed on 2026-10-30. Dated records (REPORT.md, research/, the plugin decision brief, the foundation spec and plan) keep the old name.

Checks used `gh api search/repositories`, `brew search`, and the iTunes Search API (Mac and iOS stores).
