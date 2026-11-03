# web-import Specification

## Purpose
Turns a recipe web page into a recipe draft by reading the page's schema.org Recipe data, with its cover photo and step photos. Runs in the iOS, iPadOS and macOS app (the Import from Web or YouTube sheet, also used by share-extension) and on the server as `POST /api/import`.

## Requirements

### Requirement: Import sheet
The app SHALL offer "Import from Web or YouTube…" in the Add Recipe menu, opening a sheet titled "Import from Web or YouTube" with one address field and an Import button that is disabled while the field is empty or an import is running. An address without `://` is treated as `https://`. An address with no host shows "That doesn't look like a web address." and nothing is fetched. A YouTube video link is handed to youtube-import.

#### Scenario: Bare domain
- **WHEN** the user types `example.com/pancakes` and taps Import
- **THEN** the app fetches `https://example.com/pancakes`

#### Scenario: Not an address
- **WHEN** the user enters text that does not parse to an address with a host
- **THEN** the sheet shows "That doesn't look like a web address." and stays open

### Requirement: Progress steps
While importing a web page, the sheet SHALL show the address and a checklist with the steps "Fetching the page", "Reading the recipe" and "Downloading photos", each marked waiting, running, done or skipped, above an overall progress bar. The bar counts a finished or skipped step as whole and a running step as half.

#### Scenario: Import in progress
- **WHEN** the page has been fetched and the recipe is being read
- **THEN** "Fetching the page" shows a checkmark, "Reading the recipe" shows a spinner and "Downloading photos" is waiting

### Requirement: Fetching the page
The app SHALL fetch the page with a desktop Safari user agent and a 20-second timeout, and SHALL fail with "The page returned HTTP <code>." when the response status is outside 200–299.

#### Scenario: Missing page
- **WHEN** the page answers HTTP 404
- **THEN** the import fails with "The page returned HTTP 404."

### Requirement: Reading schema.org Recipe data
The importer SHALL read the first `application/ld+json` block that contains an object whose `@type` is `Recipe` (or a list including `Recipe`), searching top-level arrays and `@graph`, and SHALL ignore blocks that are not valid JSON. CDATA markers wrapped around a block are removed before parsing. A Recipe object without a `name` is skipped. When no block yields a recipe the import fails with "No recipe found on that page." The app and the server read the same fields the same way.

#### Scenario: Recipe inside @graph
- **GIVEN** a page whose JSON-LD has `@graph` with a WebSite object and a Recipe object
- **WHEN** it is imported
- **THEN** the draft is built from the Recipe object

#### Scenario: No recipe data
- **WHEN** a page has no JSON-LD Recipe
- **THEN** the import fails with "No recipe found on that page."

### Requirement: Field mapping
The importer SHALL map `name` to title, `description` to summary, the first number in `recipeYield` to servings, ISO 8601 `prepTime` and `cookTime` (days, hours, minutes) to prep and cook minutes, `recipeIngredient` (or `ingredients`) to ingredients, and `recipeInstructions` to steps, and SHALL set `sourceURL` to the page address. Text has HTML tags removed, entities decoded and surrounding whitespace trimmed. Instructions may be a newline-separated string, a list, `HowToSection` objects with `itemListElement`, `HowToStep` objects (`text`, else `name`), or an object with numeric keys read in key order; lists of ingredients may also be numeric-key objects. A duration of zero or one that doesn't parse gives no value.

#### Scenario: Sections and steps flattened
- **GIVEN** `recipeInstructions` holds a HowToSection with one HowToStep "Mix." and a HowToStep "Cook &amp; flip."
- **WHEN** the page is imported
- **THEN** the steps are "Mix." and "Cook & flip."

#### Scenario: Durations
- **WHEN** `cookTime` is `PT1H15M` and `prepTime` is `P1DT2H`
- **THEN** cook minutes is 75 and prep minutes is 1560

#### Scenario: Object-serialized lists
- **WHEN** `recipeIngredient` is `{"0":"1 cup flour","1":"2 eggs"}`
- **THEN** the ingredients are "1 cup flour" and "2 eggs" in that order

### Requirement: Imported title cleanup
The importer SHALL collapse whitespace in the title and drop a site name after " | " and a trailing " Recipe by <name>".

#### Scenario: Site name removed
- **WHEN** the page's recipe name is "The Best Chewy Chocolate Chip Cookies Recipe by Tasty"
- **THEN** the draft title is "The Best Chewy Chocolate Chip Cookies"

### Requirement: Suggested tags
The importer SHALL suggest generic tags for the draft from the title, the leading ingredients and the page's `recipeCategory` and `keywords`: up to two main-ingredient tags (such as Chicken, Fish, Pasta), and a course tag (such as Breakfast, Dessert, Dinner), at most four tags in all. The vocabulary and the vegetarian rules belong to recipe-format.

#### Scenario: Course from the page's category
- **WHEN** a pancake recipe has `recipeCategory` "Breakfast"
- **THEN** its suggested tags include "Breakfast"

#### Scenario: Main ingredient and course from the title
- **WHEN** a recipe titled "Salmon Dinner" with "1 lb salmon" is imported
- **THEN** the suggested tags are "Fish" and "Dinner"

