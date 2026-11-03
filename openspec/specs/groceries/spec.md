# groceries Specification

## Purpose
Keeps a grocery list the user fills by hand or from a recipe's ingredients, checks off while shopping, and optionally mirrors in both directions with a "Groceries" list in the Reminders app. Runs in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: Grocery items
The system SHALL store each grocery item with `id`, `name`, `quantity` (may be empty), `isChecked`, `recipeID` (optional, the recipe it came from), `reminderID` (optional, the linked Reminders item), `createdAt` and `updatedAt`. See library-storage for where items are kept.

#### Scenario: Item from a recipe
- **WHEN** "2 cloves garlic" is added from a recipe
- **THEN** an item is saved with `quantity` "2 cloves", `name` "garlic", `isChecked` false and `recipeID` set to that recipe

### Requirement: Splitting quantity from name
The system SHALL split ingredient text into a leading quantity (numbers, fractions, ranges such as "1 to 2" or "1-2", and one following unit) and a name, dropping a leading "of" and moving a parenthesized package size into the name. Text with no leading number, or nothing after the quantity, is all name.

#### Scenario: Examples
- **WHEN** the texts "1 1/2 cups flour", "2 tbsp of olive oil", "salt", "2 cups" and "1 (18.25 ounce) package cake mix" are split
- **THEN** they give ("1 1/2 cups", "flour"), ("2 tbsp", "olive oil"), ("", "salt"), ("", "2 cups") and ("1 package", "(18.25 ounce) cake mix")

### Requirement: Adding items by hand
The system SHALL offer an "Add item" field at the top of the to-buy list that, on submit, adds the trimmed text as an item and clears the field. Empty text adds nothing.

#### Scenario: Typed item
- **WHEN** the user types "6 eggs" in Add item and presses return
- **THEN** an unchecked item "eggs" with quantity "6" appears in the list

### Requirement: Tab bar Add button on Groceries
The system SHALL, on iPhone in a compact width, turn the tab bar's search button into an "Add" button while the Groceries tab is selected; tapping it focuses the "Add item" field and stays on Groceries.

#### Scenario: Add from the tab bar
- **GIVEN** the Groceries tab is selected on an iPhone
- **WHEN** the user taps Add in the tab bar
- **THEN** the Add item field is focused for typing

### Requirement: Opening Groceries from a link
The system SHALL open Groceries when the app is opened with a `recipes://groceries` link.

#### Scenario: Groceries link
- **WHEN** the app opens `recipes://groceries`
- **THEN** the Groceries tab (or sidebar item on Mac) is selected

### Requirement: Adding a recipe's ingredients
The system SHALL let the user send a recipe's ingredients to groceries from its Groceries action, using the recipe at its current scale (see ingredient-scaling), in a sheet where every ingredient starts selected and tapping one skips it. The action is disabled for recipes with no ingredients and hidden on ideas.

#### Scenario: Skip one ingredient
- **WHEN** the user opens Groceries on a recipe, taps "salt" to skip it, and taps Add to Groceries
- **THEN** every other ingredient is added and salt is not

### Requirement: No duplicate unchecked items
The system SHALL skip adding an item when an unchecked item with the same name (ignoring case) and the same quantity is already on the list.

#### Scenario: Same recipe twice
- **GIVEN** "2 cups milk" is on the list unchecked
- **WHEN** the user adds "2 cups Milk" again
- **THEN** the list still holds one milk item

### Requirement: Checking off and deleting
The system SHALL toggle an item's checked state when tapped, updating `updatedAt`, and delete an item by swipe or context menu Delete.

#### Scenario: Check off
- **WHEN** the user taps an unchecked item
- **THEN** it moves to Completed

### Requirement: List layout
The system SHALL order items by when they were added, then name. On iPhone it shows one list with the to-buy items and a Completed section that appears only when something is checked. On iPad in a regular width and on Mac it shows To Buy and Completed side by side, with "Nothing to buy" and "Nothing completed" empty states; on an unfolded iPhone Duo the fold divides the two columns (see adaptive-layout).

#### Scenario: iPad board
- **GIVEN** an iPad in regular width
- **WHEN** the user opens Groceries
- **THEN** To Buy and Completed columns are shown next to each other

### Requirement: Clearing the list
The system SHALL offer in the Groceries options menu "Clear Completed", which deletes checked items (disabled when none are checked), and "Clear All", which deletes every item after the user confirms "Clear the whole grocery list?" (disabled when the list is empty).

#### Scenario: Clear All needs confirmation
- **WHEN** the user picks Clear All
- **THEN** a confirmation explains it removes every item, including ones not yet bought
- **AND** nothing is deleted until the user confirms

### Requirement: Reminders sync setting
The system SHALL keep the grocery list in sync with the Reminders app when "Sync with Reminders" is on, which it is by default. The toggle is in Settings > Groceries and in the Groceries options menu. Sync asks for full access to Reminders and does nothing when access is denied or the setting is off.

#### Scenario: Turning sync off
- **WHEN** the user turns Sync with Reminders off
- **THEN** grocery changes are no longer sent to or read from Reminders

### Requirement: The Groceries reminders list
The system SHALL sync with the first editable Reminders list titled "Groceries", creating it in the default Reminders account when none exists. Each item appears as a reminder titled "<quantity> <name>" (or just the name), completed when the item is checked, with a line `recipes-item:<item id in lowercase>` in its notes; other note lines are kept.

#### Scenario: Item mirrored
- **GIVEN** sync is on
- **WHEN** the user adds "500g flour"
- **THEN** a reminder "500g flour" appears in the Groceries list with the item's marker in its notes

### Requirement: Two-way reconciliation
The system SHALL reconcile the two sides repeatedly while the app runs: a new item creates a reminder; a reminder without a marker becomes a new item (title split into quantity and name, completion copied) and gets marked; a marked reminder whose item no longer exists is deleted; a linked item whose reminder no longer exists is deleted; when both exist but differ in title or completion, the side changed more than 2 seconds later wins, otherwise the reminder wins.

#### Scenario: Reminder added in the Reminders app
- **WHEN** the user adds "500g flour" marked done in the Groceries reminders list
- **THEN** a checked item "flour" with quantity "500g" appears in the app

#### Scenario: Checked in Reminders
- **GIVEN** "6 eggs" is synced
- **WHEN** the user completes the reminder in the Reminders app
- **THEN** the item becomes checked in the app

#### Scenario: Deleted in the app
- **GIVEN** a synced item
- **WHEN** the user deletes it in the app
- **THEN** its reminder is deleted from the Groceries list
