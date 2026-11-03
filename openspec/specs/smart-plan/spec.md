# smart-plan Specification

## Purpose
Fills the open slots of a week in My Week with the user's own recipes, using Apple Intelligence on device when available and a simple rotation otherwise, then lets the user review before saving. Runs in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: Starting a smart plan
The system SHALL offer a "Smart Plan" toolbar button in My Week, disabled when the library has no recipes, that plans the week being shown.

#### Scenario: Open from My Week
- **GIVEN** the library has recipes and My Week shows next week
- **WHEN** the user taps Smart Plan
- **THEN** the Smart Plan sheet opens for next week's seven days

### Requirement: Choosing meals
The system SHALL let the user choose which meals to plan with a toggle per meal (Breakfast, Lunch, Dinner, Snack), with only Dinner on at first. "Plan My Week" is disabled when no meal is selected.

#### Scenario: No meals selected
- **WHEN** the user turns Dinner off and leaves every meal off
- **THEN** "Plan My Week" is disabled

### Requirement: Only empty slots
The system SHALL fill only day-and-meal slots of the week that have no entry yet, with at most one suggestion per slot.

#### Scenario: Existing dinner kept
- **GIVEN** Tuesday already has a dinner entry
- **WHEN** the user plans dinners for the week
- **THEN** no suggestion is made for Tuesday dinner

### Requirement: Candidate recipes
The system SHALL draw suggestions only from recipes that are not ideas, with Up Next recipes first in queue order, and treat a recipe as a favorite when it is marked favorite or rated 4 or more.

#### Scenario: Ideas skipped
- **GIVEN** the library holds an idea "Frozen lasagna" and a recipe "Chili"
- **WHEN** the user runs Smart Plan
- **THEN** no suggestion uses "Frozen lasagna"

### Requirement: Apple Intelligence planning
The system SHALL, when Apple Intelligence is available, ask the on-device model to fill the open slots from up to 60 numbered candidate recipes, and discard any pick that names a recipe or day out of range, an unknown meal, a slot that is not open, or a slot already filled by an earlier pick. If the model fails or returns nothing usable, the rotation is used instead.

#### Scenario: Invalid picks dropped
- **GIVEN** 2 candidate recipes and 3 days with day 3's dinner taken
- **WHEN** the model returns picks including recipe 3, day 9, a lunch slot, a duplicate for day 1 and day 3 dinner
- **THEN** only the valid day 1 and day 2 dinner picks are kept

### Requirement: Customizable model instructions
The system SHALL give the on-device model the "Smart Plan for My Week" instructions, which the user can view and replace in Settings (see apple-intelligence).

#### Scenario: Custom instructions
- **GIVEN** the user replaced the Smart Plan for My Week instructions in Settings
- **WHEN** Smart Plan runs with Apple Intelligence
- **THEN** the model is given the replaced instructions

### Requirement: Rotation fallback
The system SHALL, without Apple Intelligence, fill open slots in day then meal order by cycling through queued recipes, then favorites, then the rest, never using the same recipe twice on one day and leaving a slot empty when no unused recipe remains for that day.

#### Scenario: Queue then favorites
- **GIVEN** recipes Plain, Loved (favorite) and Queued (in Up Next), and three days with day 2's dinner taken
- **WHEN** dinners are planned by rotation
- **THEN** day 1 gets Queued and day 3 gets Loved

#### Scenario: One recipe, two meals
- **GIVEN** a single recipe and one day with lunch and dinner selected
- **WHEN** the rotation runs
- **THEN** only one slot is filled

### Requirement: Availability explanation
The system SHALL explain under "Plan My Week" whether Apple Intelligence will be used, and when it is not available say why and that a rotation of Up Next recipes and favorites is used.

#### Scenario: Not available
- **GIVEN** Apple Intelligence is not available on the device
- **WHEN** the user opens Smart Plan
- **THEN** the footer gives the reason and mentions the rotation

### Requirement: Reviewing suggestions
The system SHALL show suggestions grouped by day with a note saying "Planned with Apple Intelligence" or "Planned from Up Next and favorites", let the user swipe to remove any suggestion, and offer "Try Again" to plan again. When there are no suggestions it shows "Nothing to plan" with a Back button.

#### Scenario: Remove one suggestion
- **WHEN** the user swipes away Wednesday's suggestion
- **THEN** it is not added when the plan is saved

### Requirement: Saving the plan
The system SHALL, on "Add to My Week", add an entry for each remaining suggestion and remove every planned recipe from Up Next.

#### Scenario: Queued recipe planned
- **GIVEN** "Curry" is in Up Next and was suggested for Friday dinner
- **WHEN** the user taps Add to My Week
- **THEN** Friday has a Curry dinner entry and Curry is no longer in Up Next
