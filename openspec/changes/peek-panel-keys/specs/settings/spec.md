## ADDED Requirements

### Requirement: General sets the Peek panel's button keys

The General pane SHALL show an Open key and a Show in Finder key under the Peek panel key, each in a key recorder with a button that leaves it without a key and a Reset button that brings back Command-O or Command-R. The recorders SHALL accept only keys with Command, Option or Control, and SHALL refuse the Peek panel key or the other action's key, saying why. A change SHALL apply at once.

#### Scenario: A new key

- **WHEN** the user records Option-Command-O for Open
- **THEN** that key opens the panel's file and Command-O reaches Finder again

#### Scenario: A bare key

- **WHEN** the user presses O alone while recording the Open key
- **THEN** the recorder refuses it and says to add Command, Option or Control
