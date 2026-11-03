# siri-shortcuts Specification

## Purpose
Siri, Shortcuts and Spotlight can save, find, open and cook recipes and add their ingredients to groceries, and `recipes://` links open the app on a recipe or in cook mode. Runs in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: Recipe entity
The system SHALL expose each recipe to Siri and Shortcuts as a Recipe with its title, summary (shown as the subtitle when not empty) and categories (the recipe's tags). Searching recipes by text matches recipes whose title, summary, notes, ingredients and tags contain every word of the query, ignoring case; suggestions are the ten most recently updated recipes. Intents read the same library folder the app uses, so they work whether or not the app is running.

#### Scenario: Find by ingredient words
- **GIVEN** a recipe "Weeknight Chili" with the ingredient "1 can black beans"
- **WHEN** Shortcuts searches recipes for "black beans"
- **THEN** "Weeknight Chili" is among the results

### Requirement: Save Recipe
The system SHALL provide a Save Recipe action that imports a web page or YouTube link (see web-import and youtube-import), saves it to the library and returns the saved recipe. It replies "Saved <title>." or, when the full recipe could not be found, "Saved <title>, but I couldn't find the full recipe. Open Recipes to finish it." followed by the import's message.

#### Scenario: Save from a link
- **WHEN** the user says "Save a recipe in Recipes" and provides a recipe page link
- **THEN** the recipe is added to the library and Siri says "Saved <title>."

### Requirement: Find and open a recipe
The system SHALL provide a Find Recipe action that returns the chosen recipe with the reply "Here's <title>.", and an Open Recipe action that opens the app on that recipe's page.

#### Scenario: Find a recipe
- **WHEN** the user runs Find Recipe for "Tomato Soup"
- **THEN** the action returns that recipe and replies "Here's Tomato Soup."

### Requirement: Start Cooking
The system SHALL provide a Start Cooking action that opens the app in cook mode on the chosen recipe (see cook-mode).

#### Scenario: Start cooking by voice
- **WHEN** the user says "Start cooking Tomato Soup in Recipes"
- **THEN** the app opens in cook mode on Tomato Soup

### Requirement: Add Ingredients to Groceries
The system SHALL provide an Add Ingredients to Groceries action that adds each of the recipe's ingredient lines to the grocery list as written, linked to the recipe, skipping any line whose item name (ignoring case) and quantity already match an unchecked grocery item. It replies "Added <n> items to your groceries." or, when nothing was added, "Those ingredients are already on your list." See groceries.

#### Scenario: Run twice
- **GIVEN** the action already added a recipe's ingredients and none have been checked off
- **WHEN** the user runs it again for the same recipe
- **THEN** nothing is added and the reply is "Those ingredients are already on your list."

### Requirement: App Shortcuts phrases
The system SHALL register these spoken phrases without setup: "Save a recipe in Recipes" and "Save this recipe in Recipes" (Save Recipe), "Find <recipe> in Recipes" and "Find a recipe in Recipes" (Find Recipe), "Start cooking <recipe> in Recipes" (Start Cooking), and "Add <recipe> to my groceries in Recipes" (Add Ingredients to Groceries).

#### Scenario: Shortcuts app
- **WHEN** the user opens the Recipes section of the Shortcuts app
- **THEN** Save Recipe, Find Recipe, Start Cooking and Add to Groceries are listed

### Requirement: Spotlight
The system SHALL index every recipe in the library for Spotlight by title, with its summary as the description and its tags as keywords, re-indexing whenever the set of recipes changes.

#### Scenario: Search from the Home Screen
- **GIVEN** a recipe "Lemon Cake" in the library
- **WHEN** the user searches Spotlight for "Lemon Cake"
- **THEN** the recipe appears as a Recipes result

### Requirement: App links
The system SHALL open `recipes://recipe/<id>` on that recipe's page, `recipes://cook/<id>` in cook mode on that recipe (where `<id>` is the recipe's UUID), `recipes://plan` on Plan, and `recipes://groceries` on Groceries. `recipes://mealie?...` pairing links are covered by mealie-sync, and widgets use these links to open the app (see home-screen-widgets).

#### Scenario: Open a recipe link
- **WHEN** the system opens `recipes://recipe/<id>` for a recipe in the library
- **THEN** the app switches to Recipes and shows that recipe's page

#### Scenario: Open the grocery list
- **WHEN** the system opens `recipes://groceries`
- **THEN** the app switches to Groceries
