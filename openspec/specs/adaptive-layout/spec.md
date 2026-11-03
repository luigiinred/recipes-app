# adaptive-layout Specification

## Purpose
How the app arranges itself for the space it has on iPhone, iPad and Mac: a tab bar on iPhone, a tab bar built into a sidebar on iPad, a sidebar beside a navigation stack on Mac, grids on wide screens, and recipe pages that put ingredients and steps side by side when there is room. It responds to width, so it also covers iPhone landscape, iPad multitasking, and the unfolded iPhone Duo, whose fold divides two-pane screens.

## Requirements

### Requirement: Tabs on iPhone and iPad
On iPhone and iPad, the system SHALL organize the app into the tabs Recipes, Plan, Groceries and Settings, plus a separate search-role Search tab in compact width. In regular width there is no Search tab; the Recipes home has its own search field instead (see recipe-browsing). Folding or unfolding a Duo keeps the open recipe: a recipe opened from Search moves to the Recipes tab when the Search tab goes away, and a sidebar collection opens in the Recipes tab when the sidebar goes away. On iPad the tab bar is built into a sidebar the user can switch to a tab bar across the top; where the system supports it, iPad starts with the sidebar showing.

#### Scenario: iPhone tabs
- **GIVEN** an iPhone in portrait
- **WHEN** the app opens
- **THEN** the tabs are Recipes, Plan, Groceries, Settings and Search

#### Scenario: iPad tabs
- **GIVEN** an iPad in regular width
- **WHEN** the app opens
- **THEN** a Settings tab is listed with Recipes, Plan and Groceries, and there is no Search tab

### Requirement: Recipes group in the iPad sidebar
In regular width on iPad, the system SHALL show a collapsible "Recipes" group in the sidebar holding All Recipes (the Recipes home), Most Recent, the liked collection, Uncategorized (only when it has recipes) and the top-level categories, each opening that collection or category directly. The group sits below Plan, Groceries and Settings, and its collections and categories are not shown in the top tab bar, which keeps a single Recipes tab.

#### Scenario: Open a category from the sidebar
- **GIVEN** an iPad sidebar listing the category Dessert
- **WHEN** the user selects Dessert
- **THEN** the Dessert category opens as the root of that tab

### Requirement: Add buttons on Plan and Groceries
The system SHALL show an "Add" (+) button at the leading edge of the navigation bar on the Plan tab, and on the Groceries tab in compact width, that starts adding there: on Plan it opens the add sheet for Up Next or for today in My Week (see meal-planning), and on Groceries it focuses the "Add item" field (see groceries). The Add Recipe (+) menu sits at the leading edge on the recipe lists too.

#### Scenario: Add on Groceries
- **GIVEN** an iPhone on the Groceries tab
- **WHEN** the user taps Add in the navigation bar
- **THEN** the Add item field is focused

### Requirement: Recipes tab is one navigation stack
On iPhone and iPad, the system SHALL push the Recipes home, a collection or category, and a recipe onto one navigation stack, so a recipe opened from a collection fills the screen and Back returns to the collection.

#### Scenario: Open a recipe on iPad
- **GIVEN** an iPad showing a category grid
- **WHEN** the user taps a recipe card
- **THEN** the recipe page fills the screen, with Back returning to the category

### Requirement: Grids in regular width
When the width is regular on iPhone or iPad, the system SHALL show the Recipes home's recipes as photo cards at least 300 points wide, and a category as a grid of subcategory tiles followed by its recipes as photo cards at least 300 points wide. In compact width these screens are lists. On Mac a collection is always a grid of photo cards.

#### Scenario: Unfolded canvas shows a grid
- **GIVEN** an unfolded dual-screen canvas with regular width
- **WHEN** the user opens the Recipes tab
- **THEN** the collections and categories show as tiles in a grid

#### Scenario: Grid ignores list style
- **GIVEN** the Recipe list setting is Compact List
- **WHEN** the user opens a collection in regular width
- **THEN** recipes show as photo cards and there is no list/cards toggle

