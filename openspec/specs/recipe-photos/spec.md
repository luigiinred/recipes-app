# recipe-photos Specification

## Purpose
Gives each recipe a cover photo and each step an optional photo: imported with the recipe, picked from the photo library, or created with Image Playground. Photos are stored as JPEG files beside the recipe JSON and shown on recipe cards, the recipe page and in cook mode, on iOS, iPadOS and macOS.

## Requirements

### Requirement: Photo files
The library SHALL store a recipe's cover photo as `Images/<recipe id>.jpg` and each step photo as `StepImages/<photo id>.jpg`, with IDs as lowercase UUIDs. A recipe's `stepImages` field lists a photo ID or null for each step, parallel to `steps`; a recipe file without the field has no step photos. Deleting a recipe deletes its cover photo and step photos. File layout and sync belong to library-storage.

#### Scenario: Import with step photos
- **GIVEN** an import whose three steps have photos for the first and third step
- **WHEN** it is saved
- **THEN** `stepImages` has three entries with null in the middle and two files are written to `StepImages`

#### Scenario: Recipe deleted
- **WHEN** a recipe with a cover and step photos is deleted
- **THEN** its `Images` and `StepImages` files are removed

### Requirement: Step photos stay with their steps
When standardizing drops an empty step, the system SHALL drop that step's photo entry too, so every remaining photo stays on its step. When the editor's cleanup changes the number of steps, step times and step photos are cleared and the user is told "cleared step times and photos because the steps changed".

#### Scenario: Empty step dropped
- **GIVEN** steps "One", " ", "Three" with a photo on each
- **WHEN** the recipe is standardized
- **THEN** the steps are "One." and "Three." with the first and third photos

### Requirement: JPEG normalization
Every photo the app stores SHALL be re-encoded as JPEG at quality 0.82 with its longest side at most 1600 pixels, applying the source's orientation. Downloaded photos are fetched over http or https only, within 15 seconds, and must be under 15 MB with a 2xx status; anything else is skipped and the recipe is kept without that photo.

#### Scenario: Large photo picked
- **WHEN** the user picks a 4000×3000 photo
- **THEN** the stored JPEG is 1600×1200

### Requirement: Letterbox trimming
When the app scales a photo, it SHALL crop black bars that appear on both opposite edges (top and bottom, or left and right), such as those baked into YouTube's 4:3 thumbnails, when each bar is at least 1/33 of that side (and at least 2 pixels) and at least half the picture remains. A dark band on one edge only is kept.

#### Scenario: Bars above and below
- **WHEN** a 120×90 image has black rows 0–11 and 78–89
- **THEN** the result is 120×66

#### Scenario: One dark edge
- **WHEN** a 120×90 image is black only in its top 20 rows
- **THEN** the image is left at 120×90

### Requirement: Cover photo in the editor
The recipe editor SHALL have a Photo section with "Add Photo" (or "Change Photo") from the photo library, "Remove Photo" when there is one, and "Create with Image Playground" where Image Playground is supported. Photo changes are saved with the recipe and discarded on cancel.

#### Scenario: Removing a photo
- **GIVEN** a recipe with a cover photo
- **WHEN** the user taps "Remove Photo" and saves
- **THEN** the recipe's `Images` file is deleted

### Requirement: Step photos in the editor
Each step in the editor SHALL have a control to add or change a step photo from the photo library (labelled "Add step photo" or "Change step photo" for accessibility) and to remove it. Step photos show under the step on the recipe page and in cook mode.

#### Scenario: Adding a step photo
- **WHEN** the user picks a photo for step 2 and saves
- **THEN** step 2 shows that photo on the recipe page

### Requirement: Create a photo with Image Playground
Where Image Playground is supported, the system SHALL let the user create a cover photo from the editor, and from the recipe page's More menu as "Create a Photo…" when the recipe has no photo. The sheet is seeded with the recipe title and a description of the dish: the title, summary, up to eight main ingredients (skipping pantry staples such as salt, pepper, water, oils, sugar, flour, butter and "to taste"), up to two cooking methods found in the steps (for example "baked", "roasted"), the last serving or garnish sentence ("Presented: …"), and the recipe's categories other than YouTube. The chosen image is saved as the cover photo.

#### Scenario: Seeded description
- **GIVEN** a recipe "Roast Chicken" with "1 whole chicken", "2 tsp salt", "1 lemon" and a step "Roast for 1 hour, then serve with greens."
- **WHEN** the user opens "Create a Photo…"
- **THEN** the description's "Made with …" list names the chicken and lemon but not salt
- **AND** it includes "The dish is roasted." and "Presented: Roast for 1 hour, then serve with greens."

#### Scenario: Photo already set
- **GIVEN** a recipe that has a cover photo
- **WHEN** the user opens the More menu
- **THEN** "Create a Photo…" is not shown

### Requirement: Showing photos
Recipe cards, the recipe page and the video poster SHALL show the cover photo scaled to fill, loaded from a thumbnail no larger than 1200 pixels and refreshed when the photo file changes. A recipe without a photo shows a soft accent-colored gradient with a fork-and-knife symbol. Photos are decorative and hidden from accessibility.

#### Scenario: No photo
- **WHEN** a recipe without a photo is shown as a card
- **THEN** the card shows the gradient placeholder
