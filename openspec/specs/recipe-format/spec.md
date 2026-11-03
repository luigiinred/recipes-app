# recipe-format Specification

## Purpose
Defines the recipe JSON document shared by the app (iOS, iPadOS, macOS), the `recipes` CLI, the server and the web UI, and the standard form every recipe is tidied into when it is saved: ingredient lines, ingredient sections, steps, tags and nested categories.

## Requirements

### Requirement: Recipe document fields
The system SHALL store each recipe as one JSON object with the fields `id`, `title`, `summary`, `servings`, `prepMinutes`, `cookMinutes`, `ingredients`, `ingredientSections`, `steps`, `stepTimestamps`, `stepImages`, `tags`, `sourceURL`, `imageURL`, `notes`, `isFavorite`, `rating`, `wantToCook`, `queuedAt`, `timeline`, `createdAt` and `updatedAt`. Only `title` is required to read a file: missing strings default to empty, missing lists to empty, `isFavorite` and `wantToCook` to false, and missing optional numbers, links and `queuedAt` to absent. `ingredients`, `steps` and `tags` are lists of strings; `ingredientSections` is a list of `{title, start}` where `start` is the index of the first ingredient under that heading; `stepTimestamps` (seconds into the source video) and `stepImages` (step photo ids, or null) run parallel to `steps`; `timeline` is a list of `{id, date, note}` cook-log entries.

#### Scenario: Minimal file reads
- **GIVEN** a recipe file containing only `{"title": "Old", "wantToCook": true}`
- **WHEN** the library is read
- **THEN** the recipe has title "Old", no ingredients, steps, step photos or timeline, no rating and no `queuedAt`
- **AND** it is still in Up Next

### Requirement: Ids and dates
The system SHALL identify every recipe by a UUID and write dates as ISO 8601 strings in UTC. The app writes ids in uppercase and whole-second dates; the server writes ids in lowercase and dates like `2026-01-01T10:00:00Z`. Both read ids in either case and dates with or without fractional seconds.

#### Scenario: Server reads an app-written recipe
- **GIVEN** a recipe file written by the app with id `E621E1F8-C36C-495A-93FC-0C247A3E6E5F`
- **WHEN** the server reads it
- **THEN** the recipe's id and step photo ids are reported in lowercase

#### Scenario: Fractional seconds
- **WHEN** the app reads a file with `"createdAt": "2026-01-01T10:00:00.123Z"`
- **THEN** the recipe loads

### Requirement: Title is required
The system MUST refuse to save a recipe whose title is empty after trimming, and SHALL collapse runs of whitespace in the title to single spaces and trim the summary on save (the server also trims the notes). On the server, a recipe file with a blank title is skipped when the library is read.

#### Scenario: Blank title rejected
- **WHEN** a recipe titled "  " is saved in the app, the CLI or through `POST /api/recipes`
- **THEN** the save fails with "A recipe needs a title." (HTTP 422 on the server)

#### Scenario: Title tidied
- **WHEN** a recipe titled "  Pancakes " is saved
- **THEN** it is stored with title "Pancakes"

### Requirement: Ingredient line standard form
The system SHALL write each ingredient as one line in the form "quantity unit item", such as "1 1/2 cups flour" or "2 cloves garlic, minced", and rewrite ingredient lines into that form on save. The unit is one of tsp, tbsp, cup, fl oz, pint, quart, gallon, ml, cl, dl, l, mg, g, kg, oz, lb, pinch, dash, clove, can, package, jar, bunch, sprig, stalk, head, slice, stick and handful; common spellings ("Tablespoons", "tbsp.", "lbs", "teaspoon", "litre", "pkg", "fl oz") are recognized case-insensitively, including a unit attached to the number ("500g"). Abbreviated units never change form; word units agree with the quantity ("1 cup", "2 cups", "1/2 cup"). Vulgar fractions become digits ("½" is "1/2", "1½" is "1 1/2"), a word "of" after the unit is dropped, and bullets, checkboxes and emoji in front of the line are removed. A line with no leading number, or with a number but nothing after the unit, is kept as written. A unit with no quantity reads as one. Writing a line in standard form twice gives the same text.

