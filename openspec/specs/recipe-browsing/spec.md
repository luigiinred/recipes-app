# recipe-browsing Specification

## Purpose
Lets the user find and organize recipes in the app on iPhone, iPad and Mac: built-in collections, nested categories, list or photo-card display, favorites, star ratings, the Up Next flag, swipe and context-menu actions, drag-to-tag, and search. Wide-screen arrangement is covered by adaptive-layout.

## Requirements

### Requirement: Built-in collections
The system SHALL offer the collections All Recipes, Most Recent, Up Next, Favorites, Top Rated and Uncategorized, each defined by a fixed rule over the library. Most Recent is the 20 newest recipes. Favorites holds `isFavorite` recipes, Top Rated those rated 4 or 5 (highest first), and Uncategorized those with no tags. Up Next holds `wantToCook` recipes, oldest `queuedAt` first, and is shown in the planner (see meal-planning). Other lists are ordered by title.

#### Scenario: Top Rated excludes low ratings
- **GIVEN** recipes rated 5, 4, 3 and one unrated
- **WHEN** the user opens Top Rated
- **THEN** only the 5- and 4-star recipes are listed, the 5-star one first

#### Scenario: Most Recent is capped
- **GIVEN** a library of 30 recipes
- **WHEN** the user opens Most Recent
- **THEN** the 20 newest recipes by creation date are listed

### Requirement: Rating style picks the liked collection
The system MUST show exactly one liked-recipes collection, chosen by the "Mark recipes with" setting (`ratingStyle`: Favorites or Star Ratings, default Favorites): Favorites for Favorites, Top Rated for Star Ratings. Switching the setting never clears hearts or stars.

#### Scenario: Star ratings shown
- **GIVEN** "Mark recipes with" is Star Ratings
- **WHEN** the user views the Recipes home or the Mac sidebar
- **THEN** Top Rated appears and Favorites does not

### Requirement: Recipes home on iPhone and iPad
On iPhone and iPad, the Recipes tab SHALL open on every recipe under a "My Recipes" heading with the recipe count; once the heading scrolls away, the navigation bar shows it as the title with the count as its subtitle. A "Tags" row shows each top-level tag as a photo tile with the number of recipes choosing it would show; tapping a tile narrows to that tag and tapping it again clears it. When the tiles don't fit on one row, the row scrolls and a "Show All" control in the Tags header (the whole header is tappable) wraps them onto as many rows as needed, with "Show Less" returning to one row. Sort is in the navigation bar and offers Most Recent, Name, Rating, Quickest, Last Cooked and Shuffle; its button shows the chosen sort's symbol, and pulling to refresh reloads the library and deals a new shuffle. By default the last chosen sort is remembered; with that setting off, the home opens on the default sort chosen in Settings. In compact width a segmented control beside the count switches between photo cards and the compact list; in regular width recipes are photo cards in columns at least 260 points wide.

#### Scenario: Filtering by a tag tile
- **GIVEN** recipes tagged "Dessert", "Dessert/Cookies" and "Dinner"
- **WHEN** the user taps the Dessert tag on the Recipes home
- **THEN** the Dessert and Dessert/Cookies recipes are listed and the Dinner recipe is not

#### Scenario: Default sort
- **GIVEN** the user has never chosen a sort and the default sort is Most Recent
- **WHEN** the user opens the Recipes tab
- **THEN** the newest recipe is listed first

### Requirement: Filter sheet
The system SHALL offer a "Filters" sheet that narrows the Recipes home by a tag at any depth (top-level tiles, then a row of subtags for the chosen tag, plus Uncategorized), a maximum total time (a histogram of recipe times above a slider, from 10 minutes to "Any"), and "Show only" toggles (Under 30 min, Under 1 hour, Favorites or Top Rated, Up Next, Ideas, Not Made Yet, Videos). Changes apply as they are made; the title's subtitle reads "N of M recipes", Reset clears everything but the search text, and a "Show N Recipes" button (or "No Recipes Match") closes the sheet. The sheet opens from the round filter button at the start of the quick filter row.

#### Scenario: Count follows the filters
- **GIVEN** four recipes, two tagged "Dessert/Cookies"
- **WHEN** the user picks Dessert and then Cookies in the filter sheet
- **THEN** the button reads "Show 2 Recipes"

### Requirement: Recipe details line
Under each recipe's title in cards and rows, the system SHALL show one line with the rating, a heart for favorites and the Up Next mark, then "Idea" for ideas and the recipe's tags (by their last component), and optionally the total time and when it was last made. Settings → Recipes → Recipe details chooses which of Rating, Favorite, Up Next, Tags, Total time and Last made show; the first four are on by default. Photo cards show only the photo above the title.

### Requirement: Library loading and empty states
The system SHALL show "Syncing recipes…" in place of the recipes until the library's first load finishes, "No recipes yet" with a hint to tap +, share from Safari, or use the command-line tool once it has loaded empty, and "Couldn't load recipes" with the error if loading fails.

