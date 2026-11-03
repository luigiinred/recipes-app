# app-settings Specification

## Purpose
The app's Settings on iPhone, iPad and Mac: pages of preferences for recipes, the planner, cooking, groceries, reminders, theme, Mealie, Apple Intelligence and data, plus Developer Tools and links for support, feedback and the welcome tour. Preferences are stored on the device in user defaults.

## Requirements

### Requirement: Where Settings opens
The system SHALL open Settings from a Settings tab on iPhone (pages pushed onto a stack) and on iPad (pages in a sidebar beside the selected page, opening on Recipes), and on Mac from the app's Settings window (⌘,) or the gear at the bottom of the sidebar. Settings applies the chosen theme itself, so theme changes show immediately.

#### Scenario: iPad settings tab
- **GIVEN** an iPad in regular width
- **WHEN** the user selects the Settings tab
- **THEN** the page list appears beside the Recipes settings page

### Requirement: Settings pages
The system SHALL list these pages: Recipes, Planner, Cooking, Groceries, Reminders; Theme; Mealie (under "Sync"); Apple Intelligence; and Data & Developer. Below them it shows a Feedback section with Report a Bug and Suggest a Change (see app-feedback), Show Welcome Tour (replays the tour; see onboarding), and a Source Code link to https://github.com/luigiinred/recipes-app.

#### Scenario: Replay the tour
- **WHEN** the user taps Show Welcome Tour
- **THEN** the welcome tour opens (full screen on iPhone and iPad, as a sheet on Mac)

### Requirement: Help Support Us section
The system SHALL show a "Help Support Us" section with Leave a Review (the App Store write-review page) and Tell a Friend Who Cooks (shares the App Store listing with a message) only when the app has an App Store ID configured, and hide it otherwise.

#### Scenario: No App Store ID
- **GIVEN** no App Store ID is configured
- **WHEN** the user opens Settings
- **THEN** the Help Support Us section is not shown

### Requirement: Recipes page
The system SHALL offer on the Recipes page: "Recipe list" (Photo Cards or Compact List; key `recipeListStyle`), "Mark recipes with" (Favorites or Star Ratings; key `ratingStyle`), "Show Delete" under Swipe actions (key `showDeleteInSwipeActions`), and "Review before saving" under Importing (key `reviewImports`). See recipe-browsing for list style, rating style and swipe actions, and web-import and share-extension for the review step.

#### Scenario: Defaults
- **GIVEN** a fresh install
- **WHEN** the user opens the Recipes page
- **THEN** Recipe list is Compact List, Mark recipes with is Favorites, Show Delete is off and Review before saving is on

### Requirement: Planner page
The system SHALL offer on the Planner page: "Add recipes as" (the default meal, including Automatic, which picks breakfast, lunch, a snack or dinner by time of day; key `defaultMeal`), "Week starts on" (System Default, Sunday, Monday or Saturday; key `weekStart`), and a "Meals to plan" toggle for each meal, stored as a comma-separated list of hidden meals (key `hiddenMeals`). Their effect is described in meal-planning.

#### Scenario: Hide a meal
- **WHEN** the user turns off Snack under Meals to plan
- **THEN** `hiddenMeals` contains the snack meal

### Requirement: Cooking page
The system SHALL offer "Keep the screen awake" for cook mode on the Cooking page, on by default (key `keepAwakeWhileCooking`; see cook-mode).

#### Scenario: Default on
- **GIVEN** the setting has never been changed
- **WHEN** the user opens the Cooking page
- **THEN** Keep the screen awake is on

### Requirement: Groceries and Reminders pages
The system SHALL offer "Sync with Reminders" on the Groceries page, which keeps the grocery list in a "Groceries" list in the Reminders app in both directions, and on the Reminders page the opt-in "Log dinner", "Plan next week" and "Add a recipe" notifications with their day and time, "Turn All Off", and a notice with "Open System Settings" when notifications are blocked. Their behavior is described in reminders.

#### Scenario: Turn All Off disabled
- **GIVEN** no reminder is on
- **WHEN** the user opens the Reminders page
- **THEN** Turn All Off is disabled

