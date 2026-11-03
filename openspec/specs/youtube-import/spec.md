# youtube-import Specification

## Purpose
Turns a YouTube cooking video into a recipe: read from the video's description, filled in from its captions by the on-device model when the description has no recipe, with a timestamp for each step and the video playing inline on the recipe page and in cook mode. Runs in the iOS, iPadOS and macOS app; the server does not import videos (see web-import).

## Requirements

### Requirement: Recognizing video links
The app SHALL treat an address as a YouTube video when it has an 11-character video ID (letters, digits, `_`, `-`) in one of these forms: `youtu.be/<id>`, `youtube.com/watch?v=<id>`, or `youtube.com/shorts|embed|live|v/<id>`, on `youtube.com`, any `*.youtube.com` host or `*.youtube-nocookie.com`. Any other address is imported as a web page (see web-import).

#### Scenario: Supported forms
- **WHEN** the address is `https://youtu.be/dQw4w9WgXcQ?si=abc`, `https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10` or `https://m.youtube.com/shorts/dQw4w9WgXcQ`
- **THEN** the video ID is `dQw4w9WgXcQ`

#### Scenario: Not a video
- **WHEN** the address is `https://www.youtube.com/@channel` or `https://example.com/watch?v=dQw4w9WgXcQ`
- **THEN** it is not treated as a YouTube video

### Requirement: Progress steps
While importing a video, the app SHALL show the steps "Finding the video and captions", "Reading the recipe", "Writing it up with the on-device model" and "Downloading the photo". The model step is marked skipped when the description already holds a full recipe, the video has no captions, or Apple Intelligence isn't available.

#### Scenario: Description has the recipe
- **WHEN** a video whose description lists ingredients and steps is imported
- **THEN** "Writing it up with the on-device model" is shown as skipped

### Requirement: Video details and captions
The app SHALL read the video's title, channel, description and thumbnail from YouTube's player data, and SHALL fail with "Couldn't read that YouTube video. It may be private or unavailable." when there is no title. Captions are fetched with timing, preferring English tracks, human-written before auto-generated, then other languages, trying at most two tracks per client and a second client when the first returns none. Both caption formats (`<text start dur>` in seconds and `<p t d>` in milliseconds) are read, with entities decoded.

#### Scenario: Millisecond captions
- **WHEN** a caption track contains `<p t="2500" d="1500"><s>Add</s><s> salt</s></p>`
- **THEN** it yields a caption starting at 2.5 seconds lasting 1.5 seconds with text "Add salt"

### Requirement: Recipe from the description
The app SHALL build the recipe from the video description after dropping blank lines, chapter timestamps (lines starting like `0:00`), bare links, hashtag-only lines and lines mentioning subscribe, follow me/us, social networks, business inquiries, music credits, sponsorship, affiliate links, Patreon, merch, newsletters or cookbooks. The cleaned text is parsed only where it has Ingredients and Method/Instructions-style headings (see scan-import for the text rules). The title is the video title with site suffixes removed, `sourceURL` is `https://www.youtube.com/watch?v=<id>`, the first tag is "YouTube" followed by suggested tags, and a summary over 300 characters is cut to 297 plus "…". With no summary, it is "From <channel> on YouTube."

#### Scenario: Full recipe in the description
- **GIVEN** a description with an intro line, a `0:00 Intro` line, "INGREDIENTS:" with four lines, "INSTRUCTIONS:" with three numbered steps, a subscribe line, links and hashtags
- **WHEN** the video "Easy Shakshuka" is imported
- **THEN** the recipe has the four ingredients, three steps, the intro line as its summary and tags "YouTube", "Eggs", "Vegetarian"
- **AND** the import is complete

### Requirement: Completeness
A video import SHALL count as complete when it has at least two ingredients and at least one step. An incomplete import keeps the first 2,000 characters of the cleaned description in the recipe's notes, always opens in the editor for review, and shows the captions (titled "Video captions") or else the cleaned description (titled "Video description") beside the draft.

