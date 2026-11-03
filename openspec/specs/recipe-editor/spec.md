# recipe-editor Specification

## Purpose
The form for writing a new recipe or changing an existing one in the app on iPhone, iPad and Mac, also used to review imported and scanned drafts. It edits the photo, title, timings, structured ingredients with sections, steps with photos and video times, flags, categories, source and notes. How a saved recipe is normalized is covered by recipe-format.

## Requirements

### Requirement: Editor title and save rules
The system SHALL title the editor "New Recipe" when the recipe has no title yet and "Edit Recipe" otherwise, and MUST keep Save disabled while the title is empty or only whitespace. Cancel closes the editor without saving. Save closes the editor and writes the recipe.

#### Scenario: Save needs a title
- **GIVEN** the New Recipe editor with an empty title
- **WHEN** the user looks at the toolbar
- **THEN** Save is disabled until a title is typed

### Requirement: Basic fields
The system SHALL edit Title, Summary, Servings, Prep minutes, Cook minutes, Source URL and Notes. Servings and minutes are saved only when they are whole numbers; anything else leaves them empty. A blank Source URL is saved as no source.

#### Scenario: Non-numeric servings
- **WHEN** the user types "four" in Servings and saves
- **THEN** the recipe is saved without a servings value

### Requirement: Structured ingredient rows
The system SHALL edit each ingredient as three parts: a quantity field ("Qty"), a unit menu ("No unit" or a unit from the preset groups), and an item field. An item typed or pasted as a whole line with no quantity or unit (such as "2 cups flour") is still split into its parts when saved. Empty ingredient rows are dropped on save.

#### Scenario: Pasted whole line
- **GIVEN** an ingredient row with no quantity or unit
- **WHEN** the user types "2 cups flour" in the item field and saves
- **THEN** the saved ingredient is "2 cups flour", and reopening the editor shows 2, cups and flour in their own fields

### Requirement: Ingredient sections
The system SHALL let the user add a section heading among the ingredients with "Add Section", name it, drag it to a new position, and delete it, so the ingredients after a heading belong to that section until the next one. The footer advises adding a section only for a distinct part of the meal, like a salad's dressing.

#### Scenario: Dressing section
- **GIVEN** ingredients "lettuce", then a heading "Dressing", then "olive oil" and "vinegar"
- **WHEN** the user saves
- **THEN** the recipe has a "Dressing" section holding olive oil and vinegar

### Requirement: Reorder and delete rows
The system SHALL show reorder handles and delete controls on ingredient and step rows without a separate Edit mode on iPhone and iPad, and a remove (−) button on each row on Mac. Every row also has a Delete item in its context menu.

#### Scenario: Reorder steps
- **WHEN** the user drags step 3 above step 1 and saves
- **THEN** the saved steps are in the new order

### Requirement: Steps
The system SHALL number each step in the editor, add a step with "Add Step", and drop steps that are empty or only whitespace on save, trimming the rest.

#### Scenario: Blank step dropped
- **GIVEN** steps "Boil water", "", "Add pasta"
- **WHEN** the user saves
- **THEN** the recipe has two steps

### Requirement: Step photos
The system SHALL let each step have one photo, picked from the photo library through the step's photo button (resized to at most 1200 pixels) and removed with "Remove Photo" in the step's context menu. Photos of steps that are removed are deleted when the recipe is saved.

#### Scenario: Add a step photo
- **WHEN** the user picks a photo for step 2 and saves
- **THEN** step 2 shows that photo on the recipe page

### Requirement: Video step times
When the Source URL is a YouTube video, the system SHALL show an "m:ss" time field on each step and save the entered times as the steps' video timestamps. If no step has a time, no timestamps are saved.

#### Scenario: Times only for videos
- **GIVEN** a recipe whose source is a web page
- **WHEN** the user edits it
- **THEN** no time field is shown on the steps

### Requirement: Recipe photo
The system SHALL let the user add or change the recipe photo from the photo library ("Add Photo" / "Change Photo"), create one with Image Playground where available ("Create with Image Playground"; see recipe-photos), and remove it ("Remove Photo"). The change is applied only when the recipe is saved.

