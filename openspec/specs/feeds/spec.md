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
