## MODIFIED Requirements

### Requirement: Signatures are never written to disk

The plugin SHALL NOT write a signature anywhere except into the PDF the user places it in. The crash-recovery copy of unsaved edits SHALL hold no signature Peeker placed, not even inside a copy of a deleted page; after a crash the other edits come back, and a signature placed since the last save has to be placed again. The last signature drawn SHALL be kept in memory until Peeker quits, and Sign SHALL offer it alongside drawing a new one.

#### Scenario: Signing two pages

- **WHEN** the user places a signature on page 1, then chooses Sign again
- **THEN** Sign offers the same signature, which can be placed on page 2 without drawing again

#### Scenario: After quitting

- **WHEN** the user quits Peeker and opens it again
- **THEN** Sign has no earlier signature to offer, and no file under the user's folders holds one

#### Scenario: A crash before saving

- **WHEN** the user fills a field and places a signature, and Peeker crashes before they save
- **THEN** the crash-recovery record holds the field's value and no signature, and after relaunch the field comes back without the signature
