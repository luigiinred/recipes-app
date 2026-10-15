# Design system

What the app does today, taken from the code. Where a value is a choice rather than something the code enforces, it says so. SwiftUI only: there is no asset-catalog color, no custom font, and no shared spacing token beyond `Theme.accent`.

## Principles

- **Native first.** System fonts, system materials, system controls, Liquid Glass on iOS 26. We add a serif for recipe titles and one accent color, and little else.
- **Photos carry the color.** Chrome stays neutral so recipe photos are the most colorful thing on screen.
- **Dynamic Type by default.** Text uses semantic styles (`.headline`, `.caption`) rather than point sizes, so it follows the user's text size.
- **Light and dark** both ship. Colors come from semantic styles (`.primary`, `.secondary`) except the accent.

## Color

### App

| Role | Value | Where |
|---|---|---|
| Accent | `Theme.accent` = sRGB `0.86, 0.28, 0.22` (`#DB4738`, a tomato red) | Cook-mode timer chips and progress, prominent glass buttons, ingredient "ready" state, placeholder photo tint |
| Text | `.primary`, `.secondary`, `.tertiary` | All text. `.secondary` is the most used style by far (about 40 uses) |
| Surfaces | System backgrounds, `.regularMaterial`, `.bar`, glass | Lists and grouped screens use system backgrounds; floating controls use glass or material |
| Destructive and errors | `.red` | Delete actions, import failure text |
| Warnings | `.orange` | Editor notices, video warnings, the Plan tab's tint |
| On photos | `.white` | Text and icons drawn over recipe photos |

Notes:

- There is no `AccentColor` asset. The accent is applied per view with `.tint(Theme.accent)`, so a new screen has to opt in.
- A recipe with no photo gets a gradient of the accent at 22% to 8% opacity with a `fork.knife` glyph at 45%.
- Timer pills in cook-mode text are the accent at 14% opacity.
- Always reference `Theme.accent`. Don't copy the numbers.

### App icon and brand

| Role | Hex |
|---|---|
| Background | A display-P3 gradient from peach (`1.000, 0.834, 0.656`) at the top to terracotta (`0.750, 0.358, 0.247`) at the bottom |
| Spoon and fork | Orange glass (`1.000, 0.553, 0.157` to `0.422, 0.257, 0.119`) |
| Book | Translucent cream glass (`0.843, 0.805, 0.805` to `1.000, 0.834, 0.671`) |

The layered icon is `apps/ios/App/AppIcon.icon`, the source of truth. `Design/AppIcon/` holds the earlier, brown version and is no longer current.

**Known mismatch:** the icon is peach, terracotta and orange, while the app's accent is a tomato red. They are close in warmth but not the same hue. Pick one direction before the next visual pass. Marketing art (see below) keeps its dark warm brown ground with the icon's orange, so the icon stands out against it.

### Marketing and App Store art

Not used inside the app. Defined here so store art stays consistent.

| Role | Value |
|---|---|
| Canvas | `#2B2320` to `#1F1815`, a slight diagonal gradient, with a soft `#FF8A4C` glow at the top at 14% |
| Headline | White, serif |
| Headline highlight | Gradient `#FFC48A` to `#FF8A4C` on the emphasized words |
| Light variant | `#FFFFFF` to `#FFF1E0`, text `#2B2320`, highlight `#E8672A` to `#C9402F` |

## Typography

All system fonts. No font files ship with the app.

| Style | Definition | Use |
|---|---|---|
| Serif display | `.system(.largeTitle, design: .serif, weight: .bold)` | Recipe title on the recipe page and collapsing header, welcome tour title |
| Serif title | `.system(.title2, design: .serif, weight: .semibold or .bold)` | Section and sidebar titles ("Recipes"), the Recipes home heading |
| Serif headline | `.system(.headline, design: .serif)` | Recipe titles in lists and cards, feed entries, tour source titles (`.title3`, semibold) |
| Serif body | `.system(.body, design: .serif)` | Recipe titles in the week plan and Smart Plan, step and ingredient text in cook mode (`.title3`) and on the recipe page |
| Rounded | `.system(.headline, design: .rounded, weight: .semibold)` with `.monospacedDigit()` | Cook-mode timers only |
| Sans (default) | `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption` | Everything else: controls, metadata, labels |

Rules:

- **Recipe content is serif, interface is sans.** If it's a recipe's words (title, ingredient, step), it's serif. If it's a control or a label, it's the default system font.
- **Ingredients:** the amount is bold and the preparation note is grey italic, for example **2 tbsp** butter *softened*. This is drawn by `IngredientLine`.
- **Weights:** `.semibold` for emphasis in metadata, `.bold` only for display titles and small badges.
- **Numbers that change** (timers, counts) use `.monospacedDigit()` so they don't jiggle.
- Fixed point sizes are used only for the cook-mode text size setting, large play and placeholder glyphs (44 to 64 pt), and the rating stars.

## Layout

| Token | Value | Notes |
|---|---|---|
| Stack spacing | 12 (most common), 8, 6, 10, 24 | Related items 6 to 8, groups 12, sections 24 |
| Padding | 16 horizontal for rows, 24 for the welcome tour and large panels | |
| Corner radius | 8, 10, 12 (cards, step photos), 20 (tour cards and floating panels) | Pills and timers are full capsules. Continuous corner style is set in only two places, so most radii use the SwiftUI default |
| Materials | `.regularMaterial` for floating panels, `.bar` for bottom bars | |
| Glass | `.glassEffect(.regular, in: Capsule())` for floating pills. `.tint(Theme.accent)` for the primary one. `.buttonStyle(.glass)` in cook mode | iOS 26 and macOS 26 |
| Photos | 4:3 on recipe cards, 16:10 for step photos, `scaledToFill`, clipped | Recipes without photos fall back to the accent gradient |

Layouts respond to width, not device: ingredients and steps sit side by side when there is room, and iPad and Mac use a three-column split (collections, recipes, recipe).

## Components

- **Buttons:** `.borderedProminent` for the one primary action on a screen, `.bordered` for secondary, `.glass` for controls floating over content. Destructive actions use `.red`.
- **Chips:** laid out by `ChipFlow` (wrapping). Under each step they list the ingredients that step uses. Timer pills in cook mode are drawn as capsules in the accent at low opacity.
- **Lists:** compact list is the default, with photo cards one tap away. Swipe actions are user-configurable.
- **Empty states:** `ContentUnavailableView` with an SF Symbol and a short title.
- **Icons:** SF Symbols only. `fork.knife` stands for "recipe" and `book.closed` for the Recipes tab.
- **Haptics:** `.sensoryFeedback` is used sparingly, for example after adding sample data.

## Motion

System animations: `.snappy` for state changes (reordering, rating, import steps), `.smooth` for progress. The recipe header collapse and its material fade follow scroll progress. No looping or decorative animation.

## Open questions

1. Icon orange versus app accent red (above).
2. `.orange` is used both as a warning color and as the Plan tab tint. Probably one of those should change.
3. Spacing and radii are repeated literals. If more screens are added, promote the common ones to `Theme`.
