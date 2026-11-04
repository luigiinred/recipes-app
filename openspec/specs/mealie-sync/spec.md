# mealie-sync Specification

## Purpose
Optionally keeps the app's library in step with a user's own Mealie server: recipes with their main photo and timeline, planned meals and one shopping list, copied both ways. It runs in the app on iPhone, iPad and Mac (Settings, Mealie) and from the `recipes mealie` command on macOS; the library stays local-first and works without it.

## Requirements

### Requirement: Connecting with an address and API token
In Settings, Mealie, the app SHALL take a server address and a Mealie API token, check them by asking Mealie for the current user, and on success store the address, username and token and start syncing. Addresses are trimmed, get `https://` when they have no scheme, lose a trailing `/` or `/api`, and must be `http` or `https` with a host. A failed check shows its error under the Connect button and stores nothing.

#### Scenario: Address normalization
- **WHEN** the user enters `mealie.example.com` or `https://example.com/mealie/api/`
- **THEN** the app connects to `https://mealie.example.com` or `https://example.com/mealie`

#### Scenario: Rejected token
- **WHEN** Mealie refuses the token
- **THEN** the page shows "Mealie didn't accept the API token." and stays disconnected

### Requirement: Pairing shared through iCloud Keychain
The app SHALL keep the Mealie address, username and token in one iCloud Keychain item, so pairing one device pairs every device signed in to the same iCloud account and disconnecting (after confirmation) on one disconnects them all. Disconnecting stops syncing and forgets the token but leaves recipes in both places. The app picks up a pairing made or removed on another device when it becomes active and periodically while running. Which things sync (planned meals, groceries, the shopping list name) is chosen per device.

#### Scenario: Disconnect everywhere
- **GIVEN** two devices on the same iCloud account are paired
- **WHEN** the user disconnects on one
- **THEN** the other shows as disconnected after it next checks the pairing
- **AND** no recipes are deleted

### Requirement: Pairing link
The app SHALL open `recipes://mealie?server=<address>&token=<token>` links by asking "Connect to Mealie?" (or "Switch Mealie Server?" when already connected, noting it replaces the connection on every device on the iCloud account) with the server's host and a warning to continue only if the sender is trusted, and connect only after the user confirms. Links without a server, without a non-blank token, or with a non-`http(s)` server are ignored. A failed connection shows "Couldn't Connect to Mealie" with the reason.

#### Scenario: Opening a link
- **WHEN** the user opens `recipes://mealie?server=mealie.example.com/api&token=%20abc%20`
- **THEN** the app asks to connect to `mealie.example.com`
- **AND** confirming connects to `https://mealie.example.com` with token `abc`

#### Scenario: Incomplete link
- **WHEN** the user opens `recipes://mealie?server=https://m.example.com`
- **THEN** nothing is asked or changed

### Requirement: Share Access
While connected, the Mealie settings SHALL offer Share Access, which creates a new Mealie API token named "Recipes shared <date and time>" for the signed-in user and presents a sheet to send the pairing link for it, warning that anyone who opens it can read and change the Mealie recipes. The shared link never contains this device's own token, so deleting its token in Mealie revokes only that link.

#### Scenario: Sharing
- **WHEN** the user taps Share Access
- **THEN** a new API token appears in Mealie
- **AND** the sheet's Send Link shares a `recipes://mealie` link carrying that new token

### Requirement: When the app syncs
While connected, the app SHALL run a pass every 2 minutes, a few seconds after the recipes, meal plan or groceries change, when it becomes active, and on Sync Now. The settings page shows the server, the signed-in user and a status: waiting, syncing, "Synced <relative time>", "Synced with N problems" (listing up to three below), or the failure message.

#### Scenario: Edit triggers a pass
- **GIVEN** the app is connected
- **WHEN** the user edits a recipe
- **THEN** a sync pass runs within seconds

