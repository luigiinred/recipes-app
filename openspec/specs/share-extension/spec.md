# share-extension Specification

## Purpose
"Save to Recipes" in the system share sheet on iOS, iPadOS and macOS: imports the shared web page or YouTube video, saves it (or lets the user review part of a recipe in the app's recipe editor), offers to follow the blog or channel behind it, and saves to the same library as the app without opening the app.

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

### Requirement: Preview before saving
After importing, the extension SHALL show the recipe as a read-only page (photo, title, summary, servings and times, ingredients under their section headings, numbered steps and notes) with Cancel in the navigation bar, the incomplete-import notice in a banner when there is one ("No full recipe was found. Check the details below." when it has no message), and Edit and Save Recipe floating at the bottom. Save Recipe saves the recipe with its photos and shows the saved screen; Edit opens the app's recipe editor with the draft; Cancel closes the share sheet without saving. A link already in the library (same source URL) shows the saved screen for that recipe with "It was already in your cookbook."

#### Scenario: Incomplete video
- **WHEN** a YouTube video without a written recipe is shared
- **THEN** the preview shows what was found under the notice, and Save keeps it so the app can find its recipe later

### Requirement: Follow the source
While importing a post or video, the extension SHALL look for the feed of whoever made it: a video's YouTube channel, or the feed a page links to (comment feeds are skipped), falling back to the site's front page. When one is found, the saved and failed screens offer "Follow <name>", which adds it to Feeds and then reads "Following <name>". A shared link to a channel, playlist, subreddit, site front page or feed itself still asks to follow it instead of importing.

#### Scenario: Recipe from a blog
- **WHEN** the user shares a recipe post from a blog that has a feed
- **THEN** the saved screen offers to follow the blog

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