#### Scenario: Lines rewritten on save
- **WHEN** a recipe is saved with ingredients "2 Tablespoons butter", "500g black beans, dried", "½ cups flour", "2 cloves of garlic, minced" and "🔹 1 lb boneless chicken"
- **THEN** they are stored as "2 tbsp butter", "500 g black beans, dried", "1/2 cup flour", "2 cloves garlic, minced" and "1 lb boneless chicken"

#### Scenario: Lines without a quantity are kept
- **WHEN** a recipe is saved with ingredients "Salt to taste" and "2 cups"
- **THEN** both are stored unchanged

### Requirement: Ingredient ranges and package sizes
In the app and CLI, the system SHALL read "1 to 2", "1 - 2", "1–2" and "1 or 2" before a unit or item as the range "1-2", and SHALL read "N (size) unit item" as N of that package unit with the size kept at the front of the item. A parenthesized size not followed by a unit stays part of the item. The server and web UI do not apply these two rules.

#### Scenario: Ranges
- **WHEN** the app saves ingredients "1 to 2 oz cheese", "1 1/2 to 2 cups stock" and "2 or 3 eggs"
- **THEN** they are stored as "1-2 oz cheese", "1 1/2-2 cups stock" and "2-3 eggs"

#### Scenario: Package sizes
- **WHEN** the app saves ingredients "1 (18.25 ounce) package devil's food cake mix" and "2 (14 oz) cans diced tomatoes"
- **THEN** they are stored as "1 package (18.25 ounce) devil's food cake mix" and "2 cans (14 oz) diced tomatoes"

### Requirement: Ingredient parts
The system SHALL split an ingredient line into an amount (the quantity and unit, such as "3 cloves"), a name (the item up to the first comma) and a preparation (the text after the first comma). A line without a quantity has an empty amount and its whole text as the name.

#### Scenario: Split for display
- **WHEN** the line "3 Cloves garlic, minced" is split
- **THEN** the amount is "3 cloves", the name is "garlic" and the preparation is "minced"

### Requirement: Ingredient sections
The system SHALL keep `ingredients` a single flat list and describe headings such as "For the sauce" only through `ingredientSections`. On save, an ingredient line that is a heading (40 characters or fewer, no digits, and ending in ":" or starting with "For the ") is removed from the list and becomes a section starting at the next ingredient; an all-caps heading is written in title case and the trailing colon is dropped. Sections are kept in order of `start`, blank titles and sections that would hold no ingredients are dropped, a later heading at the same position replaces an earlier one, and section starts move with the ingredients when blank lines are removed. Ingredients before the first section form an untitled group.

#### Scenario: Headings in the list become sections
- **WHEN** a recipe is saved with ingredients "DRESSING:", "1/3 cup olive oil", "SALAD:", "5 cups romaine"
- **THEN** the ingredients are "1/3 cup olive oil" and "5 cups romaine"
- **AND** the sections are "Dressing" starting at 0 and "Salad" starting at 1

#### Scenario: Sections follow dropped lines
- **GIVEN** ingredients "2 potatoes", " ", "1 tsp cinnamon", "2 tbsp sugar" with sections "Chips" at 0, "Cinnamon sugar:" at 2 and " " at 3
- **WHEN** the recipe is saved
- **THEN** the sections are "Chips" at 0 and "Cinnamon sugar" at 1

### Requirement: Step standard form
The system SHALL write each step as plain text without numbering or bullets: on save, whitespace is collapsed, a leading "Step 2:", "1.", "3)" or bullet is removed, the first letter is capitalized, a period is added when the step ends in a letter, digit or ")", and empty steps are dropped. When steps are dropped, `stepTimestamps` and `stepImages` stay aligned with the remaining steps, and a `stepImages` list with no photos is cleared.

#### Scenario: Steps tidied
- **WHEN** a recipe is saved with steps "  Step 2:  whisk   the eggs ", "3) Bake for 20 minutes!" and "• simmer"
- **THEN** they are stored as "Whisk the eggs.", "Bake for 20 minutes!" and "Simmer."

#### Scenario: Timestamps stay aligned
- **WHEN** a recipe is saved with steps "1. chop", "" and "simmer" and step timestamps 5, 10 and 15
- **THEN** the steps are "Chop." and "Simmer." and the timestamps are 5 and 15