### Requirement: Mac sidebar and detail
On Mac, the system SHALL show a sidebar (at least 190 points wide) beside a navigation stack. The sidebar has an expandable "Recipes" row, expanded by default, holding All Recipes, Most Recent, the liked collection, Uncategorized and the category tree (as expandable groups), with Plan and Groceries as sibling rows. Clicking a row replaces the stack's root; a recipe opened from it fills the rest of the window. A Feeds section exists behind a feature flag that is off.

#### Scenario: Sidebar footer
- **WHEN** the library is stored in iCloud Drive
- **THEN** the bottom of the sidebar shows "Synced with iCloud" beside a gear that opens Settings

#### Scenario: Switching sections resets the stack
- **GIVEN** a recipe is open on Mac
- **WHEN** the user picks Groceries in the sidebar
- **THEN** the detail area shows Groceries with no recipe pushed

### Requirement: Groceries side by side when wide
The system SHALL show Groceries as two lists, To Buy beside Completed, in regular width on iPad and iPhone and always on Mac, and as one combined list in compact width (see groceries).

#### Scenario: iPad groceries
- **GIVEN** an iPad in regular width
- **WHEN** the user opens Groceries
- **THEN** items to buy and completed items are shown side by side

### Requirement: Two-column recipe page
When the recipe page is at least 760 points wide, or on an unfolded iPhone Duo, and the recipe is not an idea, the system SHALL split it into two independently scrolling columns: the video (if any), header, directions and notes on the left (up to 720 points wide), and the photo (if any) above the ingredients in a side pane on the right, 36% of the width but between 320 and 420 points. This keeps the ingredients in view while reading steps.

#### Scenario: Wide recipe page
- **GIVEN** a recipe with a photo shown 1100 points wide
- **WHEN** the user scrolls the directions
- **THEN** the ingredients pane with the photo stays in place on the right

### Requirement: Side-by-side ingredients in one column
When the recipe page is narrower than 760 points, the system SHALL show one scrolling column at most 900 points wide in which ingredients and directions sit side by side when the content area is at least 640 points wide (ingredients take 38% of it, at most 340 points, with a 40-point gap) and are stacked, ingredients first, when it is narrower.

#### Scenario: iPhone portrait stacks
- **GIVEN** an iPhone in portrait
- **WHEN** the user opens a recipe
- **THEN** the ingredients are shown above the directions

### Requirement: Unfolded iPhone Duo
On an unfolded iPhone Duo held like a book, the system SHALL lay out two-pane screens so the fold divides them and nothing sits on the hinge: the recipe page puts the steps left and the photo and ingredients right, grids give each page its own columns, Plan shows Up Next beside My Week instead of a picker, and Groceries puts To Buy and Completed on either page. Opening a recipe while unfolded closes the tab sidebar. Cook mode's unfolded layout is covered by cook-mode.

#### Scenario: Plan unfolded
- **GIVEN** an unfolded iPhone Duo
- **WHEN** the user opens the Plan tab
- **THEN** Up Next is on the left page and My Week on the right, with no Up Next / My Week picker

#### Scenario: Recipe unfolded
- **GIVEN** an unfolded iPhone Duo with the sidebar showing
- **WHEN** the user opens a recipe
- **THEN** the sidebar closes and the steps and ingredients sit on either side of the fold

### Requirement: Settings layout by width
The system SHALL show Settings as a pushed list of pages in compact width and on Mac, and on iPad as a sidebar of pages (320 to 460 points wide) beside the selected page.

#### Scenario: iPhone settings push
- **GIVEN** an iPhone
- **WHEN** the user taps Theme in Settings
- **THEN** the Theme page is pushed onto the Settings stack

### Requirement: Mac window and sheet sizes
On Mac, the system SHALL give sheets minimum sizes so their content fits: the recipe editor at least 560 by 640 points, the Settings window at least 460 by 520, the category "Add to" sheet at least 420 by 480, the Tags sheet at least 380 by 320, and Add to Planner at least 380 by 240.

#### Scenario: Editor sheet size
- **WHEN** the user opens the recipe editor on Mac
- **THEN** the sheet is at least 560 points wide and 640 tall
