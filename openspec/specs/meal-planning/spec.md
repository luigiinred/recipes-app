# meal-planning Specification

## Purpose
Lets the user line up recipes to cook soon (Up Next), place recipes and ideas on days and meals (My Week), and jot down ideas: recipes with no ingredients or steps yet. Runs in the app on iPhone, iPad and Mac under the Plan tab or sidebar item.

## Requirements

### Requirement: Plan screen modes
The system SHALL show the Plan screen with a segmented control that switches between "Up Next" and "My Week". On an unfolded iPhone Duo it shows Up Next and My Week side by side, one on each side of the fold, without the segmented control (see adaptive-layout).

#### Scenario: Switching modes
- **WHEN** the user opens Plan and picks "My Week" in the segmented control
- **THEN** the week view replaces the Up Next list

#### Scenario: Unfolded iPhone Duo
- **GIVEN** an unfolded iPhone Duo
- **WHEN** the user opens Plan
- **THEN** Up Next is on one page and My Week on the other

### Requirement: Opening Plan from a link
The system SHALL open Plan when the app is opened with a `recipes://plan` link.

#### Scenario: Plan link
- **WHEN** the app opens `recipes://plan`
- **THEN** the Plan tab (or sidebar item on Mac) is selected

### Requirement: Tab bar Add button on Plan
The system SHALL, on iPhone in a compact width, turn the tab bar's search button into an "Add" button while the Plan tab is selected. Tapping it opens "Add to Up Next" when Up Next is showing, or the add-meal sheet for today when My Week is showing, and stays on the Plan tab.

#### Scenario: Add from the tab bar in My Week
- **GIVEN** the Plan tab shows My Week on an iPhone
- **WHEN** the user taps Add in the tab bar
- **THEN** the add-meal sheet opens for today

### Requirement: Up Next queue order
The system SHALL list Up Next as the recipes whose `wantToCook` is true, ordered by `queuedAt` (falling back to `createdAt`), oldest first. Adding a recipe to Up Next sets `wantToCook` to true and `queuedAt` to now; removing it clears both.

#### Scenario: Newly queued recipe goes last
- **GIVEN** Up Next holds "Soup" and "Tacos"
- **WHEN** the user adds "Curry" to Up Next
- **THEN** "Curry" appears after "Tacos"

### Requirement: Up Next actions
The system SHALL offer on each Up Next row: Plan (pick a day and meal), Made It (log a cook and leave the queue), Cook (disabled when the recipe has no steps) and Remove from Up Next. Plan is a leading swipe, Made It and Remove are trailing swipes, and all four are in the context menu.

#### Scenario: Made It leaves the queue
- **WHEN** the user swipes an Up Next recipe and taps Made It
- **THEN** a timeline entry dated now is added to the recipe
- **AND** the recipe leaves Up Next

### Requirement: Adding to Up Next
The system SHALL let the user add recipes to Up Next from an "Add to Up Next" sheet that lists, with search, only recipes not already queued.

#### Scenario: Picking a recipe
- **WHEN** the user taps Add on the Up Next screen and chooses a recipe
- **THEN** the sheet closes and the recipe is the last item in Up Next

### Requirement: Reordering Up Next
The system SHALL let the user drag to reorder Up Next, persisting the new order by renumbering `queuedAt` on the moved recipes. On iPhone and iPad a "Reorder" icon button appears when the queue holds more than one recipe; it turns into "Done" while reordering, and reordering ends by itself when fewer than two recipes remain.

#### Scenario: Drag to the top
- **GIVEN** Up Next holds A, B, C
- **WHEN** the user drags C to the top
- **THEN** Up Next reads C, A, B after the library reloads

### Requirement: Empty Up Next
The system SHALL show a "Nothing in Up Next" empty state with an "Add Recipes" button when the queue is empty.

#### Scenario: Empty queue
- **GIVEN** no recipe is queued
- **WHEN** the user opens Up Next
- **THEN** the empty state and its Add Recipes button are shown

### Requirement: Meal plan entries
The system SHALL store each planned meal as an entry with `id`, `recipeID` (optional), `title`, `day` as a `YYYY-MM-DD` key, `meal` (one of `breakfast`, `lunch`, `dinner`, `snack`), `createdAt` and `updatedAt`. See library-storage for where entries are kept. Deleting a recipe deletes the entries that point to it.

