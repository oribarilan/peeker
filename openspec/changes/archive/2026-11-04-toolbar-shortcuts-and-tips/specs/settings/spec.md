# Spec Delta

## MODIFIED Requirements

### Requirement: General's sections

The General pane SHALL show, in this order, the Peek panel key, Open at Login, the Default app list, the update controls and Tips.

#### Scenario: Opening General

- **WHEN** the user opens the General pane
- **THEN** it shows the Peek panel section first, then Open at Login, Default app, Updates and Tips

## ADDED Requirements

### Requirement: Appearance turns the shortcut captions on and off

The Appearance pane SHALL have a "Show shortcuts in the toolbar" checkbox bound to `showShortcuts`, on by default. Changing it SHALL apply to every open window at once and rewrite the config file like any other change in Settings.

#### Scenario: Turning captions off

- **WHEN** the user clears "Show shortcuts in the toolbar"
- **THEN** `config.json` has `"showShortcuts": false` and the toolbars lose their key captions

### Requirement: General can show the tips again

The General pane SHALL have a Show Tips Again button, greyed out until at least one tip has been shown. It SHALL forget which tips were shown, so each tool's tip appears again on its next first use.

#### Scenario: Seeing a tip again

- **WHEN** the user has seen Highlight's tip and clicks Show Tips Again
- **THEN** the next Highlight shows its tip
