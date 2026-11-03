## MODIFIED Requirements

### Requirement: Settings is a sidebar of panes

The Settings window SHALL show a sidebar of panes and the selected pane beside it. The sidebar SHALL list General, then Appearance, then one pane per plugin in sidebar order (Image, PDF, Markdown, Plain Text), each with the icon its plugin names, then Permissions and Config File. It SHALL open on General the first time, and afterwards on the pane last shown, also after a relaunch. The window SHALL resize but its zoom button SHALL be disabled.

#### Scenario: Opening Settings

- **WHEN** the user opens Settings for the first time
- **THEN** the sidebar lists General, Appearance, Image, PDF, Markdown, Plain Text, Permissions and Config File, and General is selected

#### Scenario: Choosing a pane

- **WHEN** the user clicks Plain Text in the sidebar
- **THEN** the Plain Text pane replaces the General pane beside the sidebar

#### Scenario: Back where it was

- **WHEN** the user shows the PDF pane, closes Settings, quits Peeker and opens Settings again
- **THEN** the PDF pane is selected

#### Scenario: An icon per plugin

- **WHEN** the user opens Settings
- **THEN** Image, PDF, Markdown and Plain Text each show their own icon in the sidebar

## ADDED Requirements

### Requirement: Appearance sets the app's look

The Appearance pane SHALL have an Appearance control with System, Light and Dark, bound to `appearance`. System SHALL follow the Mac's appearance; Light and Dark SHALL hold every Peeker window, Settings and the Peek panel included, in that look. A choice SHALL apply at once and rewrite the config file. While the config file can't be used, the pane's controls SHALL be disabled.

#### Scenario: Dark app on a light Mac

- **WHEN** the Mac is light and the user picks Dark
- **THEN** `config.json` says `"appearance": "dark"`, and Settings and open windows turn dark at once

#### Scenario: Broken config

- **WHEN** `config.json` isn't valid JSON
- **THEN** the Appearance pane's controls are disabled

### Requirement: Appearance sets the text's look

The Appearance pane SHALL have a Text appearance control with Match App, Light and Dark, bound to `textAppearance`. It SHALL pick the light or dark variant of the text theme in Markdown and text files, in windows and the Peek panel, at once. Match App SHALL use the app's appearance. Toolbars, sidebars, notes and the Peek panel's frame SHALL keep the app's appearance.

#### Scenario: Light page in a dark app

- **WHEN** the app is Dark, the theme is Paper and the user picks Light for Text appearance
- **THEN** open Markdown windows show Paper's light background while their toolbar and sidebar stay dark

### Requirement: Appearance shows the themes as cards

The Appearance pane SHALL show the eight text themes as cards in four columns and two rows, in the themes' order. Each card SHALL show a short styled Markdown sample (a heading with its dimmed marker, a link, a code span and a task) in that theme's colors and in the variant Text appearance picks, with its name under it. The chosen card SHALL be marked. Clicking a card SHALL choose that theme at once and write `textTheme`.

#### Scenario: Picking Paper

- **WHEN** the user clicks the Paper card
- **THEN** `config.json` says `"textTheme": "paper"`, the Paper card is marked, and open Markdown and text windows turn Paper's colors

#### Scenario: Cards follow Text appearance

- **WHEN** the user switches Text appearance from Light to Dark
- **THEN** every card redraws in its theme's dark colors

#### Scenario: Cards for VoiceOver

- **WHEN** VoiceOver reads the cards
- **THEN** each reads as a button with its theme's name, and the chosen one as selected

## REMOVED Requirements

### Requirement: General picks the text theme

**Reason**: The theme moves to the Appearance pane, where cards show what each theme looks like.

**Migration**: Pick the theme from the cards in Settings > Appearance; the `textTheme` config key is unchanged.
