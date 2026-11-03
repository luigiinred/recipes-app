# reminders Specification

## Purpose
Optional local notifications that nudge the user to log dinner, plan next week, and add a recipe. All are off until the user turns one on in Settings > Reminders. Runs in the app on iPhone, iPad and Mac.

## Requirements

### Requirement: Off by default
The system SHALL schedule no reminders until the user turns at least one on; each of "Log dinner", "Plan next week" and "Add a recipe" starts off.

#### Scenario: Fresh install
- **WHEN** the app runs with default settings
- **THEN** no reminder notifications are scheduled

### Requirement: Reminder settings
The system SHALL offer in Settings > Reminders a toggle for each reminder and, while it is on, a time picker, plus a weekday picker for "Plan next week" and "Add a recipe". Defaults are Log dinner at 20:00 daily, Plan next week on Sunday at 17:00, and Add a recipe on Saturday at 10:00. A "Turn All Off" button turns every reminder off and is disabled when none is on.

#### Scenario: Turning one on
- **WHEN** the user turns on "Plan next week"
- **THEN** a Day picker set to Sunday and a Time picker set to 17:00 appear
- **AND** the other reminders stay off

### Requirement: Notification permission
The system SHALL ask for notification permission the first time a reminder is turned on when permission has not been decided. When notifications are denied, the page says none of the reminders will appear and offers "Open System Settings".

#### Scenario: Notifications denied
- **GIVEN** notifications are off for Recipes in system settings
- **WHEN** the user opens Settings > Reminders
- **THEN** the footer says none of these will appear and an Open System Settings button is shown

### Requirement: Bounded schedule
The system SHALL schedule only dated, non-repeating notifications a limited window ahead (the next 7 evenings for Log dinner, the next 4 occurrences for the weekly reminders), and replace every pending reminder whenever the app becomes active, the recipes or meal plan change, or a reminder setting changes, so reminders stop once the app goes unopened.

#### Scenario: Weekly window
- **GIVEN** "Plan next week" is on for Sunday 17:00
- **WHEN** reminders are scheduled
- **THEN** four notifications are pending, one on each of the next four Sundays at 17:00

### Requirement: Log dinner reminder
The system SHALL schedule "How was dinner?" at the chosen time each day, skipping times already past and skipping today when the user has already logged any cook today. When a dinner is planned that day the body is "Did you make <title> tonight? Log it so you remember how it went."; otherwise "What did you have for dinner? Log it in a couple of taps."

#### Scenario: Names the planned dinner
- **GIVEN** "Sunday Sauce" is planned for dinner today and Log dinner is on
- **WHEN** reminders are scheduled before 20:00
- **THEN** today's notification body mentions "Sunday Sauce"

#### Scenario: Already logged today
- **GIVEN** a recipe has a cook logged earlier today
- **WHEN** reminders are scheduled
- **THEN** the first Log dinner notification is tomorrow

### Requirement: Plan next week reminder
The system SHALL schedule "Plan next week" on the chosen weekday and time, and skip an occurrence when the seven days after it already have 3 or more planned meals. The body is "Take two minutes to plan next week's meals." when nothing is planned, or "You have N meal(s) planned for next week. Fill in the rest?" otherwise.

#### Scenario: Week already planned
- **GIVEN** three meals are planned in the seven days after the coming Sunday
- **WHEN** reminders are scheduled
- **THEN** the first Plan next week notification is the Sunday after

#### Scenario: Thin plan
- **GIVEN** one meal is planned for next week
- **WHEN** reminders are scheduled
- **THEN** the coming Sunday's notification says "You have 1 meal planned for next week. Fill in the rest?"

### Requirement: Add a recipe reminder
The system SHALL schedule "Add a recipe" on the chosen weekday and time, with a body that rotates by week through a fixed set of nudges to save a recipe from a link, a photo or a video.

#### Scenario: Weekly nudge
- **GIVEN** "Add a recipe" is on for Saturday
- **WHEN** reminders are scheduled
- **THEN** every pending Add a recipe notification falls on a Saturday

### Requirement: Opening from a reminder
The system SHALL, when the user taps a Log dinner or Plan next week notification, open Plan in My Week, and when they tap an Add a recipe notification, open the Recipes list with the import sheet showing.

#### Scenario: Tap Plan next week
- **WHEN** the user taps a Plan next week notification
- **THEN** the app shows Plan with My Week selected

### Requirement: Reminders while the app is open
The system SHALL show a reminder as a banner with sound when it fires while the app is in the foreground.

#### Scenario: Foreground delivery
- **GIVEN** the app is open
- **WHEN** the Log dinner time arrives
- **THEN** a banner with sound is shown