#### Scenario: Remove photo then cancel
- **GIVEN** a recipe with a photo
- **WHEN** the user taps Remove Photo and then Cancel
- **THEN** the recipe keeps its photo

### Requirement: Flags and rating
The system SHALL let the user set Favorite, a one-to-five star Rating, and Up Next in the editor. Turning Up Next on records the time it was queued; leaving it on keeps the original queued time; turning it off clears it.

#### Scenario: Keep queue position
- **GIVEN** a recipe already in Up Next
- **WHEN** the user edits its title and saves
- **THEN** its place in Up Next is unchanged

### Requirement: Tag editor
The system SHALL edit tags (in the editor's "Categories" section and the recipe page's Tags sheet) as removable chips plus an "Add a new tag" field that adds a tag on Return, on a comma, or with the Add button shown while typing. Below it, every tag used in the library is offered alphabetically under "Your tags"; with no tags in the library yet, the generic starter tags are offered under "Suggestions". Duplicates are ignored case-insensitively, and "/" nests a tag ("Dinner/Pasta").

#### Scenario: Typing filters suggestions
- **GIVEN** the library has tags "Soup" and "Salad"
- **WHEN** the user types "so"
- **THEN** only "Soup" is offered, and tags already on the recipe are never offered

#### Scenario: Comma adds a chip
- **WHEN** the user types "Soup," in the Add a new tag field
- **THEN** a "Soup" chip is added and the field clears

#### Scenario: Duplicate ignored
- **GIVEN** the recipe already has "Soup"
- **WHEN** the user adds "soup"
- **THEN** no second chip appears

#### Scenario: Library tags offered
- **GIVEN** other recipes are tagged "Weeknight" and "Baking"
- **WHEN** the user opens the tag editor on a recipe with no tags
- **THEN** "Baking" and "Weeknight" are offered under "Your tags", in that order

### Requirement: Keyboard dismissal
On iPhone and iPad, the system SHALL dismiss the keyboard as soon as the user scrolls the editor or the Tags sheet.

#### Scenario: Scroll hides keyboard
- **GIVEN** the keyboard is up while editing a step
- **WHEN** the user scrolls the form
- **THEN** the keyboard is dismissed

### Requirement: Delete from the editor
The system SHALL offer "Delete Recipe…" only for a recipe that is already in the library, and MUST ask for confirmation ("This can't be undone. The recipe and its photo are removed from all your devices.") before deleting. A new or imported draft has no delete button; Cancel discards it.

#### Scenario: Draft has no delete
- **GIVEN** an imported recipe under review
- **WHEN** the editor opens
- **THEN** there is no Delete Recipe… button

### Requirement: Reviewing a draft
When opened on an import or scan, the system SHALL show any notice from the importer at the top as a warning, and the source text (such as the scanned text or captions) in a collapsible section under its title, with the footer "Check the recipe below against the scan before saving." when there is no notice.

#### Scenario: Scanned text shown
- **GIVEN** a recipe read from a scanned page
- **WHEN** the editor opens
- **THEN** a "Scanned text" disclosure holds the recognized text

### Requirement: Clean Up with Apple Intelligence
The system SHALL offer "Clean Up with Apple Intelligence", which tidies the ingredients, turns labels such as "Dressing:" into sections, splits run-together steps, and groups a long ingredient list, then reports what it changed ("Everything already looks tidy." when nothing changed). Nothing is saved until the user taps Save. If the number of steps changes, step times and photos are cleared and the message says so.

#### Scenario: Without Apple Intelligence
- **GIVEN** Apple Intelligence is unavailable
- **WHEN** the user taps Clean Up with Apple Intelligence
- **THEN** the message adds that splitting long steps and grouping ingredients need Apple Intelligence, and why it is unavailable (see apple-intelligence)

#### Scenario: Nothing to clean
- **GIVEN** a recipe already in standard form
- **WHEN** the user taps Clean Up with Apple Intelligence
- **THEN** the footer reads "Everything already looks tidy."
