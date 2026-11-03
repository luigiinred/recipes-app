# onboarding Specification

## Purpose
A welcome tour introduces the app and helps the user import a first recipe, and a cast of animated food mascots gives empty, loading and welcome screens their character. Both run in the app on iPhone, iPad and Mac; the mascots also appear in the Share extension.

## Requirements

### Requirement: When the tour shows
The system SHALL show the welcome tour once, after the library first loads, if the tour has not been completed and the library is empty; a library that already has recipes marks the tour completed without showing it. The tour covers the full screen on iPhone and iPad and opens as a 560 by 700 point sheet on Mac, and cannot be swiped away. Settings > Show Welcome Tour replays it at any time.

#### Scenario: First launch
- **GIVEN** a fresh install with an empty library
- **WHEN** the app finishes loading the library
- **THEN** the welcome tour opens

#### Scenario: Existing library
- **GIVEN** the tour was never completed and the library has recipes
- **WHEN** the app launches
- **THEN** the tour does not open and will not open on later launches

#### Scenario: Replay
- **WHEN** the user taps Show Welcome Tour in Settings
- **THEN** the tour opens on its first page

### Requirement: Tour pages
The system SHALL present seven pages in order: welcome ("Good food happens here."), Save any recipe (a mock share sheet with Save to Recipes highlighted and four numbered steps), Keep it organized, Cook with confidence, Let's add your first recipe!, Make it yours, and You're all set!. Page dots show the position. The primary button reads "Get Started" on the first page, "Next" on the next three, "Continue" on the add and try pages, and "Start Cooking" on the last, which finishes the tour.

#### Scenario: Walk through
- **GIVEN** the tour on the welcome page
- **WHEN** the user taps Get Started
- **THEN** the Save any recipe page is shown with a Next button

#### Scenario: Finish
- **GIVEN** the tour on the You're all set! page
- **WHEN** the user taps Start Cooking
- **THEN** the tour closes and is marked completed

### Requirement: Skipping
The system SHALL offer Skip Tour on every page except the last, which closes the tour and marks it completed.

#### Scenario: Skip early
- **WHEN** the user taps Skip Tour on the welcome page
- **THEN** the tour closes and does not open again on its own

### Requirement: Tour recipe sources
The system SHALL offer four real sources on the add page as photo cards: "World's Best Lasagna" (AllRecipes), "Easy Pancakes" (BBC Good Food), "White Chocolate Chip Cookies" (YouTube · Preppy Kitchen) and "Perfect Scrambled Eggs" (YouTube · Gordon Ramsay), loading their previews and cover photos in the background when the tour opens. A card whose recipe is already in the library, matched by source link (by video id for YouTube), shows a checkmark and its saved photo and cannot be tapped again.

#### Scenario: Video already saved with a different link
- **GIVEN** the library has a recipe whose source is the Scrambled Eggs video link with `&t=30s` appended
- **WHEN** the add page is shown
- **THEN** the Scrambled Eggs card shows as added

### Requirement: Importing a first recipe
The system SHALL import a tapped source card through the normal review step (see web-import and youtube-import), showing a loading card with Cancel while the import runs if its preview is not ready, and showing a failed import's error on the card. Continue stays disabled, with the note "Add at least one recipe to continue.", until at least one tour recipe is saved.

#### Scenario: Import a card
- **GIVEN** the add page with no tour recipes saved
- **WHEN** the user taps "Easy Pancakes" and saves it from the review screen
- **THEN** the card shows a checkmark
- **AND** Continue becomes enabled

#### Scenario: Nothing saved yet
- **GIVEN** the add page with no tour recipes saved
- **THEN** Continue is disabled and "Add at least one recipe to continue." is shown

### Requirement: Trying features on the saved recipe
The system SHALL show the first saved tour recipe on the Make it yours page with two actions: adding it to or removing it from Up Next, and adding its ingredients to Groceries (shown as "Added to Groceries" once any of its ingredients is on the list). If no tour recipe is saved the page shows "No recipe yet".

#### Scenario: Add to Up Next from the tour
- **GIVEN** a tour recipe was saved
- **WHEN** the user taps Add to Up Next on the Make it yours page
- **THEN** the recipe joins Up Next and the button reads "In Up Next"

### Requirement: Mascot characters and scenes
The system SHALL draw four mascot characters (tomato, potato, lemon, chili) and decorative produce (basil, garlic, broccoli, carrot, pea pod, red pepper) at runtime from rigged SVG artwork bundled with the app, animating them in looping scenes: idle, wave, hop, sour (lemon only; other characters hop), stir-fry in a wok, holding an empty wok, and paging through or writing in a book. Mascots are hidden from VoiceOver.

#### Scenario: Animated by default
- **GIVEN** Reduce Motion is off
- **WHEN** a screen with a mascot is shown
- **THEN** the mascot plays its scene in a loop

### Requirement: Reduce Motion
The system SHALL hold every mascot and produce decoration on a single still frame, chosen per scene, when Reduce Motion is on.

#### Scenario: Reduce Motion on
- **GIVEN** Reduce Motion is turned on
- **WHEN** an empty state with a waving mascot is shown
- **THEN** the mascot is drawn still, mid-wave

### Requirement: Loading mascots
The system SHALL show a mascot tossing veggies in a wok while something loads: importing a link in the app or the Share extension, reading a scan, Smart Plan, and the first library load ("Syncing recipes…"). Loading and empty-state mascots pick a random character, never the same one twice in a row.

#### Scenario: Importing a link
- **WHEN** the user pastes a recipe link and the import is running
- **THEN** a mascot stir-frying in a wok is shown above the import progress

#### Scenario: Different face each time
- **WHEN** two loading screens appear one after another
- **THEN** they show different characters

### Requirement: Empty-state mascots
The system SHALL show a mascot with a title and message on empty screens: no recipes yet, an empty collection or category, the Search tab before typing, an empty Up Next, an empty grocery list, cook mode with nothing to cook, and Smart Plan with nothing to plan (the lemon, puckering at something sour). The welcome tour shows the tomato waving among its friends on its first and last pages.

#### Scenario: Empty library
- **GIVEN** the library has loaded with no recipes
- **WHEN** the recipe list is shown
- **THEN** a waving mascot appears over "No recipes yet"