### Requirement: What a recipe carries
A recipe SHALL map to Mealie as: title, summary and servings to name, description and servings; prep and cook minutes to prep time and perform time (read from seconds, ISO 8601 durations or text such as `1 hr 15 min`); ingredients to ingredient text, with section titles as ingredient titles; steps to instructions; tags to tags, except those matching an existing Mealie category, which stay categories (Mealie categories come back as tags); source URL to `orgURL`; notes to a note titled "Notes" (other Mealie notes are read into the notes with their titles); star rating and favorite to the token user's rating and favorite (a Mealie rating of 0 means none). Step timestamps, the Up Next state and queue time, the photo URL and the app's recipe id are stored as JSON under `recipesApp` in the recipe's `extras`. Step photos stay on the device and follow their step when Mealie's steps are reordered.

#### Scenario: Reading a Mealie recipe
- **GIVEN** a Mealie recipe with `prepTimeSeconds` 600, `performTime` "1 hr", ingredient titles Base and Veg, and tag `Dinner / Soup`
- **WHEN** it is pulled
- **THEN** the app recipe has prep 10 and cook 60 minutes, sections Base and Veg, and tag `Dinner/Soup`

#### Scenario: Up Next survives a round trip
- **GIVEN** a queued recipe with step timestamps
- **WHEN** it is pushed to Mealie and read back
- **THEN** it is still queued with the same queue time and step timestamps

### Requirement: Pushing leaves Mealie's other data alone
When sending a recipe, the sync SHALL re-read it from Mealie and change only the mapped fields, keeping structured ingredients (food, unit, quantity) for lines it keeps, instruction ids and references, nutrition, other `extras` keys and every other field, and leave times unchanged when they already match. New ingredient lines reach Mealie as plain text notes.

#### Scenario: Structured ingredient kept
- **GIVEN** a Mealie ingredient with food "butter" displayed as "2 tbsp butter"
- **WHEN** the app pushes the recipe with that line unchanged and a new line "jam"
- **THEN** the butter ingredient keeps its food and "jam" is added as a note

### Requirement: Stable recipe ids across devices
A recipe pulled from Mealie SHALL get the app id stored in its `extras`, else Mealie's own id, else a new one, so every device gives it the same id. If another recipe here already has that id (for example a recipe duplicated in Mealie), the pulled recipe gets its own new id.

#### Scenario: Two devices agree
- **WHEN** two libraries each pull the same Mealie recipe
- **THEN** both save it with the same id, equal to Mealie's recipe id

#### Scenario: Duplicated in Mealie
- **GIVEN** a synced "Pasta" and a copy in Mealie carrying the same `extras`
- **WHEN** the next pass runs
- **THEN** the library has two recipes with different ids

### Requirement: Three-way comparison and conflicts
Each pass SHALL compare, per item, the library now, Mealie now and what both had after the last pass. A change on one side only is copied to the other. A recipe changed on both sides keeps the version with the later `updatedAt` and counts as a conflict; planned meals and grocery items have no edit date, so the app's version wins. An item deleted on one side and unchanged on the other is deleted on the other; if the other side edited it, the edit wins and the item comes back. A recipe changed locally while a pass runs is not overwritten; it is reported and synced on the next pass.

#### Scenario: Later edit wins
- **GIVEN** a synced recipe edited in Mealie and edited here with an older `updatedAt`
- **WHEN** the pass runs
- **THEN** the Mealie version is kept and one conflict is reported

#### Scenario: Edit beats deletion
- **GIVEN** a synced recipe deleted in Mealie and edited here
- **WHEN** the pass runs
- **THEN** the recipe is created in Mealie again

### Requirement: Per-device sync state
Each device SHALL keep its last-pass state in `Application Support/MealieSync/<key>.json`, keyed by library folder and server, outside the library so iCloud never shares it. Pointing at a different server, or a token for a different Mealie user, starts from empty state without deleting anything. Losing the state file is safe: recipes are matched again by the id in `extras` (and identical planned meals and grocery items by content), so nothing is duplicated. iCloud files not yet downloaded are skipped, not treated as deleted.

#### Scenario: State lost
- **GIVEN** a synced recipe
- **WHEN** the state file is deleted and a pass runs
- **THEN** nothing is sent, received or duplicated

#### Scenario: Another server
- **WHEN** the same library syncs with a different Mealie server
- **THEN** no local recipes are deleted and they are sent to the new server

### Requirement: Mass-deletion safeguard
A pass that would delete more than half of the synced recipes (or planned meals, or grocery items) and more than 10 SHALL stop with "This would delete N items, which looks like a mistake. Nothing was changed." In the app the settings page then offers Sync Anyway; on the command line `--allow-mass-deletion` lets it proceed.

