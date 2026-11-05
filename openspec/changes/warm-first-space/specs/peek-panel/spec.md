# Spec Delta

## ADDED Requirements

### Requirement: Peeker gets the Peek panel ready after launch

Within two seconds of launch, while the Peek panel key is on and Accessibility is granted, Peeker SHALL make the Peek panel, make its first Accessibility call and, when it may already automate Finder, make its first request to Finder, so the first Space doesn't wait for them. Getting ready SHALL NOT ask for any permission.

#### Scenario: The first press of the day

- **WHEN** Peeker starts at login and, a minute later, the user presses Space on a small Markdown file in Finder
- **THEN** over five such launches, the Peek panel appears in under 60 ms at the median on the benchmark Mac, where it took about 95 ms without getting ready

#### Scenario: Finder automation not granted yet

- **WHEN** Peeker starts for the first time, before the user has allowed it to control Finder
- **THEN** no permission request appears until the user presses Space