#### Scenario: Chatty description
- **GIVEN** a description with no headings and no recipe
- **WHEN** the video is imported without captions
- **THEN** the draft has no ingredients, its notes hold the description, and the editor shows "This video's description doesn't include a recipe, and it has no captions to read. Add the ingredients and steps below."

### Requirement: Recipe from captions with Apple Intelligence
When the description doesn't give a complete recipe, the video has captions, and Apple Intelligence is available, the app SHALL have the on-device model write the recipe from the video title and captions and fill in only what the description lacked: ingredients when it had fewer than two, steps when it had none, servings and summary when missing. The model is told to use only what the cook says. When the model is unavailable or fails, the draft opens with the notice "This video's description doesn't include a full recipe. Check the ingredients and steps below against the video." followed by the reason (see apple-intelligence).

#### Scenario: Captions fill the gaps
- **GIVEN** a description without a recipe and captions the model turns into two ingredients and two steps with 2 servings
- **WHEN** the video is imported
- **THEN** the recipe has those ingredients, steps and servings and the import is complete

#### Scenario: Model unavailable
- **GIVEN** Apple Intelligence is turned off
- **WHEN** a captioned video without a written recipe is imported
- **THEN** the draft opens with the notice above followed by "Apple Intelligence is turned off. Turn it on in Settings under Apple Intelligence & Siri."

### Requirement: Step timestamps
The app SHALL give each step the time in the video where it is spoken, by matching the step's distinctive words against 14-second windows of the captions, in order (a step never matches before the previous step's match). A match is placed 2 seconds before its window starts. A step with no good match gets no time. Times are stored in the recipe's `stepTimestamps`, parallel to its steps, in whole seconds.

#### Scenario: Steps aligned in order
- **WHEN** four steps that follow the cook's narration are aligned against the captions
- **THEN** each step gets a time, and each time is later than the one before

#### Scenario: Unrelated step
- **WHEN** a step's words appear nowhere in the captions
- **THEN** that step has no time

### Requirement: Find Step Timestamps
For a recipe whose `sourceURL` is a YouTube video and that has steps, the recipe page's More menu SHALL offer "Find Step Timestamps", which fetches the captions, aligns the current steps and saves the times. It reports "Found a timestamp for <n> of <total> steps. Tap one to jump to that moment." or "Couldn't match the steps to this video's captions."

#### Scenario: Re-aligning after edits
- **GIVEN** a YouTube recipe whose steps were edited
- **WHEN** the user taps "Find Step Timestamps"
- **THEN** the steps get new times from the captions and the count is reported

### Requirement: Video on the recipe page
A recipe whose `sourceURL` is a YouTube video SHALL show the video above the recipe: a poster (the recipe photo, or black) with a play button that loads YouTube's embedded player inline, sized to the video's own aspect ratio (from YouTube's oEmbed, clamped between 0.5 and 2.4, default 16:9), plus an "Open in YouTube" link to the current start time. As the page scrolls, the video shrinks and stays pinned; a handle along its top edge moves it to another corner, including the bottom of the screen. A video that refuses to play inside the app shows "This video can't be played inside the app (error <code>). Use Open in YouTube."

#### Scenario: Tapping a step's time
- **GIVEN** step 3 has the time 1:35
- **WHEN** the user taps the "1:35" button beside STEP 3
- **THEN** the video plays from 95 seconds

### Requirement: Video in cook mode
In cook mode, a YouTube recipe SHALL show a small player above the steps that starts at the current step's time, and when the user moves to another step while the video is showing, it jumps to that step's time if it has one.

#### Scenario: Next step
- **GIVEN** cook mode is playing the video and the next step has a time
- **WHEN** the user moves to the next step
- **THEN** the video seeks to that step's time and keeps playing

### Requirement: Timestamps in shared text
The recipe's Markdown text SHALL append to each timed step of a YouTube recipe a link `[▶ m:ss](https://youtu.be/<id>?t=<seconds>)`, using `h:mm:ss` for times of an hour or more.

#### Scenario: Linked step
- **GIVEN** a YouTube recipe whose second step "Simmer." has the time 95
- **WHEN** its Markdown is produced
- **THEN** it contains `2. Simmer. [▶ 1:35](https://youtu.be/<id>?t=95)`
