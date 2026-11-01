## ADDED Requirements

### Requirement: Peeker's annotations carry the author set in Settings

A highlight, text box or signature Peeker saves SHALL carry the author name set in Settings, and no author while that name is empty, the default. Annotations already in the file SHALL keep their own author.

#### Scenario: No name set

- **WHEN** the author name is empty and the user saves a highlight
- **THEN** the highlight has no author

#### Scenario: A name set

- **WHEN** the author name is "Sam Lee" and the user saves a highlight
- **THEN** the highlight's author is "Sam Lee"

## REMOVED Requirements

### Requirement: Peeker's annotations carry no author

**Reason**: Replaced by "Peeker's annotations carry the author set in Settings", whose empty default keeps this behavior.
**Migration**: None: without a name set, saved annotations still carry no author.