#### Scenario: First launch before sync
- **GIVEN** the library has not finished loading
- **WHEN** the user opens the Recipes tab
- **THEN** "Syncing recipes…" is shown instead of the empty library

### Requirement: Nested categories
The system SHALL treat tags as categories, where a "/" nests one under another ("Dinner/Pasta" is Pasta inside Dinner), and build the category tree from all recipes' tags, matching names case-insensitively. Each level follows the user's saved category order, with categories it doesn't list after them in alphabetical order. A category's title is its last component; tags display with " › " between levels. A category includes recipes tagged with it or anything beneath it.

#### Scenario: Tree from tags
- **GIVEN** recipes tagged "Dessert/Cookies", "dessert/Cakes" and "Soup"
- **WHEN** the category tree is shown
- **THEN** it has Dessert (with Cakes and Cookies beneath it) and Soup at the top level

### Requirement: Category drill-down on iPhone and iPad
On iPhone and iPad, opening a category SHALL show its subcategories first, each with a count of all recipes in it and beneath it, then only the recipes tagged at exactly that level. Each subcategory can be opened in turn. With both present, the sections are headed "Categories" and "Recipes". On Mac, a category lists every recipe in it or beneath it.

#### Scenario: Drilling into Dessert
- **GIVEN** recipes tagged "Dessert", "Dessert/Cookies" and "Dessert/Cookies"
- **WHEN** the user opens Dessert on iPhone
- **THEN** a Cookies row with count 2 appears under "Categories", and the one recipe tagged "Dessert" appears under "Recipes"

### Requirement: Compact list and photo cards
The system SHALL show a collection as either a Compact List (the default) or Photo Cards, stored in the `recipeListStyle` setting and switchable from Settings or, in a compact-width list, with a toolbar button ("Show as Cards" / "Show as List"). Both show badges: a heart if favorite, a star and number if rated, a queue icon if in Up Next.

#### Scenario: List row content
- **WHEN** a recipe is shown as a list row
- **THEN** it has a small thumbnail, the title with its badges, a one-line summary, and "Idea", its total minutes and up to two categories

#### Scenario: Card without a photo
- **GIVEN** a recipe with no photo
- **WHEN** it is shown as a photo card
- **THEN** the 4:3 card shows an accent-colored gradient with a fork-and-knife symbol behind the title

#### Scenario: Toggling to cards
- **GIVEN** an iPhone showing All Recipes as a compact list
- **WHEN** the user taps "Show as Cards"
- **THEN** the recipes are shown as photo cards and the choice is remembered

### Requirement: Favorites, ratings and Up Next actions
The system SHALL let the user favorite or unfavorite a recipe, rate it 1 to 5 stars or clear the rating, and add it to or remove it from Up Next, from a recipe's context menu (Favorite / Remove Favorite, a Rate submenu with 5 to 1 stars and Clear Rating, Add to / Remove from Up Next) and from the recipe page (see recipe-detail). Adding to Up Next records `queuedAt` as now; removing clears it. On a star rating control, tapping the current star clears the rating.

#### Scenario: Rate from the context menu
- **WHEN** the user long-presses a recipe and chooses Rate, 4 Stars
- **THEN** the recipe's `rating` is saved as 4 and the 4 Stars item shows a checkmark next time

### Requirement: Swipe actions
In recipe lists, the system SHALL offer trailing swipe actions that stay open until tapped (no full swipe): Up Next (a plus icon to add it, a minus icon to remove it), Favorite (or Unfavorite) only when the rating style is Favorites, Delete only when "Show Delete" is on in Settings, and Remove Tag when browsing a category. Delete asks for confirmation ("This can't be undone. The recipe and its photo are removed from all your devices.") before deleting. Remove Tag drops the recipe's tags in that category and beneath it.

#### Scenario: Delete hidden by default
- **GIVEN** "Show Delete" is off
- **WHEN** the user swipes a recipe row left
- **THEN** Up Next and Favorite appear and Delete does not

#### Scenario: Remove Tag inside a category
- **GIVEN** a recipe tagged "Dinner/Pasta" and "Quick", shown in the Dinner category
- **WHEN** the user swipes it and taps Remove Tag
- **THEN** the recipe keeps only "Quick"

### Requirement: Context menu on recipes
The system SHALL give each recipe in a collection list or grid a context menu with Favorite, Rate, Up Next, Edit (opens the editor, see recipe-editor), and, inside a category, Remove Tag.

#### Scenario: Edit from a list
- **WHEN** the user chooses Edit from a recipe's context menu
- **THEN** the recipe editor opens for that recipe

### Requirement: Drag a recipe onto a category
The system SHALL let the user drag a recipe row or card onto a category (a category row or tile on iPhone and iPad, or a Mac sidebar category) to tag it with that category. A recipe already in that category or one of its subcategories is left unchanged.

