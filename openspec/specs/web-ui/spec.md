# web-ui Specification

## Purpose
A browser app, served by the self-hosted server (see server-api), for browsing, editing, cooking, planning and shopping from the server's library, and for managing the server's password, access tokens and data. It works on desktop and phone-sized screens.

## Requirements

### Requirement: Setup and sign-in screens
The web UI SHALL ask the server for its session state on load and show the setup page while setup is pending, the sign-in page while signed out, and the library otherwise. The setup page asks for the setup code (pointing to the server log and `.server/setup-code`), a password of at least 8 characters and the password again, and refuses mismatched passwords. Whenever an API call answers `401`, the UI returns to the sign-in page. If the server can't be reached it shows the error with a "Try again" button.

#### Scenario: Mismatched passwords
- **GIVEN** the setup page
- **WHEN** the user enters two different passwords
- **THEN** the page shows "The passwords don't match." without calling the server

#### Scenario: Session lost
- **GIVEN** a signed-in browser
- **WHEN** the password is changed from another browser and this one makes a request
- **THEN** the sign-in page is shown

### Requirement: Navigation
The web UI SHALL route `/recipes` (with optional `/recipes/<id>`, `collection`, `tag` and `q` query parameters), `/recipes/<id>/edit`, `/recipes/<id>/cook`, `/new`, `/import`, `/plan`, `/groceries` and `/settings`; `/` redirects to `/recipes`, and other paths show a not-found message with a link back. A sidebar lists the collections All Recipes, Most Recent, Up Next, Favorites (or Top Rated when star ratings are chosen) and Uncategorized with counts, a nested category tree built from tags, Plan, Groceries with its count of unchecked items, and Settings. On narrow screens a tab bar shows Recipes, Plan, Groceries and Settings.

#### Scenario: Category drill-down
- **GIVEN** recipes tagged `Dessert/Cookies`
- **WHEN** the user picks Dessert in the sidebar
- **THEN** its Cookies subcategory appears beneath it and the list shows recipes in Dessert and its subcategories

### Requirement: Library refresh
The web UI SHALL keep the recipes, meal plan and groceries in memory and reload them from the server on start, every 15 seconds while the page is visible, and when the window regains focus, so edits made by the apps or other clients appear without a reload.

#### Scenario: Edit from another client
- **GIVEN** the recipe list is open
- **WHEN** a recipe is added through the API by another client
- **THEN** it appears in the list within 15 seconds without reloading the page

### Requirement: Recipe list
The recipes page SHALL show the recipes in the chosen collection or category, filtered by a search box, with a count, as a compact list or photo cards (one button toggles between them). Each row shows the photo, title, "Idea" for ideas, total time, first category and the rating or favorite mark. An add menu offers New recipe, New idea and Import from a web page. Empty states offer importing or writing a recipe when the library is empty and say "Try fewer words." when a search matches nothing. Selecting a recipe shows it beside the list.

#### Scenario: Empty library
- **GIVEN** no recipes
- **WHEN** the user opens `/recipes`
- **THEN** the page shows "No recipes yet" with links to import one or write one

### Requirement: Recipe page
The recipe page SHALL show the title, summary, servings, prep and cook time, category chips (each linking to its category), ingredients grouped under their section headings with the amount in bold, numbered steps with their step photos, notes and a link to the source host (only for `http(s)` sources). For a YouTube source it embeds the video from `youtube-nocookie.com` instead of the photo, and steps with a timestamp get a button that plays the video from that time. Actions are rating, Cook, Up Next (toggle), Plan, Groceries, and a menu with Edit, Print and Delete (after confirmation). Ideas (recipes without ingredients or steps) hide Cook and Groceries and invite adding ingredients and steps.

#### Scenario: Adding to groceries
- **WHEN** the user presses Groceries on a recipe
- **THEN** each ingredient is added to the grocery list linked to the recipe, skipping ones already waiting
- **AND** a toast reports how many were added, or "Those are already on your list"

#### Scenario: Planning from the recipe
- **WHEN** the user presses Plan
- **THEN** a dialog offers a date (with Today, Tomorrow and Day after shortcuts) and a meal, and Add to plan creates the planned meal

### Requirement: Ratings follow the browser setting
The web UI SHALL show either a favorite heart or one-to-five stars on recipes depending on the "Rate recipes with" setting, saving the choice to the recipe immediately; pressing the current star rating again clears it.

#### Scenario: Clearing stars
- **GIVEN** star ratings are chosen and a recipe has 4 stars
- **WHEN** the user presses the fourth star
- **THEN** the recipe's rating is cleared

