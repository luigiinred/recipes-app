# cooking-timeline Specification

## Purpose
A recipe's timeline records each time it was cooked, with an optional note about how it went. It is stored in the recipe file and viewed and edited in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: Timeline data
The system SHALL store a recipe's timeline as the `timeline` array in the recipe's JSON, each entry having `id` (UUID), `date` and `note` (empty string when there is none). A recipe file without `timeline` reads as an empty timeline. See recipe-format.

#### Scenario: Older recipe file
- **GIVEN** a recipe file `{"title": "Soup"}`
- **WHEN** it is read
- **THEN** its timeline is empty and it has no last-made date

#### Scenario: Round trip
- **GIVEN** a recipe with two timeline entries, one with the note "Needed more salt"
- **WHEN** it is saved and read back
- **THEN** both entries, dates and notes are unchanged

### Requirement: Last made
The system SHALL treat the latest date in a recipe's timeline as the date it was last made.

#### Scenario: Entries out of order
- **GIVEN** a timeline with entries dated 2023 and 2027, the 2027 one first
- **THEN** the recipe's last-made date is the 2027 date

### Requirement: Timeline sheet
The system SHALL open a Timeline sheet from the recipe page's More menu, titled with the recipe's name, listing its entries newest first with the weekday and full date and any note, followed by an "Added <date>" line for when the recipe was created.

#### Scenario: View the timeline
- **GIVEN** a recipe cooked on two days
- **WHEN** the user chooses More > Timeline
- **THEN** both days are listed, the most recent first, above the "Added" line

### Requirement: Logging a time it was made
The system SHALL let the user log an entry from the Timeline sheet's "Made it" section with a date (today by default, no later than today) and an optional note, by tapping Log It; the note is trimmed of surrounding whitespace and the form resets. The Up Next queue's Made It swipe action and menu item log an entry for now with no note.

#### Scenario: Log with a note
- **GIVEN** the Timeline sheet is open
- **WHEN** the user picks yesterday, types " Great with garlic ", and taps Log It
- **THEN** an entry dated yesterday with the note "Great with garlic" appears in the timeline

#### Scenario: Future dates
- **WHEN** the user opens the date picker in the "Made it" section
- **THEN** dates after today cannot be chosen

### Requirement: Cooking takes a recipe out of Up Next
The system SHALL remove a recipe from Up Next whenever a timeline entry is logged for it. See meal-planning.

#### Scenario: Made it from Up Next
- **GIVEN** a recipe in Up Next
- **WHEN** the user swipes it and taps Made It
- **THEN** the recipe leaves Up Next and its timeline gains an entry for today

### Requirement: Deleting an entry
The system SHALL delete a timeline entry when the user swipes it in the Timeline sheet and taps Delete.

#### Scenario: Remove a mistaken entry
- **WHEN** the user swipes an entry and taps Delete
- **THEN** the entry is removed from the recipe's timeline

### Requirement: Timeline kept by other clients and sync
The system SHALL keep a recipe's timeline when the recipe is saved from the web editor, and SHALL keep it in step with a connected Mealie server, where entries appear as the recipe's "Made it" timeline events and set its last-made date. See web-ui and mealie-sync.

#### Scenario: Edit in the web UI
- **GIVEN** a recipe with timeline entries
- **WHEN** it is edited and saved in the web UI
- **THEN** its timeline entries are unchanged
