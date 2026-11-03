# unit-conversion Specification

## Purpose
Shows an ingredient's amount in other units, such as "1 cup" as "16 tbsp", "8 fl oz" and "237 ml", when the cook presses and holds an ingredient in the app on iPhone, iPad and Mac, and copies the chosen equivalent. Recipes are never rewritten in another unit. The web UI and server do not convert units.

## Requirements

### Requirement: Conversion menu on ingredients
On a recipe's detail page and in cook mode, pressing and holding (or right-clicking on Mac) an ingredient SHALL open a menu headed "<amount> is" (such as "1 cup is") listing the ingredient's equivalent amounts. Choosing an equivalent copies its text, such as "237 ml", to the clipboard. An ingredient with no equivalents has no menu.

#### Scenario: Copy an equivalent
- **GIVEN** a recipe with the ingredient "1 cup flour"
- **WHEN** the user presses and holds it and chooses "237 ml"
- **THEN** "237 ml" is on the clipboard

#### Scenario: No menu for counts
- **GIVEN** the ingredient "2 cloves garlic"
- **WHEN** the user presses and holds it
- **THEN** no conversion menu appears

### Requirement: Conversions follow the shown amount
The system SHALL convert the amount as it is shown, so on a scaled recipe (see ingredient-scaling) the equivalents are those of the scaled amount.

#### Scenario: Doubled cup
- **GIVEN** "1 cup flour" shown at 2× as "2 cups flour"
- **WHEN** the user presses and holds it
- **THEN** the menu is headed "2 cups is" and lists "32 tbsp", "16 fl oz" and "473 ml"

### Requirement: Which ingredients convert
The system SHALL offer equivalents only for a single positive quantity in a volume unit (tsp, tbsp, cup, fl oz, pint, quart, gallon, ml, cl, dl, l) or a weight unit (mg, g, kg, oz, lb). Count units (clove, can, package, pinch and the like), lines without a unit or quantity, and ranges get none. Volume converts only to volume and weight only to weight.

#### Scenario: Nothing to convert
- **WHEN** equivalents are asked for "2 cloves garlic", "3 eggs", "salt to taste" and "2-3 cups broth"
- **THEN** each has none

### Requirement: US equivalents
The system SHALL list US equivalents first, in the order tsp, tbsp, fl oz, cup, quart, gallon for volume and oz, lb for weight, leaving out the ingredient's own unit. A US equivalent is listed only when it is from 1/4 to 32 (from 1 for quart and gallon) and can be written as a whole number or common fraction within 6% (see ingredient-scaling for the fractions), with the unit agreeing with the amount. Pints are never offered.

#### Scenario: Cups
- **WHEN** equivalents are asked for "1 cup flour" and "1 1/2 cups milk"
- **THEN** they are "16 tbsp", "8 fl oz", "237 ml" and "24 tbsp", "12 fl oz", "355 ml"

#### Scenario: Spoons
- **WHEN** equivalents are asked for "1 tbsp olive oil" and "1 tsp salt"
- **THEN** they are "3 tsp", "1/2 fl oz", "15 ml" and "1/3 tbsp", "5 ml"

#### Scenario: Weights
- **WHEN** equivalents are asked for "8 oz cream cheese" and "2 lb potatoes"
- **THEN** they are "1/2 lb", "227 g" and "32 oz", "907 g"

### Requirement: Metric equivalent
The system SHALL end the list with one metric equivalent: milliliters below 1000 ml and liters from 1000 ml for volume, grams below 1000 g and kilograms from 1000 g for weight, left out when it is the ingredient's own unit or below 0.1. Milliliter and gram amounts below 10 round to the nearest half and others to a whole number; liter and kilogram amounts round to two decimal places.

#### Scenario: Liters for large volumes
- **WHEN** equivalents are asked for "5 cups stock"
- **THEN** they are "1 1/4 quarts" and "1.18 l"

#### Scenario: Metric source
- **WHEN** equivalents are asked for "250 ml water" and "500 g flour"
- **THEN** they are "17 tbsp", "8 1/2 fl oz", "1 cup" and "17 1/2 oz", "1 1/8 lb"
