# scan-import Specification

## Purpose
Reads a recipe from a printed page: scanned with the camera on iPhone and iPad, or picked as a photo or PDF on iOS, iPadOS and macOS. On-device text recognition reads the page and a text parser turns it into a draft the user checks in the editor. The same text parser structures YouTube descriptions (see youtube-import). A photo of a cooked meal can also be turned into a draft recipe by Apple Intelligence.

## Requirements

### Requirement: Entry points
The Add Recipe menu SHALL offer "Import Photo or PDF…" on every platform, accepting image and PDF files, and on iOS and iPadOS also "Scan Recipe…", which opens the system document camera full screen. On a device without a document camera, "Scan Recipe…" shows "Scanning needs a device with a camera."

#### Scenario: Scanning pages
- **WHEN** the user taps "Scan Recipe…", captures two pages and finishes
- **THEN** both pages are read, in order, as one recipe

#### Scenario: Cancelling
- **WHEN** the user cancels the document camera or it fails
- **THEN** the camera closes and nothing is imported

### Requirement: Text recognition
The app SHALL recognize text on each page on the device using accurate recognition with language correction, joining each page's lines with newlines and the pages in order. Every page of a PDF is rendered at twice its size on white and read. While text is read, the app shows a "Reading recipe…" overlay.

#### Scenario: Multi-page PDF
- **WHEN** the user imports a three-page PDF
- **THEN** the text of all three pages is read in page order

### Requirement: Scan failures
The app SHALL show a "Couldn't scan" alert when reading fails: "No text found." when the pages hold no text, "Couldn't read an image from that file." for an unreadable image, and "Couldn't read that PDF." for a PDF with no readable pages.

#### Scenario: Blank page
- **WHEN** the user scans a page with no text
- **THEN** a "Couldn't scan" alert says "No text found." and no editor opens

### Requirement: Review the scan
After a scan, the app SHALL open the recipe editor with the parsed draft and a collapsible "Scanned text" section holding the recognized text (selectable), with the hint "Check the recipe below against the scan before saving." Nothing is saved until the user saves.

#### Scenario: Draft opened
- **WHEN** a page is read
- **THEN** the editor opens with the draft and the scanned text beside it

### Requirement: Title, summary and details
The parser SHALL drop blank lines, take the first remaining line as the title (or "Scanned Recipe" when there is none), and read lines beginning "Serves", "Servings", "Makes" or "Yield" as servings (the first number), "Prep time"/"Prep"/"Preparation time" as prep minutes and "Cook time"/"Cooking time"/"Cook"/"Bake" as cook minutes (from durations such as "10 minutes" or "1.5 hours"). When the text has section headings, the lines between the title and the first heading are joined as the summary.

#### Scenario: Header lines
- **GIVEN** the text starts "Lemon Ricotta Pancakes", "Serves 4", "Prep time: 10 minutes", "Cook time: 20 minutes", "Light and fluffy."
- **WHEN** it is parsed
- **THEN** the title is "Lemon Ricotta Pancakes", servings 4, prep 10, cook 20 and the summary "Light and fluffy."

### Requirement: Section headings
The parser SHALL treat a line reading "Ingredients" (or starting with it, under 40 characters) as the start of the ingredients, and "Method", "Directions", "Instructions", "Steps", "Preparation", "Procedure" or a short line starting "How to make" as the start of the steps, ignoring case and surrounding punctuation such as colons and dashes.

#### Scenario: Shouted headings
- **WHEN** the text has "INGREDIENTS" and "METHOD" lines
- **THEN** the lines after "INGREDIENTS" become ingredients and the lines after "METHOD" become steps

### Requirement: Text without headings
When the text has no section headings, the parser SHALL treat each line under 70 characters that starts with a quantity, and isn't a numbered step, as an ingredient, and every other line as a step.

#### Scenario: Plain card
- **WHEN** the text is "Toast", "2 slices bread", "1 tbsp butter", "Toast the bread and butter it."
- **THEN** the ingredients are "2 slices bread" and "1 tbsp butter" and the step is "Toast the bread and butter it."

