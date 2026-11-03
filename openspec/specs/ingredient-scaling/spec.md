# ingredient-scaling Specification

## Purpose
Lets the cook make a recipe at a bigger or smaller batch size in the app on iPhone, iPad and Mac: ingredient amounts, ranges and servings follow the chosen scale, and cook mode and Add to Groceries use the scaled amounts. The web UI and server do not scale recipes.

## Requirements

### Requirement: Scale menu
On a recipe's detail page, the system SHALL show a Scale menu in the Ingredients section header with the choices ½×, 1×, 1½×, 2×, 3× and 4×, starting at 1×. The label reads "Scale" followed by the current choice, in the secondary color at 1× and in the accent color otherwise, and is announced as "Scale recipe" with the choice as its value. The menu is hidden when the recipe has no ingredients and while previewing a recipe that has not been saved yet.

#### Scenario: Choosing a scale
- **WHEN** the user opens the Scale menu on a recipe and picks 2×
- **THEN** the label reads "Scale 2×" in the accent color

#### Scenario: Hidden for an idea
- **GIVEN** a recipe with no ingredients
- **WHEN** its detail page is shown
- **THEN** no Scale menu appears

### Requirement: Scaling is a view, not an edit
The system SHALL apply the scale only to what is shown and used from the detail page, and MUST NOT change the saved recipe. The scale resets to 1× when the recipe is opened again.

#### Scenario: Saved recipe unchanged
- **GIVEN** a recipe with "1 cup flour" shown at 2×
- **WHEN** the user edits the recipe
- **THEN** the editor shows "1 cup flour"

### Requirement: Ingredient amounts follow the scale
The system SHALL multiply each ingredient's quantity by the scale and rewrite the line in standard form (see recipe-format), with the unit's singular or plural agreeing with the new amount. Scaled amounts are written as a whole number or common fraction (1/8, 1/4, 1/3, 3/8, 1/2, 5/8, 2/3, 3/4, 7/8, with only halves from 10 up) when one is within 6%; otherwise as a decimal rounded to one place below 10 and to a whole number from 10 up. Steps are not changed.

#### Scenario: Fractions
- **WHEN** "1 1/2 cups flour" is shown at 2×, "1 cup sugar" at ½× and "1/3 cup oil" at 3×
- **THEN** they read "3 cups flour", "1/2 cup sugar" and "1 cup oil"

#### Scenario: No close fraction
- **WHEN** "1/8 tsp salt" is shown at 1½×
- **THEN** it reads "0.2 tsp salt"

#### Scenario: Counts and packages
- **WHEN** "4 eggs" is shown at 1½× and "1 (18.25 ounce) package cake mix" at 2×
- **THEN** they read "6 eggs" and "2 packages (18.25 ounce) cake mix"

### Requirement: Ranges scale at both ends
The system SHALL scale both ends of a ranged quantity and write the result as "lower-upper".

#### Scenario: Range doubled
- **WHEN** "1-2 oz cheese" and "1 to 1 1/2 cups milk" are shown at 2×
- **THEN** they read "2-4 oz cheese" and "2-3 cups milk"

### Requirement: Lines without a quantity stay as written
The system SHALL leave an ingredient whose quantity cannot be read unchanged at any scale.

#### Scenario: To taste
- **WHEN** "Salt to taste" is shown at 3×
- **THEN** it reads "Salt to taste"

### Requirement: Servings follow the scale
The system SHALL multiply the recipe's servings by the scale and round to the nearest whole number, never below 1, in the detail page's facts. A recipe without servings shows none.

#### Scenario: Doubled servings
- **GIVEN** a recipe for 4 servings with "2 cups broth" and "salt"
- **WHEN** it is shown at 2×
- **THEN** it shows 8 servings and the ingredients "4 cups broth" and "salt"

### Requirement: Cook mode and groceries use the scale
The system SHALL open cook mode from the detail page's Cook button at the detail page's current scale, showing scaled ingredient amounts throughout the session, and SHALL add the scaled ingredient lines when the user adds the recipe to groceries from the detail page. Tapping Cook again for the recipe already open in cook mode keeps that session's scale.

#### Scenario: Cooking a doubled recipe
- **GIVEN** a recipe with "1 cup rice" shown at 2×
- **WHEN** the user taps Cook
- **THEN** cook mode lists "2 cups rice"

#### Scenario: Groceries at scale
- **GIVEN** a recipe with "2 cups broth" shown at 2×
- **WHEN** the user taps Groceries
- **THEN** the sheet lists broth with the quantity "4 cups"