#### Scenario: Entry for a planned recipe
- **WHEN** the user plans "Chili" for dinner on 2026-10-21
- **THEN** an entry is saved with `recipeID` set to Chili's id, `title` "Chili", `day` "2026-10-21" and `meal` "dinner"

### Requirement: My Week view
The system SHALL show one week of seven days, each a section headed by weekday and date with its entries sorted by meal (breakfast, lunch, dinner, snack) then title, followed by an "Add meal" row. Today's header carries a "Today" badge.

#### Scenario: Day sections
- **WHEN** the user opens My Week
- **THEN** the current week is shown with seven day sections and today's section is badged "Today"

### Requirement: Week navigation and week start
The system SHALL let the user move to the previous or next week with chevron buttons, show a "Today" button when the shown week is not the current one, and start weeks on the day chosen in Settings > Planner > "Week starts on" (system default otherwise).

#### Scenario: Back to this week
- **GIVEN** the user moved two weeks ahead
- **WHEN** they tap Today
- **THEN** the current week is shown and the Today button disappears

### Requirement: Editing planned meals
The system SHALL let the user open a planned meal's recipe by tapping it (when the recipe still exists), change its meal, move it to another day of the shown week, or remove it, from the context menu; Remove is also a trailing swipe. Changes update `updatedAt`.

#### Scenario: Move to another day
- **WHEN** the user long-presses a Monday dinner and picks Move to > Thursday
- **THEN** the entry's `day` becomes that Thursday's key

### Requirement: Adding a meal to a day
The system SHALL open an add-meal sheet for a day that offers a meal picker (preset to the default meal), a searchable recipe list with an "Up Next" / "All Recipes" source picker shown only when Up Next is not empty (Up Next selected first), and a text field for an idea.

#### Scenario: Plan a queued recipe
- **WHEN** the user taps "Add meal" on Friday and picks a recipe from Up Next
- **THEN** an entry is added for Friday at the chosen meal
- **AND** the recipe leaves Up Next

### Requirement: Planning an idea by name
The system SHALL, when the user enters free text in the add-meal sheet, reuse a recipe whose title matches case-insensitively or else save a new idea recipe with that title, and plan it on the day.

#### Scenario: New idea from the planner
- **GIVEN** no recipe is titled "Leftovers"
- **WHEN** the user types "Leftovers" in the add-meal sheet and taps Add
- **THEN** a recipe titled "Leftovers" with no ingredients or steps is saved
- **AND** an entry pointing to it is added for that day

### Requirement: Planning from a recipe
The system SHALL let the user plan any recipe from its Plan action through an "Add to Planner" sheet with a day picker (today by default) and a meal picker (default meal). Planning a queued recipe removes it from Up Next.

#### Scenario: Plan from recipe detail
- **WHEN** the user taps Plan on a recipe, picks tomorrow and Lunch, and taps Add
- **THEN** a lunch entry for tomorrow is added

### Requirement: Default meal
The system SHALL preselect the meal from Settings > Planner > "Add recipes as": Automatic, Breakfast, Lunch, Dinner or Snack. Automatic picks breakfast from 04:00 to 10:59, lunch 11:00 to 14:59, snack 15:00 to 16:59, dinner 17:00 to 21:59, and snack otherwise.

#### Scenario: Automatic in the evening
- **GIVEN** "Add recipes as" is Automatic
- **WHEN** the user opens Add to Planner at 18:30
- **THEN** Dinner is preselected

### Requirement: Ideas
The system SHALL treat a recipe with no ingredients and no steps as an idea; there is no stored flag. The user creates one with "New Idea…" in the recipe list's add menu, entering a title (required) and optional notes. Ideas are labelled "Idea" in the library, their detail shows "Just an idea so far" instead of ingredients and steps, and Cook and Groceries are hidden on them.

#### Scenario: Idea becomes a recipe
- **GIVEN** an idea "Spaghetti"
- **WHEN** the user adds an ingredient to it
- **THEN** it is no longer an idea and shows ingredients and steps like any recipe
