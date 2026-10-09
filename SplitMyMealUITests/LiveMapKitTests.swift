import XCTest
import UIKit

/// Opt-in live Apple Maps integration. CI excludes this suite because provider
/// availability is external; unavailable responses are retained as explicit skips.
@MainActor
final class LiveMapKitTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // Reset before launching so no already-created CLLocationManager retains
        // the previous authorization state while the protected resource resets.
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["meal-Dinner at Juniper"].waitForExistence(timeout: 10))
        app.buttons["meal-Dinner at Juniper"].tap()
    }

    override func tearDown() async throws {
        evidence("live-mapkit-final-state")
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    func testLiveRestaurantSearchSelectionMapAndRemoval() throws {
        app.buttons["edit-meal"].tap()
        app.buttons["choose-restaurant"].tap()
        XCTAssertTrue(app.navigationBars["Restaurant"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Blue Bottle Coffee San Francisco")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "restaurant-result-")).firstMatch
        guard result.waitForExistence(timeout: 25) else {
            evidence("live-mapkit-autocomplete-unavailable")
            throw XCTSkip("Apple Maps returned no completion within 25 seconds. See retained screenshot and accessibility tree for its actual error/empty state.")
        }
        let selectedTitle = String(result.identifier.dropFirst("restaurant-result-".count).split(separator: "\n").first ?? "")
        XCTAssertFalse(selectedTitle.isEmpty)
        evidence("live-mapkit-autocomplete-results")
        result.tap()
        let resolved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["save-meal"])
        guard XCTWaiter.wait(for: [resolved], timeout: 25) == .completed else {
            evidence("live-mapkit-resolution-unavailable")
            if app.alerts["Couldn’t select restaurant"].exists {
                throw XCTSkip("Apple Maps completion resolution failed with the provider error retained in the native alert.")
            }
            XCTFail("Restaurant selection did not resolve or present an actionable error.")
            return
        }
        app.buttons["save-meal"].tap()
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", selectedTitle)).firstMatch
        for _ in 0..<6 where !restaurant.isHittable { app.swipeUp() }
        XCTAssertTrue(restaurant.waitForExistence(timeout: 5))
        restaurant.tap()
        XCTAssertTrue(app.buttons["Open in Maps"].waitForExistence(timeout: 10))
        evidence("live-selected-restaurant-map")
        app.buttons["Open in Maps"].tap()
        let maps = XCUIApplication(bundleIdentifier: "com.apple.Maps")
        XCTAssertTrue(maps.wait(for: .runningForeground, timeout: 15), "The selected restaurant must open the native Maps app.")
        if maps.staticTexts["Get Notified When Friends Share Their ETAs"].waitForExistence(timeout: 3) {
            // The dedicated simulator's first Maps launch offers optional
            // notifications. Decline that onboarding without granting access.
            maps.buttons["Not Now"].tap()
        }
        if maps.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Maps may show local ads")).firstMatch.waitForExistence(timeout: 3) {
            // Acknowledge the observed anonymous simulator's Maps information
            // screen; this does not grant a protected-resource permission.
            maps.buttons["Continue"].tap()
        }
        let destination = maps.staticTexts.matching(NSPredicate(format: "label == %@", selectedTitle)).firstMatch
        let destinationLoaded = destination.waitForExistence(timeout: 20)
        let mapsPixels = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        mapsPixels.name = "selected-restaurant-opened-in-native-maps"
        mapsPixels.lifetime = .keepAlways
        add(mapsPixels)
        let mapsTree = XCTAttachment(string: maps.debugDescription)
        mapsTree.name = "selected-restaurant-native-maps-accessibility-tree"
        mapsTree.lifetime = .keepAlways
        add(mapsTree)
        XCTAssertTrue(destinationLoaded, "Native Maps must show the selected restaurant after the handoff settles.")
        XCTAssertTrue(maps.frame.contains(destination.frame), "The exact destination title must be within the native Maps viewport.")
        app.activate()
        XCTAssertTrue(app.buttons["Open in Maps"].waitForExistence(timeout: 10), "Returning to the meal keeps its restaurant map presentation.")
        app.buttons["Done"].tap()
        app.buttons["edit-meal"].tap()
        app.buttons["remove-restaurant"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(restaurant.exists, "Cancel preserves the selected restaurant.")
        app.buttons["edit-meal"].tap()
        app.buttons["remove-restaurant"].tap()
        app.buttons["save-meal"].tap()
        XCTAssertFalse(restaurant.exists, "Save commits restaurant removal.")
        XCTAssertTrue(app.buttons["Add restaurant"].exists)
    }

    func testNearbyLocationDeniedStillAllowsTextSearchAndCancellation() throws {
        app.buttons["edit-meal"].tap()
        let title = app.textFields["meal-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let originalTitle = title.value as? String ?? ""
        XCTAssertEqual(originalTitle, "Dinner at Juniper")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalTitle.count) + "Location recovery draft")
        XCTAssertEqual(title.value as? String, "Location recovery draft")
        let done = app.buttons.matching(NSPredicate(format: "label == %@", "Done")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(done, "The focused editor must expose its keyboard Done action.")
        done?.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["choose-restaurant"].tap()
        app.buttons["nearby-restaurants"].tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(permission.waitForExistence(timeout: 10))
        let denied = permission.buttons.allElementsBoundByIndex.first { $0.label.contains("Don") && $0.label.contains("Allow") }
        guard let denied else {
            evidence("location-authorization-prompt-unavailable")
            throw XCTSkip("The simulator did not expose a fresh location permission prompt.")
        }
        denied.tap()
        XCTAssertTrue(app.staticTexts["restaurant-location-error"].waitForExistence(timeout: 10))
        evidence("nearby-location-denied")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.isEnabled)
        search.tap()
        search.typeText("Coffee")
        XCTAssertEqual(search.value as? String, "Coffee")
        if UIDevice.current.userInterfaceIdiom == .pad {
            // The centered native search sheet moves as its keyboard settles.
            // Dismiss that keyboard before resolving the Settings link's hit point.
            let hideKeyboard = app.keyboards.buttons["Hide keyboard"]
            XCTAssertTrue(hideKeyboard.waitForExistence(timeout: 5))
            XCTAssertTrue(hideKeyboard.isHittable)
            hideKeyboard.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            XCTAssertEqual(search.value as? String, "Coffee", "Dismissing the native keyboard must preserve the restaurant query.")
        }
        app.links["restaurant-open-settings"].tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15), "Denied location recovery must open native Settings.")
        XCTAssertTrue(settings.windows.firstMatch.waitForExistence(timeout: 10), "Native Settings must finish presenting its window.")
        let settingsPixels = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsPixels.name = "denied-location-opened-in-native-settings"
        settingsPixels.lifetime = .keepAlways
        add(settingsPixels)
        let settingsTree = XCTAttachment(string: settings.debugDescription)
        settingsTree.name = "denied-location-native-settings-accessibility-tree"
        settingsTree.lifetime = .keepAlways
        add(settingsTree)
        app.activate()
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Returning to the active restaurant search preserves its presentation.")
        XCTAssertEqual(search.value as? String, "Coffee", "Returning from Settings preserves the restaurant query.")
        XCTAssertTrue(search.isEnabled)
        evidence("denied-location-settings-return-preserves-query")
        let closeSearch = app.buttons["close"].firstMatch
        if closeSearch.exists { closeSearch.tap() }
        cancelRestaurantSelection()
        XCTAssertEqual(title.value as? String, "Location recovery draft", "Returning from Settings preserves the unsaved meal draft.")
        app.buttons["Cancel"].tap()
        assertOriginalRestaurant()

        // Preserve the denied authorization and the saved fixture while testing
        // the map's expanded recovery pane at the largest native text size.
        app.terminate()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchForMealTesting()
        app.buttons["meal-Dinner at Juniper"].tap()
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Juniper · sample restaurant")).firstMatch
        let footer = app.buttons["view-split"]
        XCTAssertTrue(footer.waitForExistence(timeout: 5))
        let foregroundLists = app.collectionViews.allElementsBoundByIndex.filter {
            $0.frame.contains(CGPoint(x: footer.frame.midX, y: footer.frame.minY - 20))
        }
        let mealList = foregroundLists.min { $0.frame.width < $1.frame.width }
        XCTAssertNotNil(mealList, "The saved meal must expose its foreground detail list.")
        if let mealList {
            var movements: [String] = []
            func viewport() -> (top: CGFloat, bottom: CGFloat) {
                let navBottom = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.maxY }.max() ?? mealList.frame.minY
                return (max(navBottom, mealList.frame.minY), min(footer.frame.minY - 20, mealList.frame.maxY - 4))
            }
            for attempt in 0..<24 {
                let bounds = viewport()
                if restaurant.exists && restaurant.frame.minY > bounds.top && restaurant.frame.maxY < bounds.bottom && restaurant.isHittable { break }
                let before = restaurant.exists ? String(describing: restaurant.frame) : "not instantiated"
                let gap = restaurant.exists ? (restaurant.frame.minY <= bounds.top ? bounds.top - restaurant.frame.minY + 12 : restaurant.frame.maxY - bounds.bottom + 12) : nil
                // This saved meal opens at the top; Restaurant follows its
                // people, items and charges. Keep seeking downward until the
                // lazy row exists instead of reversing halfway through a long
                // largest-text list and returning to the summary.
                let up = restaurant.exists ? restaurant.frame.minY > bounds.top : true
                let top = bounds.top + 20
                let bottom = bounds.bottom - 20
                XCTAssertGreaterThan(bottom, top, "The foreground meal list must have a usable scroll viewport.")
                let origin = mealList.coordinate(withNormalizedOffset: .zero)
                let leading = max(mealList.frame.minX + 8, footer.frame.minX - 8) - mealList.frame.minX
                let travel = gap.map { min(max($0, 20), min(150, (bottom - top) * 0.5)) } ?? (bottom - top) * 0.6
                let middle = (top + bottom) * 0.5 - mealList.frame.minY
                let upper = origin.withOffset(CGVector(dx: leading, dy: middle - travel * 0.5))
                let lower = origin.withOffset(CGVector(dx: leading, dy: middle + travel * 0.5))
                (up ? lower : upper).press(forDuration: 0.1, thenDragTo: up ? upper : lower, withVelocity: .slow, thenHoldForDuration: 0.2)
                movements.append("Attempt \(attempt): before \(before); after \(restaurant.exists ? String(describing: restaurant.frame) : "not instantiated"); viewport \(bounds.top)...\(bounds.bottom); gesture x \(mealList.frame.minX + leading); up \(up)")
            }
            let geometry = XCTAttachment(string: movements.joined(separator: "\n"))
            geometry.name = "denied-map-restaurant-row-scroll-geometry"
            geometry.lifetime = .keepAlways
            add(geometry)
            let bounds = viewport()
            XCTAssertGreaterThan(restaurant.frame.minY, bounds.top, "The entire restaurant row must be below the foreground toolbar.")
            XCTAssertLessThan(restaurant.frame.maxY, bounds.bottom, "The entire restaurant row must be above View split before tapping its center.")
        }
        XCTAssertTrue(restaurant.isHittable)
        XCTAssertEqual(restaurant.label, "Juniper · sample restaurant, Fictional dinner for app screenshots", "The complete saved title and address must remain available to accessibility at the largest text size.")
        evidence("denied-map-largest-text-saved-restaurant-row")
        restaurant.tap()
        XCTAssertTrue(app.buttons["Show my location"].waitForExistence(timeout: 5))
        app.buttons["Show my location"].tap()
        XCTAssertTrue(app.staticTexts["Location access is off."].waitForExistence(timeout: 5))
        func rotate(_ orientation: UIDeviceOrientation) {
            XCUIDevice.shared.orientation = orientation
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = XCUIApplication().frame
                return orientation == .portrait ? frame.height > frame.width : frame.width > frame.height
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
            Thread.sleep(forTimeInterval: 1)
        }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            rotate(orientation)
            assertReadableRestaurantMap(app, title: "Juniper · sample restaurant", address: "Fictional dinner for app screenshots", orientation: orientation, capturePrefix: "restaurant-map-denied-accessibility-text")
        }
        rotate(.portrait)
        assertReadableRestaurantMap(app, title: "Juniper · sample restaurant", address: "Fictional dinner for app screenshots", orientation: .portrait, capturePrefix: "restaurant-map-denied-before-settings")
        let settingsLink = app.links["map-open-settings"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsLink.isHittable)
        settingsLink.tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15), "The map's denied-location recovery must open native Settings.")
        XCTAssertTrue(settings.windows.firstMatch.waitForExistence(timeout: 10))
        app.activate()
        XCTAssertTrue(app.navigationBars["Juniper · sample restaurant"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Location access is off."].exists)
        XCTAssertFalse(permission.exists, "Returning from Settings must preserve the map without automatically requesting location.")
        evidence("denied-map-settings-return-preserves-saved-restaurant")
        app.navigationBars["Juniper · sample restaurant"].buttons["Done"].tap()
        assertOriginalRestaurant()
    }

    func testNearbyLocationAllowedUsesSyntheticSimulatorCoordinate() throws {
        app.buttons["edit-meal"].tap()
        app.buttons["choose-restaurant"].tap()
        app.buttons["nearby-restaurants"].tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(permission.waitForExistence(timeout: 10))
        let allow = permission.buttons.matching(NSPredicate(format: "label CONTAINS %@", "While Using")).firstMatch
        XCTAssertTrue(allow.exists)
        allow.tap()
        guard app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Using your location")).firstMatch.waitForExistence(timeout: 15) else {
            evidence("synthetic-nearby-location-unavailable")
            throw XCTSkip("The simulator did not deliver the synthetic location. Its actual state is retained.")
        }
        evidence("nearby-location-allowed-synthetic")
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Coffee")
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        XCTAssertTrue(settings.windows.firstMatch.waitForExistence(timeout: 10))
        let apps = settings.buttons["Apps"]
        for _ in 0..<6 where !apps.isHittable { settings.swipeUp() }
        XCTAssertTrue(apps.waitForExistence(timeout: 5), "Native Settings must expose its installed Apps list.")
        apps.tap()
        // iPad Settings exposes both sidebar Search and the Apps detail search.
        // Only the latter filters the installed apps list used for revocation.
        let appSearch = UIDevice.current.userInterfaceIdiom == .pad
            ? settings.searchFields["Search Apps"]
            : settings.searchFields.firstMatch
        XCTAssertTrue(appSearch.waitForExistence(timeout: 5))
        appSearch.tap()
        appSearch.typeText("Split My Meal")
        let ownApp = settings.staticTexts["Split My Meal"].firstMatch
        XCTAssertTrue(ownApp.waitForExistence(timeout: 10))
        ownApp.tap()
        let location = settings.staticTexts["Location"].firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        location.tap()
        let askAgain = settings.staticTexts["Ask Next Time or When I Share"].firstMatch
        XCTAssertTrue(askAgain.waitForExistence(timeout: 5))
        askAgain.tap()
        let askTree = XCTAttachment(string: settings.debugDescription)
        askTree.name = "native-settings-ask-next-time-accessibility-tree"
        askTree.lifetime = .keepAlways
        add(askTree)
        app.activate()
        let cacheCleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Use my location"), object: app.buttons["nearby-restaurants"])
        XCTAssertEqual(XCTWaiter.wait(for: [cacheCleared], timeout: 5), .completed)
        XCTAssertFalse(permission.exists, "Ask Next Time must not request location automatically on return.")
        XCTAssertFalse(app.staticTexts["restaurant-location-error"].exists)
        XCTAssertFalse(app.links["restaurant-open-settings"].exists)
        XCTAssertEqual(search.value as? String, "Coffee")
        evidence("idle-ask-next-time-clears-cached-nearby-without-prompt")
        let closeForReauthorization = app.buttons["close"].firstMatch
        if closeForReauthorization.exists { closeForReauthorization.tap() }
        app.buttons["nearby-restaurants"].tap()
        XCTAssertTrue(permission.waitForExistence(timeout: 10), "An explicit Nearby retry must request permission again.")
        allow.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Using your location")).firstMatch.waitForExistence(timeout: 15))
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Inline iPad search retains the query across explicit reauthorization.
            XCTAssertEqual(search.value as? String, "Coffee", "Requesting permission again preserves the existing restaurant query.")
        } else {
            search.tap()
            search.typeText("Coffee")
        }
        settings.activate()
        let never = settings.staticTexts["Never"].firstMatch
        XCTAssertTrue(never.waitForExistence(timeout: 5))
        never.tap()
        let revoked = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        revoked.name = "native-settings-revokes-cached-nearby-location"
        revoked.lifetime = .keepAlways
        add(revoked)
        let revokedTree = XCTAttachment(string: settings.debugDescription)
        revokedTree.name = "native-settings-location-permission-accessibility-tree"
        revokedTree.lifetime = .keepAlways
        add(revokedTree)
        app.activate()
        XCTAssertTrue(app.staticTexts["restaurant-location-error"].waitForExistence(timeout: 10), "Revoking permission while idle must replace cached nearby status with an actionable error.")
        XCTAssertTrue(app.buttons["nearby-restaurants"].label.contains("Use my location"))
        XCTAssertTrue(app.links["restaurant-open-settings"].exists)
        XCTAssertEqual(search.value as? String, "Coffee", "Idle revocation preserves the independently editable restaurant query.")
        evidence("idle-location-revocation-clears-cached-nearby-status")
        let closeForCancellation = app.buttons["close"].firstMatch
        if closeForCancellation.exists { closeForCancellation.tap() }
        cancelRestaurantSelection()
        app.buttons["Cancel"].tap()
    }

    func testRapidQueryCancellationLeavesOriginalRestaurant() throws {
        app.buttons["edit-meal"].tap()
        app.buttons["choose-restaurant"].tap()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Coffee San Francisco")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        search.typeText("Pizza New York")
        let closeSearch = app.buttons["close"].firstMatch
        if closeSearch.exists { closeSearch.tap() }
        cancelRestaurantSelection()
        app.buttons["Cancel"].tap()
        assertOriginalRestaurant()
        evidence("live-rapid-query-cancelled")
    }

    func testSameQueryRetryRecoversAfterStagedFailureUsingLiveMapKit() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "--fail-first-restaurant-search"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["meal-Dinner at Juniper"].waitForExistence(timeout: 10))
        app.buttons["meal-Dinner at Juniper"].tap()
        app.buttons["edit-meal"].tap()
        app.buttons["choose-restaurant"].tap()
        let search = app.searchFields.firstMatch
        let query = "Blue Bottle Coffee San Francisco"
        search.tap()
        search.typeText(query)
        XCTAssertTrue(app.staticTexts["restaurant-search-error"].waitForExistence(timeout: 10), "The isolated DEBUG fixture must expose the actual retry control before any provider request.")
        XCTAssertEqual(search.value as? String, query)
        evidence("restaurant-staged-search-failure-with-retry")
        app.buttons["retry-restaurant-search"].tap()
        XCTAssertEqual(search.value as? String, query, "Retry must preserve the complete restaurant query.")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "restaurant-result-")).firstMatch
        guard result.waitForExistence(timeout: 25) else {
            evidence("restaurant-retry-live-provider-unavailable")
            throw XCTSkip("The staged error and same-query Retry were exercised, but Apple Maps returned no real suggestions within 25 seconds. Retained evidence distinguishes the fixture from the unavailable provider.")
        }
        XCTAssertFalse(app.staticTexts["restaurant-search-error"].exists)
        XCTAssertEqual(search.value as? String, query)
        evidence("restaurant-same-query-retry-live-suggestions")
        let closeSearch = app.buttons["close"].firstMatch
        if closeSearch.exists { closeSearch.tap() }
        cancelRestaurantSelection()
        app.buttons["Cancel"].tap()
        assertOriginalRestaurant()
        evidence("restaurant-retry-cancel-preserves-saved-restaurant")
    }

    /// Cancels the foreground search sheet after retaining its query through native keyboard dismissal.
    private func cancelRestaurantSelection() {
        if UIDevice.current.userInterfaceIdiom == .pad, app.keyboards.firstMatch.exists {
            let search = app.searchFields.firstMatch
            let originalQuery = search.value as? String
            let hideKeyboard = app.keyboards.buttons["Hide keyboard"]
            XCTAssertTrue(hideKeyboard.waitForExistence(timeout: 5))
            XCTAssertTrue(hideKeyboard.isHittable)
            hideKeyboard.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            XCTAssertEqual(search.value as? String, originalQuery, "Keyboard dismissal must preserve the pending restaurant query.")
        }
        // A centered iPad sheet moves during keyboard layout. Resolve its native
        // Cancel only after the keyboard has disappeared, then verify dismissal
        // before any background editor control can satisfy the next query.
        let restaurant = app.navigationBars["Restaurant"]
        let cancel = restaurant.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable)
        XCTAssertEqual(app.state, .runningForeground)
        cancel.tap()
        XCTAssertTrue(restaurant.waitForNonExistence(timeout: 5), "Cancel must dismiss restaurant selection before returning to the meal draft.")
    }

    private func assertOriginalRestaurant() {
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Juniper")).firstMatch
        // The saved restaurant is a lazy row below People and Items.
        for _ in 0..<6 where !restaurant.isHittable { app.swipeUp() }
        XCTAssertTrue(restaurant.waitForExistence(timeout: 5))
        XCTAssertTrue(restaurant.isHittable, "Cancellation preserves a reachable saved restaurant.")
    }

    /// Applies the supported native app launch boundary before any store opens.
    private func launchForMealTesting() {
        guard app.launchArguments.contains("--uitesting") else {
            XCTFail("Every UI app launch must use the isolated local test store.")
            return
        }
        let arguments = XCTAttachment(string: String(describing: app.launchArguments))
        arguments.name = "isolated-ui-launch-arguments"
        arguments.lifetime = .keepAlways
        add(arguments)
        app.launch()
    }

    private func evidence(_ name: String) {
        guard app != nil else { return }
        let pixels = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        pixels.name = name
        pixels.lifetime = .keepAlways
        add(pixels)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
