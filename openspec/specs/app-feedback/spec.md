# app-feedback Specification

## Purpose
The app asks for an App Store rating once the user has a few recipes, and offers links to report a bug or suggest a change as a prefilled GitHub issue. Runs in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: When the rating banner is due
The system SHALL show the rating banner only after the welcome tour has been completed, while the banner has not been dismissed, and once the library holds at least five recipes that are not ideas (see recipe-format for ideas).

#### Scenario: Fifth recipe
- **GIVEN** the tour is completed and the library has four recipes with ingredients or steps
- **WHEN** the user saves a fifth
- **THEN** the rating banner appears

#### Scenario: Ideas don't count
- **GIVEN** four recipes and one idea with no ingredients or steps
- **THEN** the rating banner does not appear

#### Scenario: Tour not completed
- **GIVEN** five recipes and the tour never completed
- **THEN** the rating banner does not appear

### Requirement: Rating banner
The system SHALL show a "Rate us" banner with the line "Help other cooks find Recipes" and a dismiss button: on iPhone and iPad in compact width as an accessory above the tab bar, on iPad in regular width at the bottom of the recipe library, and on Mac at the bottom of the sidebar. Tapping the banner asks the system to show its App Store rating prompt; tapping it or dismissing it hides the banner for good.

#### Scenario: Rate
- **GIVEN** the rating banner is showing
- **WHEN** the user taps it
- **THEN** the system rating prompt is requested and the banner no longer appears

#### Scenario: Dismiss
- **WHEN** the user taps the banner's dismiss button
- **THEN** the banner disappears and does not come back

### Requirement: Review and share links in Settings
The system SHALL show a "Help Support Us" section in Settings with Leave a Review (the App Store write-review page) and Tell a Friend Who Cooks (sharing the App Store listing with a short message) only when the app's App Store ID is configured; without it the section is hidden.

#### Scenario: No App Store ID
- **GIVEN** the app is built without an App Store ID
- **WHEN** the user opens Settings
- **THEN** there is no Help Support Us section

### Requirement: Report a Bug and Suggest a Change
The system SHALL offer Report a Bug and Suggest a Change in a Feedback section of Settings, each opening a new issue on `https://github.com/luigiinred/recipes-app/issues/new` in the browser. A bug is labelled `bug`, titled "Bug: ", and its body asks "What happened?", "What did you expect?" and "Steps to reproduce"; a suggestion is labelled `enhancement`, titled "Idea: ", and asks "What would you like to change or add?" and "Why would it help?".

#### Scenario: Report a bug
- **WHEN** the user taps Report a Bug
- **THEN** a new GitHub issue opens labelled `bug` with a body containing "Steps to reproduce"

#### Scenario: Suggest a change
- **WHEN** the user taps Suggest a Change
- **THEN** a new GitHub issue opens labelled `enhancement`

### Requirement: Environment in the report
The system SHALL end each feedback issue body with a `---` line followed by `Recipes <version> (<build>) · <iOS|macOS> <system version>`, and SHALL include nothing from the user's recipes.

#### Scenario: Version details
- **GIVEN** app version 1.0, build 8, on iOS 26
- **WHEN** a feedback link is built
- **THEN** its body ends with "---\nRecipes 1.0 (8) · iOS 26"