### Requirement: Ingredient lines and sub-headings
The parser SHALL strip a leading bullet (•, -, *, ·, ●, ▪) from ingredient lines. Within the ingredients, a short line with no digits and no quantity that ends in ":" or starts with "For " or "For the " becomes an ingredient section heading (without the colon) over the ingredients after it.

#### Scenario: Sub-headings become sections
- **GIVEN** ingredients "For the chips:", two ingredients, "Cinnamon sugar:", two ingredients
- **WHEN** the text is parsed
- **THEN** the recipe has four ingredients and sections "For the chips" starting at 0 and "Cinnamon sugar" starting at 2

### Requirement: Step lines
The parser SHALL remove step numbering such as "1.", "2)", "3:" or "Step 4." from the start of a step, start a new step for each numbered line, and join an unnumbered line onto the previous step when that step doesn't end in ".", "!" or "?", so steps broken across lines are rejoined.

#### Scenario: Wrapped step
- **GIVEN** the method "1. Whisk the ricotta and", "eggs until smooth.", "2. Cook on a hot pan for 3 minutes per side."
- **WHEN** it is parsed
- **THEN** the steps are "Whisk the ricotta and eggs until smooth." and "Cook on a hot pan for 3 minutes per side."

### Requirement: Headings required for video descriptions
When parsing a video description, the parser SHALL produce no ingredients or steps unless the text contains a section heading, so chatty descriptions don't turn into a recipe.

#### Scenario: Description without headings
- **WHEN** a video description "Thanks for watching, this pasta is so good and easy to make." / "2 cups of love" is parsed
- **THEN** the draft has no ingredients and no steps

### Requirement: Recipe from a meal photo
The Add Recipe menu SHALL offer "Recipe from Meal Photo": on iOS and iPadOS a submenu with "Take Photo" (only when the device has a camera) and "Choose Photo", and on macOS "Recipe from Meal Photo…", which chooses from the photo library. While the photo is read, the app shows a "Looking at your meal…" overlay. A photo that can't be loaded shows "Couldn't load that photo."

#### Scenario: Choosing a photo
- **WHEN** the user picks "Choose Photo" and selects a picture of a meal
- **THEN** the app shows "Looking at your meal…" and then opens the recipe editor

### Requirement: Writing the meal-photo draft
When Apple Intelligence is available, the app SHALL have the on-device model write a draft for the dish in the photo: a title in title case ("Untitled Meal" when blank), a one-sentence summary, servings (none when zero), ingredients in the standard `quantity unit item` form and unnumbered steps. On iOS 27 or macOS 27 with a model that can see images, the photo itself is given to the model; otherwise the photo is classified on the device and the model is given up to ten labels with at least 15% confidence, most likely first, such as "fried rice (95%), food (90%)". No confident labels fails with "Couldn't tell what's in that photo."; a refusal gives "Apple Intelligence declined to read this photo."; an unreadable image gives "Couldn't read that photo." The instructions can be customized (see apple-intelligence).

#### Scenario: Labels from image recognition
- **GIVEN** the model can't take images and recognition finds "fried_rice" at 95%, "food" at 90% and "plate" at 5%
- **WHEN** the draft is written
- **THEN** the model is told "Image recognition looked at a photo of a meal and saw, most likely first: fried rice (95%), food (90%). Write a recipe for the dish."

### Requirement: Reviewing the meal-photo draft
The app SHALL open the recipe editor with the photo attached as the cover photo and, when a draft was written, the notice "Apple Intelligence wrote this from your photo. Check the ingredients and amounts." When Apple Intelligence isn't available or writing fails, the editor opens with an empty recipe, the photo and the reason as its notice (see apple-intelligence for the status explanations). Nothing is saved until the user saves.

#### Scenario: Without Apple Intelligence
- **GIVEN** Apple Intelligence is turned off
- **WHEN** the user chooses a meal photo
- **THEN** the editor opens with an empty recipe, the photo, and "Apple Intelligence is turned off. Turn it on in Settings under Apple Intelligence & Siri."