#### Scenario: Drop files the recipe
- **GIVEN** a recipe with no tags
- **WHEN** the user drops it on the Soup category
- **THEN** the recipe is tagged "Soup" and appears in Soup

#### Scenario: Already filed beneath
- **GIVEN** a recipe tagged "Dessert/Cookies"
- **WHEN** the user drops it on Dessert
- **THEN** its tags do not change

### Requirement: Reorder and nest categories
The system SHALL let the user drag a category onto another category to nest it there, or onto the top or bottom edge of a category to place it before or after that one. Nesting rewrites the tags of every recipe in the moved category and beneath it. Dropping a category on the "Categories" header (iPhone and iPad) or the Recipes row (Mac) moves it to the top level. The order is saved in `CategoryOrder.json` (a JSON array of category paths) in the library folder, so it syncs with the library.

#### Scenario: Works wherever categories are listed
- **WHEN** the user drags a category row or tile on iPhone or iPad, or a category in the Mac sidebar
- **THEN** it can be nested, reordered or moved to the top level as described

#### Scenario: Nest a category
- **GIVEN** recipes tagged "Pasta" and "Pasta/Baked"
- **WHEN** the user drops the Pasta category onto Dinner
- **THEN** those recipes are tagged "Dinner/Pasta" and "Dinner/Pasta/Baked"

#### Scenario: Reorder siblings
- **GIVEN** top-level categories Dessert and Soup
- **WHEN** the user drops Soup on the top edge of Dessert
- **THEN** Soup is listed before Dessert on every device sharing the library

#### Scenario: Cannot nest into itself
- **WHEN** the user drops Dinner onto Dinner/Pasta
- **THEN** nothing changes

### Requirement: Find recipes for a category
When browsing a category in a non-empty library, the system SHALL offer "Find Recipes for <category>" in the category's More (⋯) toolbar menu, which opens a sheet listing recipes not yet in that category that look like they belong, sorted by title and all pre-ticked. A recipe belongs when its suggested or existing generic tag matches the category, or every word of the category name appears in its title, summary, tags or ingredients. "Add N" tags the ticked recipes with the category.

#### Scenario: No candidates
- **GIVEN** no other recipe looks like it belongs in the category
- **WHEN** the user opens the sheet
- **THEN** it shows "Nothing to add"

#### Scenario: Filing soups
- **GIVEN** a category "Soup" and an untagged recipe titled "Tomato Soup"
- **WHEN** the user taps Find Recipes for Soup and then Add 1
- **THEN** Tomato Soup is tagged "Soup"

### Requirement: Search
The system SHALL match a recipe when every space-separated word of the query appears, case-insensitively, in its title, summary, notes, ingredients or tags. On iPhone and iPad, search narrows the Recipes home as one more filter, starting from every recipe: in compact width from the Search tab, which shows the same page and shares its filters and sort, and in regular width from a search field on the Recipes home. While searching, a row of quick filter chips sits above the search field, led by the round filter button; chips that are on shrink to icons pinned at the leading edge while the rest scroll beneath them, and the Tags row hides unless a tag is chosen. Settings → Recipes → Quick Filters chooses which filters and tags the chips offer and their order; tag chips require every chosen tag. Scrolling or opening a recipe dismisses the keyboard and keeps the query. A query with no matches shows a no-results state. On Mac, a search field on the recipe list filters the current collection. Search prompts read "Search My Recipes".

#### Scenario: Multi-word search
- **GIVEN** a recipe "Tomato Soup" with the ingredient "fresh basil"
- **WHEN** the user searches "basil tomato"
- **THEN** the recipe is in the results

#### Scenario: Words must all match
- **WHEN** the user searches "tomato chocolate" and no recipe contains both words
- **THEN** the no-results state is shown

### Requirement: Add Recipe menu
The system SHALL put an Add Recipe (+) menu in the Recipes toolbar with New Recipe, New Idea…, Import from Web or YouTube…, Scan Recipe… (iPhone and iPad only; without a camera it reports "Scanning needs a device with a camera."), Import Photo or PDF…, and Recipe from Meal Photo (Take Photo or Choose Photo on iPhone and iPad; Choose Photo on Mac). A recipe saved from any of these is opened. The flows belong to recipe-editor, web-import, youtube-import and scan-import.

#### Scenario: Category toolbar groups actions
- **GIVEN** the user is browsing a category
- **WHEN** they open the toolbar's More (⋯) menu
- **THEN** it holds the list/cards toggle (in compact width), an Add Recipe submenu, and Find Recipes for that category

#### Scenario: New recipe opens after saving
- **WHEN** the user picks New Recipe, enters a title and saves
- **THEN** the new recipe's page opens

### Requirement: Empty collection
The system SHALL show the collection title with "No recipes here yet." when a collection or category has no recipes and no search is active, and on iPhone and iPad only when it also has no subcategories.

#### Scenario: Empty favorites
- **GIVEN** no recipe is a favorite
- **WHEN** the user opens Favorites
- **THEN** "No recipes here yet." is shown
