# share-extension Specification

## Purpose
"Save to Recipes" in the system share sheet on iOS, iPadOS and macOS: imports the shared web page or YouTube video, lets the user review it in the app's recipe editor, and saves it to the same library as the app without opening the app.

## Requirements

### Requirement: Share sheet entry
The extension SHALL appear in the share sheet as "Save to Recipes" when the shared items include one web URL or text.

#### Scenario: Sharing from Safari
- **WHEN** the user shares a recipe page from Safari
- **THEN** "Save to Recipes" is offered

### Requirement: Finding the link
The extension SHALL use the first shared http or https URL, and otherwise the first link found in shared text. With neither, it shows "Couldn't import that" with "No web page to import."

#### Scenario: Link inside text
- **WHEN** the user shares the text "Try this https://example.com/soup tonight"
- **THEN** the extension imports `https://example.com/soup`

#### Scenario: Nothing to import
- **WHEN** the shared text contains no link
- **THEN** the extension shows "Couldn't import that" and "No web page to import."

### Requirement: Import in the extension
The extension SHALL import the link the same way the app does (see web-import and youtube-import), showing "Reading recipe…", the site's host without `www.`, the progress steps and a cancel control while it works. A failed import shows "Couldn't import that" with the error and a Done button.

#### Scenario: Page without recipe data
- **WHEN** the shared page has no recipe data
- **THEN** the extension shows "Couldn't import that" and "No recipe found on that page."

### Requirement: Review before saving
After importing, the extension SHALL always open the app's recipe editor with the draft, its cover photo and step photos, whatever the app's "Review before saving" setting. An incomplete import shows its message, or "No full recipe was found. Check the details below." when it has none. Cancel closes the share sheet without saving.

#### Scenario: Incomplete video
- **WHEN** a YouTube video without a written recipe is shared and the model couldn't fill it in
- **THEN** the editor opens with the import's notice above the draft

### Requirement: Saving to the library
Saving SHALL write the recipe, its cover photo and step photos to the same library the app uses (see library-storage), then show "Recipe added!" and "<title> has been added to your cookbook." with the note "It will sync to your other devices through iCloud.", or the incomplete-import notice in orange instead when there was one. A save that fails shows "Couldn't import that" with the error.

#### Scenario: Saved
- **WHEN** the user taps Save in the extension's editor
- **THEN** the extension shows "Recipe added!" with the recipe's title
- **AND** the recipe appears in the app's library

### Requirement: Open in Recipes
The saved screen SHALL offer "Open in Recipes", which opens `recipes://recipe/<id>` (lowercase recipe ID) in the app and closes the share sheet, and "Done", which closes the share sheet.

#### Scenario: Jump to the recipe
- **WHEN** the user taps "Open in Recipes" after saving
- **THEN** the app opens on the saved recipe and the share sheet closes