### Requirement: Recipe editor
The editor SHALL edit the title (required), summary, servings, prep and cook minutes, comma-separated categories (with `/` for nesting and suggestions from existing tags), ingredients one per line with `#` lines as section headings, a cover photo, source address, notes, and steps that can be added, reordered, deleted and have their step photo removed. For YouTube recipes each step has a video time field in `m:ss` or `h:mm:ss` form. Saving refuses a missing title, malformed step times and a source that isn't `http://` or `https://`. Chosen photos are scaled to at most 2000 pixels on the longest side and re-encoded as JPEG before upload. Saving keeps the recipe's favorite, rating, queue state, timeline and creation date.

#### Scenario: Ingredient sections
- **WHEN** the user enters `# Dough`, `2 cups flour`, `# Filling`, `1 apple`
- **THEN** the saved recipe has ingredients `2 cups flour` and `1 apple` with sections Dough at 0 and Filling at 1

#### Scenario: Bad step time
- **WHEN** a YouTube recipe's step time is `soon`
- **THEN** saving shows "Step times look like 1:30." and nothing is saved

### Requirement: Import from a web page
The import page SHALL take a page address, ask the server to read it (see server-api), and open the editor titled "Review imported recipe" with the draft and its photo, so nothing is saved until the user saves. It notes that YouTube videos can be imported in the iPhone and Mac apps and offers "Write one instead".

#### Scenario: Reviewing an import
- **WHEN** the user imports a recipe page
- **THEN** the editor opens filled with the page's recipe and photo
- **AND** saving creates the recipe and uploads the photo

### Requirement: New ideas
The web UI SHALL let the user jot down an idea, a recipe with only a title and optional notes, from the recipes page's add menu, and open it after saving.

#### Scenario: Saving an idea
- **WHEN** the user saves the idea "Frozen burgers"
- **THEN** a recipe with that title and no ingredients or steps is created and shown

### Requirement: Cook mode
Cook mode SHALL fill the screen with one page for the ingredients followed by one page per step in large type, with a progress bar, Back and Next (Start cooking on the first page, Done on the last) buttons, and the left and right arrow keys; Escape or the close button leaves it. Durations in a step ("20 to 25 minutes", "1.5 hours") become timer buttons using the upper end of a range; running timers count down in a list, beep when done and can be dismissed. While "Keep the screen awake in cook mode" is on and the browser supports it, the screen is kept awake.

#### Scenario: Timer from a range
- **GIVEN** a step reading "Bake 20 to 25 minutes"
- **WHEN** the user presses its timer button
- **THEN** a 25:00 timer starts counting down

### Requirement: Plan page
The plan page SHALL show the Up Next queue, where recipes can be moved up or down (the new order is saved), planned or removed from the queue, and a seven-day week starting on the chosen weekday, with previous, next and Today buttons. Each day lists its meals in breakfast, lunch, dinner, snack order with buttons to change the day and meal or remove them. Adding a meal picks a recipe by search or takes a typed idea, which is saved as an idea recipe (or reuses a recipe with that exact title) before it is planned.

#### Scenario: Typed idea
- **WHEN** the user adds "Leftovers" to Tuesday as a typed idea
- **THEN** a recipe titled Leftovers is created and planned for Tuesday

#### Scenario: Default meal
- **GIVEN** "Meal for new plans" is "Based on the time of day"
- **WHEN** the user opens the add-meal dialog at 12:00
- **THEN** Lunch is preselected

### Requirement: Groceries page
The groceries page SHALL add typed items (splitting a leading quantity such as "2 cups flour"), saying "That's already on your list" for a duplicate, show unchecked items above a Done section, link items to the recipe they came from, check and uncheck items, remove them, and offer Clear completed and Clear all (after confirmation).

#### Scenario: Checking an item
- **WHEN** the user checks Milk
- **THEN** it moves to the Done section and the change is saved to the server

### Requirement: Browser settings
The settings page SHALL keep per-browser preferences in local storage: "Rate recipes with" (Favorites, default, or Star ratings), "Recipe list" (Compact list, default, or Photo cards), "Week starts on" (Sunday, default, or Monday), "Meal for new plans" (based on the time of day, default, or a fixed meal) and "Keep the screen awake in cook mode" (on by default). It also shows the server version and a Sign out button.

#### Scenario: Monday weeks
- **WHEN** the user chooses Monday for "Week starts on"
- **THEN** the plan page's weeks start on Monday in this browser

### Requirement: Account and data settings
The settings page SHALL show the server's address with a copy button, create named access tokens and show each new token once with a copy button, list tokens with their creation and last-used dates and revoke them after confirmation, change the password (asking for the current password and the new one twice, and reporting that other browsers were signed out), download the whole library as an export file, and restore an export file, reporting how many recipes, planned meals and grocery items were restored.

#### Scenario: New token
- **WHEN** the user creates a token named "Kitchen Mac"
- **THEN** the token value is shown once with "Copy it now. It isn't shown again."
- **AND** the token appears in the list as "never used"