### Requirement: Cover photo
The importer SHALL take the cover photo from the recipe's `image` (a string, the first usable entry of a list, or an object's `url` or `contentUrl`), falling back to the page's `og:image` or `og:image:secure_url` meta tag, resolved against the page address. In the app the photo is downloaded (15-second timeout, under 15 MB, http or https only) and stored as described in recipe-photos; a photo that fails to download leaves the draft without one.

#### Scenario: Open Graph fallback
- **GIVEN** the Recipe object has no `image` and the page has `<meta property="og:image" content="https://cdn.example.com/toast.jpg">`
- **WHEN** the page is imported
- **THEN** the cover photo is downloaded from `https://cdn.example.com/toast.jpg`

### Requirement: Step photos
In the app, the importer SHALL download the `image` of each `HowToStep` (up to the first 40 steps, concurrently) and attach each photo to its step. Step photos are dropped when the page has none, or when splitting long steps (see apple-intelligence) changed the number of steps.

#### Scenario: Photos follow their steps
- **GIVEN** the first of two steps has an image and the second has none
- **WHEN** the page is imported
- **THEN** the first step gets the photo and the second has none

### Requirement: Long steps split on import
In the app, a web import SHALL standardize the draft (see recipe-format) and pass steps longer than 450 characters to the on-device model to be split, as described in apple-intelligence; without Apple Intelligence the steps are kept as they are.

#### Scenario: Model unavailable
- **GIVEN** Apple Intelligence is not available
- **WHEN** a page with one 900-character step is imported
- **THEN** the draft keeps that single step

### Requirement: Review or save
The app SHALL open a finished import in the recipe editor for review, with the photo and step photos attached, when the "Review before saving" setting (Settings → Recipes → Importing, on by default) is on or the import is incomplete. With the setting off and a complete import, the app saves the recipe directly, closes the sheet and selects the new recipe.

#### Scenario: Review off
- **GIVEN** "Review before saving" is off
- **WHEN** a page with full recipe data is imported
- **THEN** the recipe is saved without opening the editor and is selected in the list

#### Scenario: Review on
- **GIVEN** "Review before saving" is on
- **WHEN** a page is imported
- **THEN** the editor opens with the draft and nothing is saved until the user saves

### Requirement: Apple Intelligence fallback for pages without recipe data
When a web import fails with "No recipe found on that page.", the app SHALL offer "Try with Apple Intelligence". The button is disabled, with the reason shown beneath it, when Apple Intelligence isn't available. Using it fetches the page, reads its visible text with the on-device model, and opens the result in the editor for review, as described in apple-intelligence.

#### Scenario: Offered after a miss
- **WHEN** a page without schema.org data is imported
- **THEN** the sheet shows "No recipe found on that page." and a "Try with Apple Intelligence" button

### Requirement: Server import endpoint
The server SHALL accept `POST /api/import` with `{ "url": "<address>" }` and return `{ "draft": <recipe input>, "image": <data URL or null> }` without saving anything. The draft uses the same field mapping, title cleanup and tag suggestions as the app; step photos and step splitting are not done on the server. The cover photo is returned as a `data:image/...;base64,` URL only when the download succeeds with a 2xx status and its bytes are recognized as JPEG, PNG, GIF or WebP; otherwise `image` is null. Pages are limited to 5 MB and photos to 15 MB.

#### Scenario: Draft and photo returned
- **WHEN** a client posts the address of a page with recipe data and a JPEG photo
- **THEN** the response has the draft and an `image` starting with `data:image/jpeg;base64,`
- **AND** the library's recipe list is unchanged

#### Scenario: Error statuses
- **WHEN** the body's `url` is not a valid URL
- **THEN** the server answers 422
- **AND** a page answering a non-2xx status gives 502 "The page returned HTTP <code>.", a page without recipe data gives 422 "No recipe found on that page.", and a YouTube address (youtube.com, www., m., music., youtu.be) gives 422 "Importing from YouTube isn't supported on the server yet. Use the iPhone or Mac app."

### Requirement: Safe server fetching
The server SHALL fetch import pages and photos only over http or https, following at most 5 redirects within one 30-second deadline (15-second socket timeout), and SHALL refuse loopback, private, link-local, carrier-grade NAT, multicast, reserved and tunnelled addresses at connection time on every hop, unless `ALLOW_PRIVATE_IMPORTS=true`. Responses compressed with gzip, deflate or brotli are decoded, and a body over the size limit is abandoned with "That page is too large to import." Markup is scanned in linear time so hostile pages cannot stall the server.

#### Scenario: Private address refused
- **GIVEN** `ALLOW_PRIVATE_IMPORTS` is not set
- **WHEN** a client imports `http://127.0.0.1:9/` or `http://[::1]/`
- **THEN** the server answers 400 "That address isn't allowed."

#### Scenario: Non-web scheme refused
- **WHEN** a client imports `file:///etc/passwd`
- **THEN** the server answers 400 "Only web addresses can be imported."

#### Scenario: Hostname resolving to a private address
- **WHEN** a client imports `http://localhost:9/`
- **THEN** the connection is refused at lookup and the server answers 502

#### Scenario: Redirect followed
- **GIVEN** private imports are allowed and `/old` redirects to `/pancakes`
- **WHEN** a client imports `/old`
- **THEN** the draft's `sourceURL` is the `/pancakes` address