#### Scenario: Library emptied locally
- **GIVEN** 30 synced recipes all deleted here
- **WHEN** a pass runs
- **THEN** it stops and the 30 recipes remain in Mealie
- **AND** a pass allowed to mass-delete removes them

### Requirement: Failures are per item
When Mealie refuses one recipe, planned meal, grocery item or photo, the pass SHALL record it in the report's problems and carry on with the rest; the next pass tries it again.

#### Scenario: One refused recipe
- **GIVEN** Mealie refuses recipe updates
- **WHEN** a pass runs
- **THEN** it finishes with one problem
- **AND** a later pass sends the recipe once Mealie accepts it

### Requirement: Photos
The recipe's main photo SHALL sync both ways: a new or changed photo here is uploaded, a changed photo in Mealie is downloaded and stored as JPEG, and removing it on one side removes it on the other.

#### Scenario: Photo deleted here
- **GIVEN** a synced recipe photo
- **WHEN** it is deleted in the app and a pass runs
- **THEN** the Mealie recipe has no image

### Requirement: Timeline
Each time-cooked event on a recipe's timeline SHALL sync with the recipe's Mealie timeline as an "info" event with the same time and note, and sending events sets the recipe's last-made date in Mealie to the newest event's time. Mealie "info" and "comment" events come back as timeline events; Mealie's own system events stay in Mealie. Events are matched by time (within a second) and note, so an event already in both places isn't duplicated, and deleting a matched event on one side deletes it on the other. Editing an event's note after it syncs isn't carried across.

#### Scenario: Cooked it
- **GIVEN** a recipe with a timeline event "Needed salt"
- **WHEN** a pass runs
- **THEN** Mealie's timeline for the recipe shows "Needed salt" and its last-made date is that event's time

#### Scenario: System events ignored
- **GIVEN** Mealie added a "Recipe created" system event and the user logged "Great with garlic"
- **WHEN** a pass runs
- **THEN** only "Great with garlic" is added to the app's timeline

### Requirement: Planned meals
When "Planned meals" is on (the default), planned meals SHALL sync with Mealie's meal plan by day and meal type (breakfast, lunch, dinner, snack); Mealie's other types (side, drink, dessert) arrive as snacks. Entries for a recipe link to its Mealie recipe; entries with only a title, such as ideas, sync by title. Entries whose recipe hasn't synced yet are left for a later pass.

#### Scenario: Drink becomes a snack
- **GIVEN** a Mealie meal plan entry of type drink titled "Wine"
- **WHEN** a pass runs
- **THEN** the app plans "Wine" as a snack on that day

### Requirement: Groceries
When "Groceries" is on (the default), grocery items SHALL sync with one Mealie shopping list named in Settings (default "Recipes"), matched by name case-insensitively and created if it doesn't exist. Items the app sends are written as a note reading "<quantity> <name>" with the app's name, quantity and recipe link kept in the item's `extras`; items made in Mealie are read from their food, quantity and unit, or note. Changing only whether an item is checked keeps Mealie's structured fields. Choosing a different list starts that list's pairing afresh.

#### Scenario: Grocery round trip
- **GIVEN** an app item "black beans" with quantity "500g" and a Mealie item "milk"
- **WHEN** a pass runs
- **THEN** Mealie's list reads "500g black beans" and "milk" and the app has both items

### Requirement: recipes mealie command
`recipes mealie` SHALL run the same sync for the library folder in use (see recipes-cli), taking the address from `--server` or `MEALIE_URL` and the token from `MEALIE_TOKEN` only, with `--list <name>` (default "Recipes"), `--skip-meal-plan`, `--skip-groceries`, `--allow-mass-deletion` and `--json`. It prints sent, received, deleted in Mealie and deleted here counts for recipes, photos, meal plan, groceries and timeline, conflicts when there are any, and each problem.

#### Scenario: Missing token
- **WHEN** the user runs `recipes mealie --server https://mealie.example.com` without `MEALIE_TOKEN`
- **THEN** it fails asking to set `MEALIE_TOKEN` to an API token from Mealie
