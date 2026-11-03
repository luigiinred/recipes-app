# home-screen-widgets Specification

## Purpose
Home Screen and Lock Screen widgets show the meal plan, Up Next, the grocery list and a random recipe from the library at a glance, and open the app at the matching place. They run on iPhone and iPad; the cook timer Live Activity lives in the same extension but is covered by cook-timers.

## Requirements

### Requirement: Widgets offered
On iPhone and iPad, the system SHALL offer four widgets: Meal Plan and Up Next in small, medium, large and Lock Screen rectangular sizes; Groceries in those sizes plus Lock Screen circular; and Random Recipe in small, medium and large Home Screen sizes.

#### Scenario: Widget gallery
- **WHEN** the user adds a widget and picks Recipes in the gallery
- **THEN** Meal Plan, Up Next, Groceries and Random Recipe are offered

### Requirement: Kept in step with the app
The system SHALL keep the widgets' copy of the library current while the app runs, refreshing the widgets whenever the shown meals, queue, groceries, recipe pool or accent color change, and drawing widget accents in the accent color chosen in Settings. Widgets also refresh at midnight, and Random Recipe every six hours.

#### Scenario: Check off groceries
- **GIVEN** the Groceries widget is on the Home Screen
- **WHEN** the user checks off "Milk" in the app
- **THEN** "Milk" disappears from the widget

#### Scenario: New accent
- **WHEN** the user changes the accent color in Settings
- **THEN** the widgets' headers and symbols use the new color

### Requirement: Meal Plan widget
The system SHALL show planned meals ordered by meal within each day, each with its meal's symbol: Today with up to three meals in the small size, Today and Tomorrow side by side in the medium size, five days from Today in the large size, and two of today's meals on the Lock Screen. Extra meals show "+N more" and an empty day "Nothing planned". In medium and large sizes a meal planned from a recipe opens that recipe; any other tap opens Plan.

#### Scenario: Busy day
- **GIVEN** today has breakfast, lunch, dinner and a snack planned
- **WHEN** the small Meal Plan widget is shown
- **THEN** it lists three meals in meal order and "+1 more"

#### Scenario: Tap a recipe in the medium widget
- **GIVEN** tonight's dinner is planned from the recipe "Lemon Pasta"
- **WHEN** the user taps it in the medium Meal Plan widget
- **THEN** the app opens on Lemon Pasta's page

### Requirement: Up Next widget
The system SHALL show the first recipes in the Up Next queue, in queue order: up to three titles in the small size, three rows with photo, title and total time in the medium size, six in the large size with the queue count in the header, and two titles on the Lock Screen. An empty queue shows a prompt to line recipes up ("Nothing lined up" on the Lock Screen). Tapping a row in medium or large opens that recipe; any other tap opens Plan.

#### Scenario: Queue order
- **GIVEN** "First" was queued before "Second", and another recipe is not queued
- **WHEN** the Up Next widget is shown
- **THEN** it lists "First" then "Second" and nothing else

### Requirement: Groceries widget
The system SHALL show the unchecked grocery items, oldest first, as "name · quantity" (or just the name): up to four in the small size, six in two columns in medium and fourteen in large, with "+N more" beyond that and "N to buy" in the header. An empty list reads "Everything is checked off" when items are checked off, otherwise "Nothing to buy". Tapping the widget opens Groceries.

#### Scenario: Only what's left
- **GIVEN** "Flour" added before "Milk 1 L", and "Eggs" checked off
- **WHEN** the Groceries widget is shown
- **THEN** it lists "Flour" then "Milk · 1 L" under "2 to buy"

#### Scenario: Lock Screen
- **GIVEN** three items left to buy
- **THEN** the circular Lock Screen widget shows 3 and the rectangular one reads "3 to buy" above two of the names

#### Scenario: All bought
- **GIVEN** every grocery item is checked off
- **WHEN** the medium Groceries widget is shown
- **THEN** it reads "Everything is checked off"

### Requirement: Random Recipe widget
The system SHALL show one recipe drawn from up to 24 library recipes that are not ideas, preferring recipes with photos, as a full-bleed photo with "Try this", the title and the total time, keeping the same recipe for each six-hour window of the day and changing between windows. Tapping it opens that recipe. With no recipes it reads "Add recipes to see one here".

#### Scenario: Same recipe through the morning
- **GIVEN** a library of twelve recipes
- **WHEN** the widget is shown at 7:00 and again at 11:00 on the same day
- **THEN** both show the same recipe

#### Scenario: Ideas are skipped
- **GIVEN** a library with one recipe and one idea with no ingredients or steps
- **THEN** the Random Recipe widget only ever shows the recipe
