# apple-intelligence Specification

## Purpose
Uses Apple's on-device language model, where the device has it, to write recipes from video captions, page text and meal photos, split long steps and group ingredients, and reports in plain language when it isn't available so every feature falls back to working without it. Runs in the iOS, iPadOS and macOS app; nothing is sent off the device. Smart Plan's use of the model is described in smart-plan.

## Requirements

### Requirement: Availability status
The app SHALL determine one Apple Intelligence status and give each a plain-language explanation shown wherever a feature can't use the model:
- available: "Ready."
- OS older than iOS 26 or macOS 26: "This needs iOS 26 or macOS 26."
- device not eligible: "This device doesn't support Apple Intelligence."
- turned off: "Apple Intelligence is turned off. Turn it on in Settings under Apple Intelligence & Siri."
- model still downloading: "Apple Intelligence is still downloading its language model. Try again in a few minutes."
- any other reason: "Apple Intelligence isn't available right now."

#### Scenario: Turned off
- **GIVEN** Apple Intelligence is turned off in system Settings
- **WHEN** a feature that needs the model reports why it can't run
- **THEN** it says "Apple Intelligence is turned off. Turn it on in Settings under Apple Intelligence & Siri."

### Requirement: Settings page
Settings SHALL have an "Apple Intelligence" page listing "Smart Plan for My Week", "Recipes from video captions", "Recipes from meal photos" and "Photos with Image Playground", each marked "Ready" or "Not available". The first three follow the model's status and the third follows whether Image Playground is supported. The footer says everything runs on the device when the model is available, and otherwise gives the status explanation followed by "Smart Plan falls back to a simple rotation, and a video without a written recipe opens as a draft with its captions beside it."

#### Scenario: Unsupported device
- **GIVEN** the device isn't eligible for Apple Intelligence
- **WHEN** the user opens Settings → Apple Intelligence
- **THEN** the first three rows say "Not available" and the footer begins "This device doesn't support Apple Intelligence."

### Requirement: Viewing and customizing prompts
The Apple Intelligence settings page SHALL have a "Prompts" section listing each job the model does, marked "Default" or "Custom": "Recipe from a meal photo", "Recipe from video captions", "Recipe from a web page", "Split a pasted method into steps", "Group ingredients into sections" and "Smart Plan for My Week". Opening one shows its summary, a "Customize this prompt" toggle and the default instructions (selectable). Turning Customize on with no saved text starts from the default, shows an editor for "Your prompt" and a "Reset to Default Prompt" button (disabled while the text equals the default). Each job uses its custom instructions only while Customize is on and the text isn't blank; otherwise it uses the default. Only the instructions change: the structure the app asks the model to return stays the same. Customizing one job leaves the others on their own settings.

#### Scenario: Custom prompt used
- **GIVEN** the user turned on Customize for "Split a pasted method into steps" and wrote new instructions
- **WHEN** a long step is split
- **THEN** the model is given the user's instructions

#### Scenario: Blank custom prompt
- **GIVEN** Customize is on for "Smart Plan for My Week" and the text is only whitespace
- **WHEN** Smart Plan runs
- **THEN** the default instructions are used

#### Scenario: Customize off
- **GIVEN** custom text is saved for a job but Customize is off
- **WHEN** that job runs
- **THEN** the default instructions are used

### Requirement: Writing a recipe from text
Given a title and a block of text (a video's captions or a web page's visible text), the app SHALL ask the on-device model for a structured recipe: each ingredient as quantity, a unit from the app's unit list or none, and item; steps as short imperative sentences without numbering; servings only if stated; and a one-sentence summary. By default the model is instructed to use only what the text says and not to invent ingredients, quantities or steps, and is given the recipe standards from recipe-format. Ingredients are written in the standard `quantity unit item` form and steps are standardized; empty ones are dropped.

#### Scenario: Captions written up
- **GIVEN** the model is available
- **WHEN** a cooking video's captions are passed in
- **THEN** the result is a list of standard ingredient lines, unnumbered steps, optional servings and a summary

### Requirement: Long text and model errors
The app SHALL send at most the first 7,000 characters of the text, and retry once with the first 3,500 when the model reports the text is too long for its context; if that also fails the reason is "The text is too long for the on-device model." A guardrail refusal gives "Apple Intelligence declined to read this text.", an unsupported language gives "Apple Intelligence doesn't support this language.", and missing model assets are reported as the model still downloading. The model is loaded ahead of time when a video or page import starts so the first request doesn't wait.

#### Scenario: Very long captions
- **GIVEN** captions too long for the model at 7,000 characters
- **WHEN** a recipe is written from them
- **THEN** the app retries with the first 3,500 characters

