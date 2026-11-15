# feeds Specification

## Purpose
Subscribing to recipe blogs by RSS or Atom, browsing their posts, and saving a post's recipe to the library. The feature is hidden: `AppFeatures.feeds` is false, so no feed screens are reachable in shipped builds. When enabled, the screens appear in the Mac sidebar; feed subscriptions are stored and synced on every platform.

## Requirements

### Requirement: Hidden behind a flag
The system SHALL hide every feed screen while the `AppFeatures.feeds` flag is off, which it is. With the flag on, the Mac sidebar shows a "Feeds" section listing subscribed feeds and an "Add Feed…" button. No iPhone or iPad navigation leads to feeds.

#### Scenario: Shipped build
- **WHEN** the user opens the Mac sidebar in a build with the flag off
- **THEN** no Feeds section is shown

### Requirement: Feed subscriptions
The system SHALL store each subscription as a feed with `id`, `url`, `title` and `createdAt`, listed oldest first. See library-storage for where feeds are kept.

#### Scenario: Subscribing saves a feed
- **WHEN** the user subscribes to a blog
- **THEN** a feed with its feed URL and title is saved

### Requirement: Finding the feed behind an address
The system SHALL accept either a feed URL or a site URL, prefixing "https://" when no scheme is given. If the address is not itself a feed, it looks for a `<link>` of type `application/rss+xml` or `application/atom+xml` in the page and subscribes to that. It reports "That doesn't look like a web address." for an invalid address, "No feed found at that address." when no feed link exists, and the HTTP status for a non-2xx response.

#### Scenario: Site address
- **GIVEN** a blog page links an RSS feed in its head
- **WHEN** the user enters the blog's address in Add Feed and taps Subscribe
- **THEN** the linked feed is saved with the feed's own title

### Requirement: Parsing RSS and Atom
The system SHALL read RSS, Atom and RDF feeds into posts with a title, link (resolved against the feed URL), optional published date, a plain-text summary of at most 240 characters, and an optional image taken from an image enclosure, a media thumbnail or content, or the first `<img>` in the summary. Posts without a title or link are dropped, and a document that is not a feed is rejected with "That address isn't an RSS or Atom feed."

#### Scenario: Atom entry
- **WHEN** an Atom feed titled "Atom Eats" with an entry "Tart" linking to https://example.com/tart is parsed
- **THEN** the feed title is "Atom Eats" and one post "Tart" with that link is returned

#### Scenario: Not a feed
- **WHEN** an HTML page is parsed as a feed
- **THEN** parsing fails

### Requirement: Browsing posts
The system SHALL list a feed's posts with title, summary, date and image, show "Couldn't load feed" with the reason when loading fails, and reload on pull to refresh.

#### Scenario: Load failure
- **WHEN** a feed's address cannot be fetched
- **THEN** the feed's post list shows "Couldn't load feed" and the error

### Requirement: Saving a post's recipe
The system SHALL import the selected post's link as a recipe preview (see web-import) that the user can save to the library, and show "No recipe found" with "Open in Browser" when no recipe can be read.

#### Scenario: Post without a recipe
- **WHEN** the user selects a post whose page holds no recipe
- **THEN** "No recipe found" is shown with a link to open the post in the browser

### Requirement: Unsubscribing
The system SHALL let the user unsubscribe from a feed from its context menu in the sidebar, deleting the saved feed.

#### Scenario: Unsubscribe
- **WHEN** the user picks Unsubscribe on a feed
- **THEN** the feed disappears from the sidebar and its stored record is deleted

### Requirement: YouTube channels
Add Feed SHALL have a YouTube mode that searches YouTube channels by name, listing each match with its picture, name and handle or subscriber count, and a follow button that adds the channel's video feed. A video post's long-press menu offers "Find Recipe Later", which saves the video as an idea with its title and thumbnail and then looks for the recipe in its description and captions in the background, filling the idea in when it finds one. Saving a video post whose recipe can't be read does the same. A video post that opens without a readable recipe shows the video with "Find Later". An idea saved from a video offers "Find the Recipe in This Video" on its page.

#### Scenario: Follow a channel by name
- **WHEN** the user searches "Pasta Grannies" in Add Feed's YouTube mode and taps its follow button
- **THEN** the channel's newest videos show up in Discover

### Requirement: Your Feeds lists everything followed
The Manage Feeds page SHALL list every feed the user follows under "Your Feeds" at the top, including popular ones, each with a symbol for YouTube, Reddit or other feeds, before the popular feeds to discover.

### Requirement: Discover tab toolbar and view settings
The followed-posts tab SHALL be named "Discover". It always shows a Popular Feeds button in its navigation bar, and a Mark All as Viewed button beside Manage Feeds. The Popular Feeds card at the top of the list has an X that dismisses it for good; Settings → Discover → View brings it back with "Popular Feeds Card", and also holds the Layout choice (All Posts, One at a Time, By Feed) and "Show Viewed Posts".

#### Scenario: Dismiss the Popular Feeds card
- **WHEN** the user taps the X on the Popular Feeds card
- **THEN** the card goes away and Popular Feeds stays reachable from the navigation bar

### Requirement: Search recipes online
Unless "Search Recipes Online" is switched off in Settings → Search (where each source below also has its own switch), the Discover tab SHALL have a "Search Recipes Online" box, and a search on Home or Recipes SHALL show the same online results right under the matching recipes, with a spinner while sources answer and "Search the Web for …" at the end. "No Results" shows only when neither the library nor any source found anything, and then it carries Search the Web. Online results look like library rows (or cards): a photo, the title, and the site with the cooking time, both read from the result's page when the search engine leaves them out. A search lists, each under its own switch (on by default):
- "From the Web": Google's results, loaded in a hidden in-app browser and read from the page once it has run (title, star rating and picture from each card, with Google's `/goto` links resolved to the real page), topped up from DuckDuckGo's HTML results when Google gives fewer than eight
- "From Sites You Follow": matching posts from the WordPress sites behind followed feeds, through their REST API
- "YouTube": matching recipe videos, each shown as YouTube does (a 16:9 picture with its running time, then the title, channel, views and age), with Find Recipe Later in their long-press menu
- "Search the Web for …", last: opens Google in an in-app browser, where tapping a result opens it in the app's recipe preview instead of the site

Each section appears as soon as its source answers. Tapping any result opens the same recipe preview as a feed post, with Add to My Recipes. No source needs an API key.

#### Scenario: Turned off
- **GIVEN** Search Recipes Online is off in Settings → Search
- **WHEN** the user opens Discover
- **THEN** there is no search box

### Requirement: End of the feed
When every loaded post has been viewed and older pages remain, Feeds SHALL load older pages before deciding there is nothing new. At the end of the new posts, in every layout, it shows "You're All Caught Up" with how many feeds the user follows, "Browse Viewed Posts (N)" when any are viewed, and "Find More Feeds". Browse Viewed Posts opens a Viewed Posts page listing viewed posts newest first; it doesn't change the Show Viewed Posts setting, so the feed keeps showing only what's new.

#### Scenario: Everything viewed
- **GIVEN** every post in every followed feed has been viewed
- **WHEN** the user opens Feeds
- **THEN** the caught-up card shows with Browse Viewed Posts, and no viewed post appears in the feed

### Requirement: Watch a video while its recipe loads
Opening a YouTube post or result SHALL show its player right away, above a loading page, while the recipe is read from the video. When the recipe arrives, the recipe page replaces the loading page, and a video already playing carries on from the same moment in the recipe page's player.

