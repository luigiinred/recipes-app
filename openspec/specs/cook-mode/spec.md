# cook-mode Specification

## Purpose
Cook mode shows a recipe one step at a time in large type, with the ingredients close by, timers you can start from the step text, and the screen kept awake. It runs in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: Entering cook mode
The system SHALL open cook mode for a recipe from the Cook button on its page, from the Cook item on an Up Next entry, and from requests routed to cook mode (a `recipes://cook/<id>` link, the Start Cooking intent, a timer alert or a timer notification). A request that arrives before the library has loaded starts cook mode once it has. The Cook button is disabled for a recipe with no steps and is not shown for an idea. On iPhone and iPad cook mode covers the full screen; on Mac it is a sheet.

#### Scenario: Start from the recipe page
- **GIVEN** a recipe with steps
- **WHEN** the user taps Cook on its page
- **THEN** cook mode opens on that recipe

#### Scenario: Recipe without steps
- **GIVEN** a recipe that has ingredients but no steps
- **WHEN** the user views its page
- **THEN** the Cook button is disabled

#### Scenario: Open from a link
- **WHEN** the app opens `recipes://cook/<id>` for a recipe in the library
- **THEN** cook mode opens on that recipe

#### Scenario: Link opens the app from cold
- **GIVEN** the app is not running
- **WHEN** the user taps a timer's Live Activity linked to a recipe
- **THEN** the app launches and cook mode opens on that recipe once the library has loaded

### Requirement: Scaled amounts
The system SHALL show ingredient amounts in cook mode at the scale chosen on the recipe page when cook mode was started, and at 1× when started from anywhere else. See ingredient-scaling for how amounts scale.

#### Scenario: Cooking a doubled recipe
- **GIVEN** the recipe page's Scale menu is set to 2×
- **WHEN** the user taps Cook
- **THEN** the ingredient list and the step ingredient lists in cook mode show doubled amounts

### Requirement: One step at a time
The system SHALL show one step per page with a "Step N of M" caption in accent-colored small capitals above the step text, which is drawn at 28 points on narrow (under 500 points wide) or short (under 500 points tall, wide layout) windows and at 36 points otherwise. On Mac the Left and Right arrow keys move to the previous and next step. A recipe with no steps shows "No steps".

#### Scenario: Arrow keys on Mac
- **GIVEN** cook mode on step 2 on Mac
- **WHEN** the user presses the Left Arrow key
- **THEN** step 1 is shown

### Requirement: Cookbook pages on iPhone and iPad
On iPhone and iPad, the system SHALL draw each step as a cookbook page, in the theme's page color or warm paper by default and shaded along the spine, with the step number at the bottom, and SHALL turn between steps with a page curl when the user swipes.

#### Scenario: Swipe to the next step
- **GIVEN** cook mode on step 1 of 4 on iPhone
- **WHEN** the user swipes left
- **THEN** the page curls over to step 2, captioned "Step 2 of 4" with the number 2 at its foot

### Requirement: Step position
The system SHALL show the recipe title and, for recipes with more than one step, a row of step dots in the title area, one per step and at most nine at a time centered on the current step; tapping a dot jumps to that step. The step reached is remembered per recipe while the app runs, so reopening cook mode on the same recipe returns to it.

#### Scenario: Jump with the dots
- **GIVEN** a recipe with 5 steps open in cook mode on step 1
- **WHEN** the user taps the fourth dot
- **THEN** step 4 is shown

#### Scenario: Return to where you were
- **GIVEN** the user closed cook mode on step 3 of a recipe
- **WHEN** they open cook mode on the same recipe again without relaunching the app
- **THEN** step 3 is shown

### Requirement: Highlights in the step text
The system SHALL mark each duration found in a step (see cook-timers) as a tappable timer pill showing a timer symbol and the duration as written, and SHALL show ingredient names mentioned in the step in bold accent color, except where they overlap a duration.

#### Scenario: Timer and ingredient in one step
- **GIVEN** a recipe with the ingredient "1 onion" and the step "Fry the onion for 5 minutes"
- **WHEN** that step is shown in cook mode
- **THEN** "onion" is bold in the accent color
- **AND** "5 minutes" appears as a timer pill

### Requirement: Ingredients for this step
The system SHALL list, under the step text in large type, the recipe's ingredients the step mentions, under the heading "FOR THIS STEP", and SHALL show the step's photo below it when the step has one. Steps that mention no ingredient show no such list. Pressing and holding an ingredient offers unit conversions (see unit-conversion).

#### Scenario: Step that uses two ingredients
- **GIVEN** a step that mentions flour and butter, both in the ingredient list
- **WHEN** the step is shown
- **THEN** a "FOR THIS STEP" panel lists the flour and butter lines

### Requirement: Ingredient checklist
The system SHALL offer a checklist of all ingredients, grouped under their section headings, where tapping a line toggles a checkmark and strikes it through. On windows at least 860 points wide the checklist sits in a side column beside the steps; on narrower windows a floating Ingredients button opens it in a sheet, and the button is disabled when the recipe has no ingredients.

#### Scenario: Check off an ingredient on iPhone
- **GIVEN** cook mode on iPhone
- **WHEN** the user taps the floating Ingredients button and taps "2 eggs"
- **THEN** "2 eggs" shows a filled checkmark and is struck through

#### Scenario: Wide window
- **GIVEN** cook mode in a window 1000 points wide
- **THEN** the ingredient checklist is shown beside the step without a floating button

### Requirement: Two-page spread on an unfolded iPhone Duo
On an unfolded iPhone Duo held like a book, the system SHALL lay cook mode out as a two-page spread: the ingredient checklist fills the page left of the fold and the step the page right of it, with nothing on the fold and no floating Ingredients button.

#### Scenario: Unfolded iPhone Duo
- **GIVEN** an unfolded iPhone Duo held like a book
- **WHEN** cook mode opens
- **THEN** the ingredient checklist is on the left page and the step on the right page

### Requirement: Video alongside the steps
The system SHALL show a small player for a recipe with a YouTube video at the top of cook mode, starting at the current step's timestamp; once the video is playing, moving to another step that has a timestamp jumps the video to it. Video playback on the recipe page pauses when cook mode opens. See youtube-import for step timestamps.

#### Scenario: Move to the next step with the video open
- **GIVEN** a video recipe whose step 2 has a timestamp of 95 seconds, with the cook mode player playing
- **WHEN** the user moves to step 2
- **THEN** the video plays from 1:35

### Requirement: Screen stays awake
The system SHALL keep the screen from dimming or locking while cook mode is open when the Cooking setting "Keep the screen awake" is on, which it is by default, and SHALL restore normal sleep when cook mode closes.

#### Scenario: Default setting
- **GIVEN** the user has not changed "Keep the screen awake"
- **WHEN** cook mode stays open for longer than the auto-lock interval
- **THEN** the screen does not lock

#### Scenario: Setting turned off
- **GIVEN** "Keep the screen awake" is off
- **WHEN** cook mode is open
- **THEN** the screen locks on the normal schedule

### Requirement: Running timers in view
The system SHALL show running cook timers as a horizontal strip of chips at the bottom of cook mode whenever any exist (see cook-timers), and SHALL close cook mode from its Close button.

#### Scenario: Close cook mode
- **WHEN** the user taps Close in cook mode
- **THEN** cook mode closes and the screen beneath is shown