### Requirement: Run-together numbered steps are split
In the app and CLI, when one step holds at least three numbered parts running 1, 2, 3 in order ("1. Brown the beef. 2. Add the peppers. 3. ..."), the system SHALL split it into separate steps and move any text before "1." to the end of the recipe's notes. Steps that merely contain numbers are left alone. Split-off steps after the first get no timestamp or photo.

#### Scenario: Pasted block split
- **WHEN** the app saves a recipe whose only step is "NOTE #1: Cut this up. 1. In a large pot, brown the beef. 2. Add the bell pepper. 3. Reduce heat to low."
- **THEN** the steps are "In a large pot, brown the beef.", "Add the bell pepper." and "Reduce heat to low."
- **AND** the notes start with "NOTE #1:"

#### Scenario: Ordinary numbers kept
- **WHEN** the app saves steps "Bake at 350. 2 cups of sugar go in the bowl. Mix well." and "Cook 10. Minutes pass."
- **THEN** the recipe still has two steps

### Requirement: Tags and nested categories
The system SHALL treat tags as categories, where "/" nests one category under another ("Dinner/Pasta" is Pasta inside Dinner). On save, each tag's parts are trimmed and empty parts removed ("Dinner / Pasta" becomes "Dinner/Pasta"), empty tags are dropped, and repeats are removed ignoring case, keeping the first. A category contains recipes tagged with it or with anything beneath it, matching each part case-insensitively and only whole parts. Comma-separated input is split into separate tags. Tags display with " › " between levels.

#### Scenario: Tags tidied
- **WHEN** a recipe is saved with tags "vegetarian", "Dinner/Soup" and "Vegetarian"
- **THEN** its tags are "Vegetarian" and "Dinner/Soup"

#### Scenario: Category matching
- **GIVEN** a recipe tagged "Dinner/Pasta"
- **WHEN** the categories "Dinner", "dinner/pasta" and "Din" are opened
- **THEN** the recipe is in the first two and not in "Din"

#### Scenario: Comma input
- **WHEN** the tags " Dinner / Pasta, ,Soup," are entered
- **THEN** the tags are "Dinner/Pasta" and "Soup"

### Requirement: Category order and moves
In the app, the system SHALL order sibling categories by the user's saved category order (see library-storage), with categories it does not list following alphabetically. Moving a category under another category, or to the top level, SHALL rewrite every recipe tag in the moved category's subtree to the new path and drop tags that become repeats on a recipe; a category cannot move into itself or one of its own subcategories. Moving a category before a sibling places it ahead of that sibling in the saved order. The drag gestures that trigger moves are covered by recipe-browsing.

#### Scenario: Saved order first
- **GIVEN** tags "Dinner/Pasta", "Dinner/Soup", "Breakfast" and "Dessert" and the saved order "Dessert", "Dinner", "Dinner/Soup", "Dinner/Pasta"
- **WHEN** the category tree is built
- **THEN** the top level is Dessert, Dinner, Breakfast and Dinner's children are Soup, Pasta

#### Scenario: Nesting rewrites the subtree
- **GIVEN** recipes tagged "Pasta", "Pasta/Fresh", "Dinner/Soup" and "Dessert"
- **WHEN** Pasta is moved under Dinner
- **THEN** the tags become "Dinner/Pasta", "Dinner/Pasta/Fresh", "Dinner/Soup" and "Dessert"

#### Scenario: Unnesting merges
- **GIVEN** recipes tagged "Dinner/Soup" and "Soup"
- **WHEN** Dinner/Soup is moved to the top level
- **THEN** both recipes are tagged "Soup" and the top level has one Soup category

#### Scenario: No move into itself
- **WHEN** Dinner is dropped onto Dinner/Pasta
- **THEN** nothing moves

### Requirement: Generic tag vocabulary
The system SHALL keep a vocabulary of generic tags in three groups: main ingredient (Beef, Pork, Chicken, Turkey, Lamb, Fish, Seafood, Eggs, Pasta, Rice, Beans, Tofu), diet (Vegetarian, Vegan) and course (Breakfast, Lunch, Dinner, Appetizer, Side, Soup, Salad, Dessert, Snack, Drink). In the app and CLI, a single-level tag matching a vocabulary word ignoring case is saved in the vocabulary's capitalization; nested tags and tags outside the vocabulary are kept as written. Tags suggested for an imported recipe come only from this vocabulary, at most four: main ingredients from the title or the first four ingredients (a named meat or fish drops Pasta, Rice, Eggs and Beans), Vegan and Vegetarian or just Vegetarian when no meat, fish, seafood or meat stock is listed and there are at least two ingredients, and one course from the page's own categories or the title.

