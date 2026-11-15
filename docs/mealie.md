# Syncing with Mealie

The app can keep its library in step with a [Mealie](https://github.com/mealie-recipes/mealie) server. It is optional: the app stays local-first, reads and writes the same JSON files with or without it, and works offline. Mealie is one more place those files are copied to and from.

The sync code is `MealieSync` in `apps/ios/Sources/RecipeKit/Mealie`, shared by the app and the `recipes mealie` command. It is separate from the [file sync protocol](sync-protocol.md), which only talks to this repo's own server.

## Connecting

In Mealie, open your profile, choose **API Tokens** and create one. In the app, go to Settings, Mealie, and enter the server address and token. The address and token are kept in one iCloud Keychain item, so pairing one device pairs every device signed in to the same iCloud account, and disconnecting on one disconnects them all. Which things sync (planned meals, groceries, the shopping list name) is still chosen per device. Use `https://`; plain `http://` only works for servers on your local network.

## Sharing

Settings, **Mealie Sharing** makes a link three ways. Each opens Recipes and sets everything up; the sheet that shows it can send it, copy it, or open it on the same device to try it.

- **Add a New User** makes a one-use invitation to your household (`POST /api/households/invitations`, or `/api/groups/invitations` on older servers) and a `recipes://mealie-invite?server=<address>&token=<invitation>` link. Opening it asks for a name, email, username and password, signs the new user up, signs in as them, makes them an API token and syncs as them.
- **Share This Account** makes a new API token named "Recipes shared <date>" and a `recipes://mealie?server=<address>&token=<token>` link. Opening it asks before connecting, and whoever opens it can read and change your Mealie recipes as you.
- **Share Read-Only** makes a token named "Recipes Discover shared <date>" and a `recipes://discover?…` link that adds the server to Discover.

Revoke an account or read-only link by deleting its token under API Tokens in Mealie; your own devices keep working. Links only work once the app is installed.

## Discover

Discover browses a Mealie server without syncing with it. Servers come from a Share Read-Only link or from **Add Server** (Settings, Mealie Sharing, or the + on the Discover tab), by address and token. The same server can be added more than once, each with its own name, and **Use the Server I Sync With** fills in your own connection so you can see your recipes the way someone you share them with would. Servers are kept in the iCloud Keychain like your own connection, so they appear on every device.

A server needs no token when its group is public: paste the group's page (`https://mealie.example.com/g/<group>`) and leave the token empty. Recipes then reads Mealie's public explore API (`/api/explore/groups/<group>/recipes`), which shows only recipes marked public in households that aren't private. A Share Read-Only link for such a server is `recipes://discover?server=<address>&group=<group>`.

A library search also lists up to five matches from each Discover server after your own recipes, read from the server the first time you search.

Added servers are listed under **Mealie Servers** on the Discover tab (and can also be a Home section, or a sidebar section on Mac). Inside, the server's recipes have the same collections, categories and recipe pages as your own, but nothing can be edited, rated, queued or planned. **Add to My Recipes** (a recipe's toolbar or a row's context menu) saves a copy with its photo as a new recipe of yours. The list is read from Mealie's recipe list and each recipe is read in full when it's opened. Ratings, favorites and the Up Next queue on the server belong to its owner and are left out.

The app never writes with a Discover token, but Mealie tokens carry the full rights of the user who made them, so the token itself could change that user's recipes. Share it only with people you trust.

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
