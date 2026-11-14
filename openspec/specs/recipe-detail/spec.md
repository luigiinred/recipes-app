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
The system SHALL show the recipe's tags as chips directly under the title (nested ones shown with " › "), followed by an "Add" chip, or "Add Tags" when the recipe has none. Tapping a tag chip opens a list of every recipe with that tag, where tapping a recipe opens it; a tag chip's context menu also offers Edit Tags…. Tapping the Add chip opens a "Tags" sheet with the tag editor (see recipe-editor) and Cancel and Done. Done saves the tags only if they changed; Cancel discards the edits.

#### Scenario: Add the first tag
- **GIVEN** a recipe with no tags
- **WHEN** the user taps Add Tags, adds "Soup" and taps Done
- **THEN** the recipe is saved with the tag "Soup" and a Soup chip shows under the title

#### Scenario: Browse a tag
- **GIVEN** a recipe tagged "Breakfast"
- **WHEN** the user taps the Breakfast chip
- **THEN** a "Breakfast" page lists every recipe tagged Breakfast

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
The system SHALL give the recipe page a More (⋯) menu with Favorite / Remove Favorite, Rate, Add to / Remove from Up Next, Timeline (see cooking-timeline), Create a Photo… (only when Image Playground is available and the recipe has no photo; see recipe-photos), Print…, Share (see Share options), Find Step Timestamps (only for a YouTube recipe with steps; see youtube-import), Clean Up (not for ideas; checks the recipe again even after a dismissed suggestion), and Edit (see recipe-editor). Deleting the recipe from the editor closes the page.

#### Scenario: Create a Photo hidden when there is one
- **GIVEN** a recipe that has a photo
- **WHEN** the user opens the More menu
- **THEN** Create a Photo… is not listed

### Requirement: Cleanup suggestions
About a second after a recipe page opens, when "Suggest cleanups on recipes" is on (Settings → Apple Intelligence, on by default), the system SHALL check the recipe for a cleanup and, when something would change, show a "Suggested cleanup" card at the bottom of the page with a summary such as "Tidy 2 ingredients and split 1 long step.", a Review button and an X. The changes are found one by one: each ingredient written in standard form (see recipe-format), labels such as "Dressing:" turned into sections or, with Apple Intelligence and only in the rare recipe that makes a distinct part separately (at least six ingredients and a method that names a dressing, sauce, marinade, glaze, frosting, filling, crust, topping or similar), the ingredients grouped into two or three sections of at least two each, such as Salad and Dressing, each step tidied or split (numbered steps run together, and with Apple Intelligence long steps), and text before numbered steps moved into Notes.

Review opens "Review Cleanup", which lists every change under Ingredients, Sections, Steps and Notes as a before and an after: a one-line change shows removed words struck through in red and added words in the accent, and other changes show the whole before and after (section titles as headings). Each change has a checkbox, all ticked at first, and the page offers Select All / Deselect All. "Apply All" (or "Apply N") saves only the ticked changes and shows a toast with Undo; Cancel changes nothing. A split step keeps its video time and photo on its first part. X dismisses the card. A recipe found tidy or dismissed is not offered again until its ingredients, sections, steps or notes change. "Check all recipes in the background" (on by default) keeps a queue of every recipe not yet checked in its current form, new and edited ones included, and works through it one recipe at a time while the app is open, picking up recipes that join the queue mid-pass; Settings → Apple Intelligence shows how many are "Waiting to Be Checked". A recipe leaves the queue once checked, and joins it again whenever its ingredients, sections, steps or notes change, including after the user edits a dismissed or tidied recipe. Recipes to Tidy lists the ones with a cleanup waiting, each with Review and a Dismiss swipe. Settings → AI Improvements (also linked from Apple Intelligence) gathers it all: Suggest Improvements (key `suggestCleanups`), Check in the Background (key `scanLibraryForCleanups`), a switch for each kind of improvement (Tidy ingredients, Ingredient sections, Split and tidy steps, Move loose text into Notes; keys `cleanup.ingredients`, `cleanup.sections`, `cleanup.steps`, `cleanup.notes`, all on by default), Recipes to Tidy, and Waiting to Be Checked, which lists the recipes the check hasn't reached. A kind switched off is left out of every suggestion and its summary; a recipe whose only changes are switched off shows no card.

#### Scenario: Keep only some changes
- **GIVEN** a recipe whose ingredients include "0.5 cup milk" and "2 Tablespoons butter"
- **WHEN** the user opens Review, unticks the butter change and taps Apply 1
- **THEN** the recipe is saved with "1/2 cup milk" and "2 Tablespoons butter"

#### Scenario: Dismissed
- **GIVEN** the user tapped X on a recipe's card
- **WHEN** they open the recipe again without changing it
- **THEN** no card appears

### Requirement: Recipe PDF and Print
The system SHALL lay a recipe out as a PDF on US Letter at actual size, always in light mode on a white page with no background fills: the title, the summary, a facts line ("Serves N · Prep N min · Cook N min · Total N min"), a small photo when the recipe has one, and an accent rule; then "Ingredients" in a narrow left column (amounts in bold, preparation in grey italics, section subheadings) beside a numbered "Method", followed by "Notes". Type is the font chosen in Settings at 11–12pt, and the accent color appears only in rules, labels and step numbers. No ingredient or step is split across pages; a later page repeats the title and, once the ingredients are done, runs the steps full width. Each page's footer shows the source site and, on a recipe of more than one page, "N of M". The PDF reflects the scale the recipe is shown at. Print… prints this same PDF with the system print dialog on iPhone, iPad and Mac.

#### Scenario: Long recipe
- **GIVEN** a recipe with 19 ingredients and 12 steps
- **WHEN** the user shares it as a PDF
- **THEN** page 1 holds the header, every ingredient and the first steps, page 2 the rest of the steps and the notes, and the footers read "1 of 2" and "2 of 2"

### Requirement: Share options
The More menu's Share SHALL offer: "As a PDF" (the recipe PDF, named after the recipe), "As Text" (Markdown, below), "Original Recipe Link" when the recipe has a web source, and "Link in My Mealie" once the recipe has synced to the user's Mealie server from this device, which opens its page there (`/g/<group>/r/<slug>`, or `/recipe/<slug>` when the group isn't known).

#### Scenario: Not synced yet
- **GIVEN** Mealie is connected but the recipe hasn't synced from this device
- **WHEN** the user opens Share
- **THEN** "Link in My Mealie" is not listed

### Requirement: Share as Markdown
The system SHALL share a recipe as Markdown text: "# Title", the summary, a facts line ("Servings: N · Prep: N min · Cook: N min"), "Tags: …", "## Ingredients" as a bullet list with "### Section" subheadings, "## Steps" as a numbered list, "## Notes", and "Source: URL". For a YouTube recipe, a step with a timestamp ends with a link to that moment in the video ("[▶ m:ss](https://youtu.be/<id>?t=<seconds>)").

#### Scenario: Shared steps
- **WHEN** the user shares a recipe with steps "Boil water" and "Add pasta"
- **THEN** the text contains "## Steps", "1. Boil water" and "2. Add pasta"
