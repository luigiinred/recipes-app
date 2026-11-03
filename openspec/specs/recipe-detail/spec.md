# recipe-detail Specification

## Purpose
The recipe page in the app on iPhone, iPad and Mac: a readable view of one recipe with its photo or video, key facts, quick actions, ingredients, directions and notes, plus a menu for rating, printing, sharing and editing. How the page splits into columns on wide screens is covered by adaptive-layout.

## Requirements

### Requirement: Title and artwork
The system SHALL show the recipe's title in large bold text at the top of the page content. When the recipe has a photo and no YouTube video, the photo runs across the top of the page up behind the navigation bar, and the content sits on a card with rounded top corners overlapping it. Once the user scrolls the title away, it moves into the navigation bar. A YouTube recipe shows its video player at the top instead of a photo (see youtube-import).

#### Scenario: Photo above the title
- **GIVEN** a recipe with a photo and no video
- **WHEN** the user opens it
- **THEN** the photo fills the top of the page and the title is shown below it on the content card

#### Scenario: Photo follows scrolling
- **GIVEN** a recipe page with a photo in one column
- **WHEN** the user scrolls down
- **THEN** the photo moves at half speed as the card covers it
- **AND** pulling down past the top enlarges the photo from its bottom edge instead of opening a gap

### Requirement: Facts row
The system SHALL show a row of facts for whichever of Total Time, Cook Time and Servings the recipe has, formatting minutes as "N min", "N hr" or "N hr M min". Servings follow the chosen scale (see ingredient-scaling).

#### Scenario: Duration formatting
- **GIVEN** a recipe with a total time of 90 minutes and a cook time of 60 minutes
- **WHEN** the user opens it
- **THEN** the row shows Total Time "1 hr 30 min" and Cook Time "1 hr"

### Requirement: Quick action tiles
The system SHALL show action tiles under the facts: Cook (starts cook mode at the current scale, disabled when there are no steps; see cook-mode), Groceries (opens a sheet to add the scaled ingredients, disabled when there are no ingredients; see groceries), Up Next (shows "Queued" when the recipe is in Up Next and toggles it), and Plan (opens "Add to Planner" with a Day and a Meal; see meal-planning). Cook and Groceries are not shown for an idea.

#### Scenario: Queue from the page
- **GIVEN** a recipe not in Up Next
- **WHEN** the user taps the Up Next tile
- **THEN** the recipe is added to Up Next and the tile reads "Queued"

### Requirement: Rating and summary in the header
The system SHALL show a five-star rating control in the header when the rating style is Star Ratings or the recipe already has a rating, followed by the summary.

#### Scenario: Rating control hidden for favorites style
- **GIVEN** the rating style is Favorites and the recipe has no rating
- **WHEN** the user opens it
- **THEN** no star control is shown in the header

### Requirement: Tags under the title
The system SHALL show the recipe's tags as chips directly under the title (nested ones shown with " › "), followed by an "Add" chip, or "Add Tags" when the recipe has none. Tapping a tag chip or the Add chip opens a "Tags" sheet with the tag editor (see recipe-editor) and Cancel and Done. Done saves the tags only if they changed; Cancel discards the edits.

#### Scenario: Add the first tag
- **GIVEN** a recipe with no tags
- **WHEN** the user taps Add Tags, adds "Soup" and taps Done
- **THEN** the recipe is saved with the tag "Soup" and a Soup chip shows under the title

#### Scenario: Cancel keeps tags
- **GIVEN** a recipe tagged "Soup"
- **WHEN** the user opens the Tags sheet, removes Soup and taps Cancel
- **THEN** the recipe is still tagged "Soup"

### Requirement: Ingredients
The system SHALL list the ingredients under "INGREDIENTS", grouped under their section headings when the recipe has sections. Each line shows the amount in bold, the item in the body style, and any preparation in grey italics. Pressing and holding an ingredient offers its amount in other units to copy (see unit-conversion), and a scale menu beside the heading changes the amounts (see ingredient-scaling).

#### Scenario: Styled ingredient line
- **WHEN** the recipe shows "2 tbsp olive oil, plus more for serving"
- **THEN** "2 tbsp" is bold and the preparation after the item is grey italic

### Requirement: Directions
The system SHALL list the steps under "DIRECTIONS", each headed "STEP n", followed by its text, chips for the ingredients that step uses, and its step photo when it has one. For a YouTube recipe, a step with a timestamp shows a play button with its time that plays the video from that moment.

#### Scenario: Step ingredient chips
- **GIVEN** a step "Whisk the eggs with the milk" and ingredients "3 eggs" and "1/2 cup milk"
- **WHEN** the user opens the recipe
- **THEN** that step shows chips for "3 eggs" and "1/2 cup milk"

### Requirement: Notes and source
The system SHALL show the notes under "NOTES" when there are any, and a link to the source URL labelled with its host name.

#### Scenario: Source link
- **GIVEN** a recipe imported from https://www.example.com/soup
- **WHEN** the user opens it
- **THEN** a "www.example.com" link opens the source page

### Requirement: Ideas
The system SHALL show an idea (a recipe with no ingredients or steps) as a note, "Just an idea so far", explaining that adding ingredients and steps makes it a full recipe, with an "Add Ingredients and Steps" button that opens the editor.

#### Scenario: Idea page
- **GIVEN** an idea titled "Leftovers"
- **WHEN** the user opens it
- **THEN** the idea note and Add Ingredients and Steps button appear instead of ingredients and directions

### Requirement: More menu
The system SHALL give the recipe page a More (⋯) menu with Favorite / Remove Favorite, Rate, Add to / Remove from Up Next, Timeline (see cooking-timeline), Create a Photo… (only when Image Playground is available and the recipe has no photo; see recipe-photos), Print…, Share, Find Step Timestamps (only for a YouTube recipe with steps; see youtube-import), and Edit (see recipe-editor). Deleting the recipe from the editor closes the page.

#### Scenario: Create a Photo hidden when there is one
- **GIVEN** a recipe that has a photo
- **WHEN** the user opens the More menu
- **THEN** Create a Photo… is not listed

### Requirement: Print
The system SHALL print a recipe as a page with the title, the summary in italics, a facts line ("Serves N · Prep N min · Cook N min"), "Ingredients" with section subheadings, a numbered "Method", "Notes" and the source URL, using the system print dialog on iPhone, iPad and Mac.

#### Scenario: Print layout
- **WHEN** the user chooses Print… for a recipe with 4 servings and two steps
- **THEN** the print dialog opens with "Serves 4" and a numbered two-item Method

### Requirement: Share as Markdown
The system SHALL share a recipe as Markdown text: "# Title", the summary, a facts line ("Servings: N · Prep: N min · Cook: N min"), "Tags: …", "## Ingredients" as a bullet list with "### Section" subheadings, "## Steps" as a numbered list, "## Notes", and "Source: URL". For a YouTube recipe, a step with a timestamp ends with a link to that moment in the video ("[▶ m:ss](https://youtu.be/<id>?t=<seconds>)").

#### Scenario: Shared steps
- **WHEN** the user shares a recipe with steps "Boil water" and "Add pasta"
- **THEN** the text contains "## Steps", "1. Boil water" and "2. Add pasta"
