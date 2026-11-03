# cook-timers Specification

## Purpose
Cook timers are started from durations found in a recipe's steps and ring when they finish. On iPhone and iPad they run as system alarms with a Live Activity on the Lock Screen and Dynamic Island; on Mac they use notifications.

## Requirements

### Requirement: Durations found in step text
The system SHALL find durations in step text written as a number (whole or decimal, with `.` or `,`) followed by an hour, minute or second unit (`hour`, `hours`, `hr`, `hrs`, `minute`, `minutes`, `min`, `mins`, `second`, `seconds`, `sec`, `secs`, case-insensitive). A range (`15-20`, `15–20`, `15 to 20`) uses its upper bound, and a following minutes or seconds amount (optionally after "and") is added to the same timer. Zero durations are ignored.

#### Scenario: Simple duration
- **WHEN** a step reads "Simmer for 10 minutes."
- **THEN** one timer of 600 seconds is found

#### Scenario: Compound and separate durations
- **WHEN** a step reads "Bake 1 hour 30 minutes, then rest 5 min"
- **THEN** two timers are found, of 5400 and 300 seconds

#### Scenario: Range and decimal
- **WHEN** steps read "Cook 15-20 mins" and "Boil 1.5 hours"
- **THEN** timers of 1200 and 5400 seconds are found

#### Scenario: Not a duration
- **WHEN** a step reads "Add 2 cups flour"
- **THEN** no timer is found

### Requirement: Starting a timer
The system SHALL start a timer when the user taps a timer pill in cook mode (see cook-mode), for the pill's duration, labelled "<recipe title> · step <N>" and linked to that recipe. Several timers can run at once.

#### Scenario: Tap a pill
- **GIVEN** step 2 of "Tomato Soup" reads "Simmer for 10 minutes"
- **WHEN** the user taps the "10 minutes" pill
- **THEN** a 10:00 timer labelled "Tomato Soup · step 2" starts

### Requirement: Timer chips
The system SHALL show each running timer in cook mode as a chip with its remaining time (`m:ss`, or `h:mm:ss` from one hour), its label and a close button. A finished timer's chip reads "Done" and is filled with the accent color until dismissed; the close button cancels a running timer or dismisses a finished one.

#### Scenario: Timer finishes
- **GIVEN** a running timer in cook mode
- **WHEN** its time runs out
- **THEN** its chip reads "Done" in an accent-filled capsule

#### Scenario: Cancel a timer
- **WHEN** the user taps the close button on a running timer's chip
- **THEN** the chip disappears and the timer will not ring

### Requirement: Alarms on iPhone and iPad
On iPhone and iPad, the system SHALL schedule each timer as a system alarm, asking for alarm permission the first time, so it rings through silent mode and Focus. The alert shows the timer's label with a Stop button and, for a timer linked to a recipe, a Cook Mode button that opens the app in cook mode for that recipe.

#### Scenario: Phone is silenced
- **GIVEN** alarms are allowed and the ring/silent switch is set to silent
- **WHEN** a timer finishes
- **THEN** the timer rings as an alarm

#### Scenario: Open cook mode from the alert
- **WHEN** the user taps Cook Mode on a finished timer's alert
- **THEN** the app opens in cook mode on the timer's recipe

### Requirement: Notification fallback
The system SHALL deliver a notification titled "Timer done" with the timer's label as its body and the default sound when a timer finishes, if notification permission is granted, on Mac always and on iPhone and iPad when alarms are not allowed. Tapping the notification opens cook mode for the timer's recipe. Cancelling the timer removes the pending notification.

#### Scenario: Alarms declined on iPhone
- **GIVEN** the user declined alarm permission but allowed notifications
- **WHEN** a timer finishes
- **THEN** a "Timer done" notification appears with the timer's label

#### Scenario: Timer on Mac
- **GIVEN** the app runs on Mac with notifications allowed
- **WHEN** a timer finishes
- **THEN** a "Timer done" notification is delivered

### Requirement: Live Activity
On iPhone and iPad, the system SHALL show each alarm-backed timer as a Live Activity on the Lock Screen and in the Dynamic Island with a timer symbol, the label and a live countdown; when it fires the Lock Screen view reads "Timer done" and the countdown shows "Done". Tapping the Live Activity of a timer linked to a recipe opens `recipes://cook/<id>`.

#### Scenario: Glance at the Lock Screen
- **GIVEN** a running 10-minute timer
- **WHEN** the user locks the phone
- **THEN** the Lock Screen shows the timer's label and its remaining time counting down

#### Scenario: Tap the Live Activity
- **WHEN** the user taps a timer's Live Activity
- **THEN** the app opens in cook mode on that timer's recipe

### Requirement: Timers outlive the app
On iPhone and iPad, the system SHALL save running timers and restore them on relaunch when the system still holds their alarm, and SHALL remove a timer from the app when its alarm is stopped or removed outside the app, such as from the Lock Screen.

#### Scenario: Relaunch with a timer running
- **GIVEN** a running alarm-backed timer
- **WHEN** the app is quit and relaunched before it finishes
- **THEN** the timer's chip shows again with the correct remaining time

#### Scenario: Stopped from the Lock Screen
- **GIVEN** a timer that has fired
- **WHEN** the user taps Stop on the Lock Screen alert
- **THEN** the timer's chip is gone from cook mode
