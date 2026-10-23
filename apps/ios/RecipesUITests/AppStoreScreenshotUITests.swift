#if os(iOS)
import XCTest

/// Drives the app to one screen and saves a screenshot for the App Store (`app-store/`). Skipped unless APP_STORE_SCENE is set.
final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private let hero = "Brown Butter Chocolate Chip Cookies"

    func testCapture() throws {
        let env = ProcessInfo.processInfo.environment
        guard let named = env["APP_STORE_SCENE"], let out = env["APP_STORE_OUT"], let library = env["APP_STORE_LIB"] else {
            throw XCTSkip("Not capturing App Store screenshots")
        }
        continueAfterFailure = false
        let dark = named.hasSuffix("-dark")
        let scene = named.replacingOccurrences(of: "-dark", with: "")

        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-recipeListStyle", env["APP_STORE_STYLE"] ?? (scene == "list" ? "list" : "cards"), "-onboardingCompleted", "YES", "-defaultMeal", "lunch", "-reviewPromptDismissed", "YES"]
        if dark { app.launchArguments += ["-AppleInterfaceStyle", "Dark"] }
        if env["APP_STORE_LANDSCAPE"] == "1" { XCUIDevice.shared.orientation = .landscapeLeft }
        app.launch()

        let loaded = NSPredicate(format: "label == 'Brown Butter Chocolate Chip Cookies' OR label == '19'")
        XCTAssertTrue(app.staticTexts.matching(loaded).firstMatch.waitForExistence(timeout: 40), "library should load")
        sleep(3)
        let regular = app.windows.firstMatch.frame.width > 700
        if regular { showTopTabBar() }

        switch scene {
        case "home":
            break
        case "library":
            if regular { openRecipe(hero) } else { open("All Recipes") }
        case "list":
            open("All Recipes")
        case "recipe":
            if !regular { open("All Recipes") }
            openRecipe(hero)
        case "ingredients":
            if !regular { open("All Recipes") }
            openRecipe(hero)
            app.swipeUp()
            app.swipeUp()
        case "cook":
            if !regular { open("All Recipes") }
            openRecipe(hero)
            tapButton("Cook")
            sleep(3)
            app.swipeLeft()
            sleep(1)
            app.swipeLeft()
        case "plan":
            tab("Plan")
            tapButton("My Week")
            if regular { openRecipe("Thai Red Curry") }
        case "upnext":
            tab("Plan")
            if regular { openRecipe("Slow-Braised Beef") }
        case "groceries":
            tab("Groceries")
        case "settings":
            tab("Settings")
        case "roundtrip":
            tab("Settings")
            tab("Recipes")
        case "search":
            tab("Search")
        case "import":
            tapButton("Add Recipe")
            tapButton("Import from Web or YouTube…")
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            field.tap()
            field.typeText("http://localhost:8765/lemon-herb-gnocchi.html")
            tapButton("Import")
            let previewed = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Lemon Herb Gnocchi' OR value == 'Lemon Herb Gnocchi'")).firstMatch.waitForExistence(timeout: 40)
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(out)/\(named).png"))
            XCTAssertTrue(previewed, "the import should open a preview")
        case "idea":
            tab("Plan")
            tapButton("My Week")
            let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add meal on'")).allElementsBoundByIndex.first(where: \.isHittable)
            XCTAssertNotNil(add, "No Add meal button")
            add?.tap()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            field.tap()
            field.typeText("Taco night")
            tapButton("Add")
            XCTAssertTrue(app.staticTexts["Taco night"].firstMatch.waitForExistence(timeout: 8), "the idea should join the week")
            if regular { openRecipe("Thai Red Curry") }
        case "cleanup":
            if !regular { open("All Recipes") }
            openRecipe(hero)
            tapButton("More")
            tapButton("Edit")
            let cleanUp = app.buttons["Clean Up with Apple Intelligence"].firstMatch
            for _ in 0..<8 where !cleanUp.exists || !cleanUp.isHittable { app.swipeUp() }
            XCTAssertTrue(cleanUp.exists, "No Clean Up button")
        case "smartplan":
            tab("Plan")
            tapButton("My Week")
            tapButton("Smart Plan")
            sleep(8)
        default:
            XCTFail("Unknown scene \(scene)")
        }

        sleep(3)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: URL(fileURLWithPath: "\(out)/\(named).png"))
    }

    /// Drives the app through one slow, paced scene for an App Store preview video (`app-store/preview/`). Skipped unless APP_PREVIEW_SCENE is set.
    /// Each beat prints `APP_PREVIEW_EVENT <name> <unix time>` so the footage can be lined up with the recording.
    func testPreview() throws {
        let env = ProcessInfo.processInfo.environment
        guard let scene = env["APP_PREVIEW_SCENE"], let library = env["APP_STORE_LIB"] else {
            throw XCTSkip("Not recording an App Store preview")
        }
        continueAfterFailure = false
        if scene == "safarisettings" { try chooseSafariBottomLayout(); return }
        if scene == "prep" {
            // First launch on a fresh install: let the system's one-time questions get answered, so they never appear in a recording.
            let first = XCUIApplication()
            first.launchEnvironment["RECIPES_DIR"] = library
            first.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"]
            first.launch()
            sleep(6)
            if ProcessInfo.processInfo.environment["APP_PREVIEW_PRIME"] == "1" {
                // Start one timer so the system's one-time alarm question is answered before anything is recorded, then cancel it.
                let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                first.staticTexts.matching(NSPredicate(format: "label == 'Brown Butter Chocolate Chip Cookies' OR label == '19' OR label == '20' OR label == '21' OR label == 'All Recipes'")).firstMatch.waitForExistence(timeout: 30)
                let row = first.staticTexts["All Recipes"].firstMatch
                if row.waitForExistence(timeout: 10) { row.tap(); sleep(1) }
                for _ in 0..<16 where !(first.staticTexts["World's Best Lasagna"].firstMatch.exists && first.staticTexts["World's Best Lasagna"].firstMatch.isHittable) { first.swipeUp(); usleep(400_000) }
                first.staticTexts["World's Best Lasagna"].firstMatch.tap(); sleep(2)
                first.buttons["Cook"].firstMatch.tap(); sleep(3)
                for _ in 0..<3 { first.swipeLeft(); usleep(500_000) }
                sleep(1)
                first.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.59, dy: 0.314)).tap()
                let ok = sb.alerts.buttons["Allow"].firstMatch
                if ok.waitForExistence(timeout: 6) { ok.tap() }
                sleep(2)
                let chip = first.buttons["Cancel timer"].firstMatch
                if chip.waitForExistence(timeout: 4) { chip.tap(); sleep(1) }
            }
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for _ in 0..<3 {
                let allow = springboard.alerts.buttons["Allow"].firstMatch
                if allow.waitForExistence(timeout: 3) { allow.tap(); sleep(1) }
            }
            mark("end")
            return
        }
        if scene == "share" { try shareFromSafari(landscape: env["APP_STORE_LANDSCAPE"] == "1"); return }
        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-recipeListStyle", env["APP_STORE_STYLE"] ?? "cards", "-onboardingCompleted", "YES", "-defaultMeal", "dinner", "-reviewPromptDismissed", "YES"]
        if env["APP_STORE_LANDSCAPE"] == "1" { XCUIDevice.shared.orientation = .landscapeLeft }
        app.launch()

        let loaded = NSPredicate(format: "label == 'Brown Butter Chocolate Chip Cookies' OR label == '19' OR label == '20' OR label == '21' OR label == 'All Recipes'")
        // System questions (Reminders, alarms) can cover the app on a fresh install: answer them until the library shows.
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var ready = false
        for _ in 0..<60 {
            if app.staticTexts.matching(loaded).firstMatch.exists { ready = true; break }
            for name in ["Allow", "Don\u{2019}t Allow", "Don't Allow", "OK"] {
                let button = system.alerts.buttons[name].firstMatch
                if button.exists { button.tap(); break }
            }
            sleep(1)
        }
        XCTAssertTrue(ready, "library should load")
        sleep(3)
        let lasagna = "World's Best Lasagna"
        let regular = app.windows.firstMatch.frame.width > 700
        if regular { showTopTabBar() }
        let url = env["APP_PREVIEW_URL"] ?? "http://localhost:8765/lemon-herb-gnocchi.html"
        mark("ready")

        switch scene {
        case "hero":
            if !regular { open("All Recipes") }
            sleep(2)
            mark("library")
            for _ in 0..<10 { app.swipeUp(velocity: .slow); mark("swipe"); sleep(1) }
        case "import":
            tapButton("Add Recipe")
            mark("menu")
            sleep(1)
            tapButton("Import from Web or YouTube…")
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            sleep(1)
            field.tap()
            sleep(1)
            mark("typing")
            for character in url {
                field.typeText(String(character))
                mark("key")
                usleep(180_000)
            }
            sleep(1)
            mark("submit")
            tapButton("Import")
            let review = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Lemon Herb Gnocchi' OR value == 'Lemon Herb Gnocchi'")).firstMatch
            XCTAssertTrue(review.waitForExistence(timeout: 40), "the import should open a preview")
            mark("review")
            sleep(3)
            glide(by: 0.45)
            sleep(2)
            glide(by: 0.45)
            sleep(2)
        case "plan":
            tab("Plan")
            tapButton("My Week")
            sleep(2)
            mark("week")
            // The lasagna goes on Sunday, picked from Up Next. Then an idea joins the week on Monday.
            let sunday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add meal on'")).allElementsBoundByIndex.first(where: \.isHittable)
            XCTAssertNotNil(sunday, "No Add meal button")
            sunday?.tap()
            mark("picker")
            let row = app.staticTexts[lasagna].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "No lasagna in the picker")
            sleep(2)
            mark("pick")
            row.tap()
            XCTAssertTrue(app.staticTexts[lasagna].firstMatch.waitForExistence(timeout: 8))
            sleep(3)
            mark("lasagna")
            if regular {
                let monday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add meal on Monday'")).firstMatch
                XCTAssertTrue(monday.waitForExistence(timeout: 8), "No Monday add button")
                let frame = monday.frame
                app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.minX + 60, dy: frame.midY)).tap()
            } else {
                // Monday's "Add meal" sits at the same place on the week every time.
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.755)).tap()
            }
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            sleep(1)
            field.tap()
            sleep(1)
            mark("typing")
            for character in "Taco night" {
                field.typeText(String(character))
                mark("key")
                usleep(180_000)
            }
            sleep(1)
            mark("submit")
            tapButton("Add")
            XCTAssertTrue(app.staticTexts["Taco night"].firstMatch.waitForExistence(timeout: 8), "the idea should join the week")
            mark("idea")
            sleep(3)
        case "smartplan":
            tab("Plan")
            tapButton("My Week")
            sleep(2)
            mark("week")
            tapButton("Smart Plan")
            sleep(3)
            mark("sheet")
            tapButton("Plan My Week")
            mark("run")
            let confirm = app.buttons["Add to My Week"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 60), "the plan should be ready")
            mark("review")
            sleep(3)
            confirm.tap()
            mark("added")
            sleep(3)
            for _ in 0..<2 { app.swipeUp(velocity: .default); mark("glide"); sleep(1) }
            sleep(2)
        case "cleanup":
            if !regular { open("All Recipes") }
            scrollToRecipe(lasagna)
            sleep(2)
            tapButton("More")
            tapButton("Edit")
            mark("editor")
            sleep(2)
            mark("messy")
            let cleanUp = app.buttons["Clean Up with Apple Intelligence"].firstMatch
            // Quick flicks, the way a thumb moves, so the recording has real speed in it.
            for _ in 0..<12 where !(cleanUp.exists && cleanUp.isHittable) { fling(up: true); mark("flick"); usleep(600_000) }
            XCTAssertTrue(cleanUp.exists, "No Clean Up button")
            sleep(1)
            mark("button")
            cleanUp.tap()
            mark("run")
            sleep(3)
            mark("done")
            // Back up the page until the ingredients are on screen. Any further and the sheet would be dragged shut.
            let ingredientsHeader = app.staticTexts["Ingredients"].firstMatch
            for _ in 0..<6 where !(ingredientsHeader.exists && ingredientsHeader.isHittable && ingredientsHeader.frame.minY > 150) { fling(up: false); mark("flick"); usleep(600_000) }
            mark("top")
            sleep(3)
        case "cook":
            // Step 4 has "8 to 10 minutes", a timer pill. Three swipes get there from step 1.
            let at = (env["APP_PREVIEW_PILL"] ?? "0.59,0.314").split(separator: ",").map { Double($0)! }
            if !regular { open("All Recipes") }
            scrollToRecipe(lasagna)
            sleep(2)
            mark("recipe")
            tapButton("Cook")
            mark("cook")
            sleep(4)
            for _ in 0..<3 { app.swipeLeft(); mark("swipe"); usleep(900_000) }
            sleep(1)
            mark("tap")
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: at[0], dy: at[1])).tap()
            mark("timer")
            sleep(6)
            app.swipeLeft()
            mark("next")
            sleep(4)
        default:
            XCTFail("Unknown scene \(scene)")
        }
        mark("end")
        sleep(1)
    }

    /// Safari already shows a recipe page (the recording script opens it). The steps come from APP_PREVIEW_TAPS, a `;` list of
    /// `t:x,y` (tap at a fraction of the screen), `w:seconds` and `m:name` (log an event). Safari's page is far too large to query,
    /// so everything is tapped by position through SpringBoard, which has a tiny hierarchy.
    private func shareFromSafari(landscape: Bool) throws {
        let script = ProcessInfo.processInfo.environment["APP_PREVIEW_TAPS"] ?? ""
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        safari.activate()
        sleep(3)
        mark("page")
        for step in script.split(separator: ";") {
            let parts = step.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "t":
                let xy = parts[1].split(separator: ",").map { Double($0)! }
                screen.coordinate(withNormalizedOffset: CGVector(dx: xy[0], dy: xy[1])).tap()
            case "d":
                let v = parts[1].split(separator: ",").map { Double($0)! }
                screen.coordinate(withNormalizedOffset: CGVector(dx: v[0], dy: v[1]))
                    .press(forDuration: 0.05, thenDragTo: screen.coordinate(withNormalizedOffset: CGVector(dx: v[2], dy: v[3])), withVelocity: .default, thenHoldForDuration: 0.1)
            case "w": usleep(UInt32(Double(parts[1])! * 1_000_000))
            case "m": mark(parts[1])
            default: break
            }
        }
        mark("end")
    }

    /// Switches Safari to the layout that keeps Share in the toolbar (Settings > Apps > Safari > Tabs). Prints what it sees, so the path can be fixed up.
    private func chooseSafariBottomLayout() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        sleep(2)
        func dump(_ tag: String) {
            print(tag, settings.descendants(matching: .any).allElementsBoundByIndex.prefix(300).compactMap { $0.label.isEmpty ? nil : "\($0.elementType.rawValue):\($0.label)" }.joined(separator: " | "))
        }
        dump("SETTINGS")
        let apps = settings.buttons["Apps"].firstMatch
        for _ in 0..<12 where !apps.exists { settings.swipeUp() }
        apps.tap(); sleep(2)
        dump("APPS")
        let safari = settings.buttons["Safari"].firstMatch
        for _ in 0..<20 where !safari.exists { settings.swipeUp() }
        safari.tap(); sleep(2)
        dump("SAFARI")
        for _ in 0..<6 { settings.swipeUp() }
        sleep(1)
        let bottom = settings.staticTexts["Bottom"].firstMatch
        XCTAssertTrue(bottom.exists, "No Bottom layout")
        bottom.tap()
        sleep(2)
        dump("SAFARI-2")
        mark("end")
    }

    /// A hard flick: a fast drag over most of the screen, so the page keeps travelling on its own for a second or so.
    private func fling(up: Bool) {
        let window = app.windows.firstMatch
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.85 : 0.2))
        let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.2 : 0.85))
        from.press(forDuration: 0.02, thenDragTo: to, withVelocity: 5000, thenHoldForDuration: 0)
    }

    private func mark(_ name: String) {
        print("APP_PREVIEW_EVENT \(name) \(Date().timeIntervalSince1970)")
    }

    /// A slow drag that scrolls the page by a fraction of the screen, so the recording shows smooth motion.
    private func glide(by fraction: Double) {
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fraction > 0 ? 0.75 : 0.3))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fraction > 0 ? 0.75 - fraction : 0.3 - fraction))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// iPad remembers whether the tab bar is in the sidebar; the App Store shots show it across the top.
    private func showTopTabBar() {
        let hide = app.buttons["Hide Sidebar"].firstMatch
        guard hide.waitForExistence(timeout: 5) else { return }
        hide.tap()
        sleep(2)
    }

    /// The library lists recipes by title, so a recipe late in the alphabet is below the fold. Scroll until it is on screen, then open it.
    private func scrollToRecipe(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        for _ in 0..<16 where !(row.exists && row.isHittable) { app.swipeUp(velocity: .default); usleep(400_000) }
        mark("found")
        sleep(1)
        openRecipe(title)
    }

    private func open(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No \(title)")
        row.tap()
        sleep(1)
    }

    private func openRecipe(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No \(title)")
        row.tap()
        sleep(2)
    }

    /// A tab is a button in the top tab bar, or a row in the sidebar when the tab bar is built into it.
    private func tab(_ name: String) {
        let places = [app.tabBars.buttons[name], app.buttons[name], app.cells.staticTexts[name], app.staticTexts[name]].map(\.firstMatch)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let target = places.first(where: { $0.exists && $0.isHittable }) {
                target.tap()
                sleep(1)
                return
            }
            usleep(300_000)
        }
        print(app.debugDescription)
        XCTFail("No tab \(name)")
    }

    private func tapButton(_ name: String) {
        XCTAssertTrue(app.buttons[name].firstMatch.waitForExistence(timeout: 8), "No button \(name)")
        let screen = app.windows.firstMatch.frame
        let candidates = app.buttons.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
        // Frames, not isHittable: a hidden copy has no hit point and makes XCTest fail. The visible one is the lowest.
        guard let button = candidates
            .filter({ $0.exists && !$0.frame.isEmpty && screen.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) })
            .max(by: { $0.frame.minY < $1.frame.minY }) else {
            return XCTFail("No visible button \(name)")
        }
        button.tap()
    }
}
#endif