#### Scenario: Vocabulary capitalization
- **WHEN** the app saves a recipe tagged "breakfast"
- **THEN** its tag is "Breakfast"

#### Scenario: Suggestions stay generic
- **WHEN** tags are suggested for "Lemon Garlic Salmon" with ingredients "2 salmon fillets", "1 lemon", "3 cloves garlic", "2 tbsp butter" and page keywords "Main Course", "lemon", "garlic", "easy", "quick dinner"
- **THEN** the suggested tags are "Fish" and "Dinner"

#### Scenario: Plant-based dish
- **WHEN** tags are suggested for "Chickpea Curry" with ingredients "2 cans chickpeas", "1 can coconut milk", "200 g spinach" and page category "Dinner"
- **THEN** the suggested tags are "Beans", "Vegan", "Vegetarian" and "Dinner"

### Requirement: Ratings, queue and ideas
The system SHALL store `rating` only as a whole number from 1 to 5 and drop any other value on save, and SHALL keep `queuedAt` only while `wantToCook` is true. A recipe with no ingredients and no steps is an idea: a title and maybe notes, with nothing to cook yet. No field marks an idea; it is derived.

#### Scenario: Invalid rating dropped
- **WHEN** a recipe with rating 9 or 0 is saved
- **THEN** it is stored with no rating

#### Scenario: Queue date cleared
- **WHEN** a recipe with `wantToCook` false and a `queuedAt` date is saved
- **THEN** it is stored without `queuedAt`

#### Scenario: Idea
- **WHEN** a recipe titled "Spaghetti" has notes but no ingredients or steps
- **THEN** it is an idea, and adding one ingredient or one step makes it a full recipe

### Requirement: Collections are derived from recipe fields
The system SHALL compute the built-in collections from recipe fields alone, with the same rules in the app and the web UI: Most Recent is the 20 newest by `createdAt`; Up Next is `wantToCook` recipes by `queuedAt` (falling back to `createdAt`), oldest first; Favorites is `isFavorite`; Top Rated is rating 4 or more, highest first; Uncategorized is recipes with no tags. How these collections are shown is covered by recipe-browsing.

#### Scenario: Top Rated
- **GIVEN** recipes rated 3, 4 and 5
- **WHEN** Top Rated is computed
- **THEN** it lists the 5-star recipe then the 4-star recipe

### Requirement: Normalization on every save
The system SHALL apply the standard form whenever a recipe is saved, whether it comes from the editor, an import, the on-device model, the CLI or the server API, and applying it to an already standard recipe SHALL change nothing. Saving sets `updatedAt` to the save time. In the app, Settings → Data & Developer → "Tidy imported recipes" re-saves every recipe not yet in standard form and reports "Cleaned up N recipes." or "Every recipe is already tidy."

#### Scenario: Idempotent
- **WHEN** a standardized recipe is standardized again
- **THEN** it is unchanged

#### Scenario: Tidy imported recipes
- **GIVEN** every recipe in the library is already in standard form
- **WHEN** the user taps "Tidy imported recipes"
- **THEN** an alert says "Every recipe is already tidy."

### Requirement: Server-side save rules
When the server saves a recipe, it SHALL keep `sourceURL` and `imageURL` only when they are http or https links, drop `servings`, `prepMinutes` and `cookMinutes` that are not positive, keep the original `createdAt`, and set `queuedAt` to the given date, the stored date or the save time while `wantToCook` is true. The server writes no null members and keeps the keys in sorted order, like the app's files.

#### Scenario: Non-web links dropped
- **WHEN** a recipe is created through the API with `sourceURL` "javascript:alert(1)" and `imageURL` "data:text/html,x"
- **THEN** the saved recipe has neither link

#### Scenario: Null members omitted
- **WHEN** a recipe is created through the API with `servings: null` and `rating: null`
- **THEN** its file has no `servings` or `rating` key
