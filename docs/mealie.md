# Syncing with Mealie

The app can keep its library in step with a [Mealie](https://github.com/mealie-recipes/mealie) server. It is optional: the app stays local-first, reads and writes the same JSON files with or without it, and works offline. Mealie is one more place those files are copied to and from.

The sync code is `MealieSync` in `apps/ios/Sources/RecipeKit/Mealie`, shared by the app and the `recipes mealie` command. It is separate from the [file sync protocol](sync-protocol.md), which only talks to this repo's own server.

## Connecting

In Mealie, open your profile, choose **API Tokens** and create one. In the app, go to Settings, Mealie, and enter the server address and token. The address and token are kept in one iCloud Keychain item, so pairing one device pairs every device signed in to the same iCloud account, and disconnecting on one disconnects them all. Which things sync (planned meals, groceries, the shopping list name) is still chosen per device. Use `https://`; plain `http://` only works for servers on your local network.

To pair another device, open Settings, Mealie and tap **Share Access**. The app makes a new API token named "Recipes shared <date>" and sends a `recipes://mealie?server=<address>&token=<token>` link for it; opening the link on a device with the app asks before connecting. Anyone who opens the link can read and change your Mealie recipes, so send it only to people you trust. To revoke it, delete that token under API Tokens in Mealie; your own devices keep working. The link only works once the app is installed; if it isn't, install the app and open the link again.

From a terminal:

```bash
export MEALIE_URL=https://mealie.example.com MEALIE_TOKEN=...
recipes mealie            # --skip-meal-plan, --skip-groceries, --list "Name", --json
```

## What syncs

| In the app | In Mealie |
|---|---|
| Recipe title, summary, servings | name, description, servings |
| Prep and cook minutes | prep time and perform time (read from seconds or text) |
| Ingredients and their sections | ingredient text and ingredient titles |
| Steps | instructions |
| Tags | tags (and categories, which stay categories) |
| Source URL | `orgURL` |
| Notes | a note titled "Notes" |
| Star rating, favorite | your rating and favorite (per user) |
| Main photo | recipe image |
| Timeline (the times you cooked it, with notes) | the recipe's timeline: "info" and "comment" events, and its last-made date |
| Planned meals, ideas | meal plan entries (breakfast, lunch, dinner, snack) |
| Groceries | one shopping list, named in Settings (default "Recipes") |

Mealie's own system events (recipe created, updated) stay in Mealie. An event is matched by its time and note, so a recipe already in both places doesn't gain duplicates, and deleting an event on one side deletes it on the other. Editing an event's note after it syncs isn't carried across.

Step timestamps, the Up Next queue and the recipe's photo URL have no place in Mealie, so they are stored in the recipe's `extras` under `recipesApp`. That is also what lets every device give a recipe the same id. Step photos stay on the device; Mealie has no per-step photos.

## How a pass works

Mealie has no change feed or ETags, so each device keeps the state both sides had after its last pass in `Application Support/MealieSync/<key>.json` (per library and server, outside the library folder, so iCloud never shares it between devices). A pass compares the library, Mealie and that state for every item.

- Changed on one side only: the change is copied across.
- Recipe changed on both: the later `updatedAt` wins. Meal plan and grocery items have no edit date, so the app's version wins.
- Deleted on one side and unchanged on the other: the deletion is copied. If the other side edited it, the edit wins and the item comes back.
- Pushing re-reads the recipe from Mealie and changes only the fields above, so Mealie's nutrition, tools, structured ingredients (food, unit, quantity) and anything else it holds are left as they were.
- A pass that would delete more than half of what was synced (and more than 10 items) stops and asks first.
- Losing the state file is safe: recipes are matched again by the id in `extras`, so nothing is duplicated.

## Limits

- Ingredients the app writes reach Mealie as plain text (its "note"), not parsed into food and unit.
- Mealie's other meal types (side, drink, dessert) show up in the app as snacks.
- Several Mealie households or shopping lists are not browsed; the app uses the list whose name you give it.
- Ratings and favorites belong to the user the token was made for.

## Trying it locally

```bash
docker run -d -p 9925:9000 -e ALLOW_SIGNUP=false ghcr.io/mealie-recipes/mealie:latest
# sign in at http://localhost:9925 (changeme@example.com / MyPassword), then create an API token
```

`swift test` covers the sync against an in-memory Mealie (`FakeMealie`), so it needs no server.