### Requirement: Theme page
The system SHALL offer on the Theme page a live preview, an Appearance choice (System, Light, Dark, Pitch Black, Sepia; default System; key `appearance`), a Font choice (Serif, Sans Serif, Rounded, Monospaced; default Serif; key `fontStyle`), and an Accent color (key `accentColorHex`, a six-digit hex) chosen from presets Tomato (DB4738, the default), Orange, Saffron, Basil, Teal, Blueberry, Plum, Rose and Graphite, or a custom color, with "Reset to Tomato" disabled while Tomato is selected.

#### Scenario: Pick an accent preset
- **WHEN** the user taps the Basil swatch
- **THEN** `accentColorHex` becomes 3E8E5A and the swatch shows a checkmark

### Requirement: Theme applies across the app
The system SHALL apply the chosen appearance, font design and accent color to every screen, sheet and full-screen cover. Light and Sepia use a light color scheme, Dark and Pitch Black a dark one, and System follows the device. Dark, Pitch Black and Sepia paint their own page and card colors. The font applies throughout, including navigation titles and tab labels on iPhone and iPad, while text size follows the device. The accent colors buttons, links, highlights and ratings.

#### Scenario: Dark is lighter than Pitch Black
- **WHEN** the user picks Dark
- **THEN** pages are a dark gray rather than the pure black of Pitch Black

#### Scenario: Sepia
- **WHEN** the user picks Sepia
- **THEN** screens show a light color scheme on a warm paper-colored page

### Requirement: Apple Intelligence page
The system SHALL show on the Apple Intelligence page whether each of "Smart Plan for My Week", "Recipes from video captions", "Recipes from meal photos" and "Photos with Image Playground" is "Ready" or "Not available" on this device, and when the model is unavailable, why, and what falls back (see apple-intelligence).

#### Scenario: Unavailable model
- **GIVEN** Apple Intelligence is not available on the device
- **WHEN** the user opens the page
- **THEN** the first three rows read "Not available" and the footer explains why

### Requirement: Customizable model prompts
The system SHALL list under "Prompts" on the Apple Intelligence page each job the on-device model does (meal photo, video captions, web page, splitting steps, grouping ingredients, Smart Plan), marked "Default" or "Custom". Opening one shows its default prompt; "Customize this prompt" opens an editor seeded with it, and "Reset to Default Prompt" restores it. Only the instructions change, not the shape of the model's answer. Keys: `aiPrompt.<job>.custom` and `aiPrompt.<job>.text`.

#### Scenario: Customize a prompt
- **WHEN** the user opens Split a pasted method into steps and turns on Customize this prompt
- **THEN** an editable copy of the default prompt appears and the row on the Apple Intelligence page reads "Custom"

#### Scenario: Empty custom prompt
- **GIVEN** a customized prompt whose text was cleared
- **WHEN** the model runs that job
- **THEN** it uses the default prompt

### Requirement: Data & Developer page
The system SHALL offer on the Data & Developer page: "Tidy imported recipes", which re-saves every recipe not yet in standard form and reports "Cleaned up N recipes." or "Every recipe is already tidy."; "Export all data as JSON", which saves one JSON file named "Recipes Export <date>" holding every recipe, photo and step photo (base64), planned meal, grocery item and feed; and a link to Developer Tools.

#### Scenario: Export
- **WHEN** the user taps Export all data as JSON
- **THEN** a save dialog offers a file named "Recipes Export" followed by the date

### Requirement: Developer Tools
The system SHALL offer in Developer Tools "Add Sample Recipes, Plan and Groceries", which saves seven sample recipes with photos and step photos, a week of planned meals and a grocery list, replacing earlier copies; and "Import from real sites", a list of real recipe pages and YouTube videos that each import through the normal importer straight into the library, plus "Import All".

#### Scenario: Import one source
- **WHEN** the user taps a source in Import from real sites
- **THEN** it shows a spinner, then a checkmark when the recipe is saved, or the error message if the import fails

#### Scenario: Samples are not duplicated
- **GIVEN** the samples were added once
- **WHEN** the user taps Add Sample Recipes, Plan and Groceries again
- **THEN** the library still has one copy of each sample recipe