### Requirement: Reading a page without recipe data
When the user taps "Try with Apple Intelligence" after a web import found no recipe data (see web-import), the app SHALL fetch the page, take its `<title>` (or the host) as the title and its visible text (scripts, styles, head, navigation, footer, comments and markup removed, one line per paragraph, list item or heading), and have the model find the recipe while ignoring navigation, comments and ads. The progress steps are "Fetching the page", "Reading it with Apple Intelligence" and "Downloading the photo". A result with fewer than two ingredients or no steps fails with "Apple Intelligence couldn't find a recipe on this page." The draft gets the page's `og:image` photo, suggested tags, a summary of at most 300 characters, and always opens for review with the page text beside it (titled "Page text") and the notice "Apple Intelligence wrote this from the page's text. Check the ingredients and steps against the page."

#### Scenario: Blog post without schema data
- **GIVEN** Apple Intelligence is available and a page lists ingredients and a method in plain HTML
- **WHEN** the user taps "Try with Apple Intelligence"
- **THEN** the editor opens with the written recipe, the page text and the notice

#### Scenario: Model unavailable
- **GIVEN** Apple Intelligence isn't available
- **WHEN** the import sheet offers "Try with Apple Intelligence"
- **THEN** the button is disabled and the status explanation is shown beneath it

#### Scenario: Visible text
- **WHEN** a page has a `<nav>`, a `<script>`, an `<h1>Best Soup</h1>`, list items "2 cups stock" and "1 onion" and a paragraph "Simmer   for 20 minutes."
- **THEN** the text given to the model is "Best Soup", "2 cups stock", "1 onion", "Simmer for 20 minutes." on separate lines

### Requirement: Splitting long steps
The app SHALL ask the model to split any step longer than 450 characters into separate steps in the original order, keeping the author's words (at most the first 3,000 characters of the step are sent). The split is used only when it gives at least two steps whose combined length is at least 70% of the original; otherwise, on any error, or when the model isn't available, the step is kept as it was. This runs on every web import and in the editor's cleanup (see recipe-editor).

#### Scenario: Ordinary steps
- **WHEN** a recipe's steps are "Brown the beef." and "Add the peppers."
- **THEN** the model is not asked and the steps are unchanged

#### Scenario: Model drops text
- **GIVEN** a step of 600 characters
- **WHEN** the model returns two short steps covering less than 70% of it
- **THEN** the original step is kept

### Requirement: Grouping ingredients into sections
In the editor's cleanup (see recipe-editor), when the recipe has no ingredient sections, at least four ingredients and the model is available, the app SHALL ask the model whether the method makes distinct parts of the dish (such as a salad and its dressing, or a pie's filling and crust) and assign each ingredient to one, never grouping by ingredient type or by when it is added. Each named group becomes a section, in order of first appearance, with its ingredients moved together in their original order; an ingredient the model skipped joins the group of the one before it (or after it, at the start); ingredients left unclaimed go in a final "Other" section. When the result would have fewer than two sections, the ingredients are left unchanged.

#### Scenario: Two parts
- **GIVEN** ingredients "2 potatoes", "1 tsp cinnamon", "2 tbsp oil", "2 tbsp sugar", "1 tsp salt"
- **WHEN** the groups are "Cinnamon sugar:" with cinnamon and sugar and "Chips" with the rest
- **THEN** the ingredients become cinnamon, sugar, potatoes, oil, salt with sections "Cinnamon sugar" at 0 and "Chips" at 2

#### Scenario: Single dish
- **WHEN** the model puts every ingredient in one group
- **THEN** the ingredient list and its sections are unchanged

### Requirement: Fallbacks without the model
Every feature that uses the model SHALL keep working without it: a web import keeps long steps as they are, a YouTube video without a written recipe opens as a draft with its captions beside it and the reason in its notice (see youtube-import), the editor's cleanup still standardizes the recipe and adds "Splitting long steps and grouping ingredients need Apple Intelligence." and the status explanation to its message, a meal photo opens the editor with just the photo and the reason (see scan-import), and Smart Plan falls back to a rotation (see smart-plan).

#### Scenario: Cleanup without the model
- **GIVEN** Apple Intelligence is turned off
- **WHEN** the user taps "Clean Up with Apple Intelligence" in the editor
- **THEN** the recipe is tidied without splitting or grouping and the message ends with "Splitting long steps and grouping ingredients need Apple Intelligence. Apple Intelligence is turned off. Turn it on in Settings under Apple Intelligence & Siri."
