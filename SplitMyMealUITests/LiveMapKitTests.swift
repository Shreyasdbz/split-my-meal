import XCTest

/// Opt-in live Apple Maps integration. CI excludes this suite because provider
/// availability is external; unavailable responses are retained as explicit skips.
@MainActor
final class LiveMapKitTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
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
        app.buttons["close"].firstMatch.tap()
        app.navigationBars["Restaurant"].buttons["Cancel"].tap()
        XCTAssertEqual(title.value as? String, "Location recovery draft", "Returning from Settings preserves the unsaved meal draft.")
        app.buttons["Cancel"].tap()
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
        guard app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Nearby search enabled")).firstMatch.waitForExistence(timeout: 15) else {
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
        let appSearch = settings.searchFields.firstMatch
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
        let cacheCleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Search near me"), object: app.buttons["nearby-restaurants"])
        XCTAssertEqual(XCTWaiter.wait(for: [cacheCleared], timeout: 5), .completed)
        XCTAssertFalse(permission.exists, "Ask Next Time must not request location automatically on return.")
        XCTAssertFalse(app.staticTexts["restaurant-location-error"].exists)
        XCTAssertFalse(app.links["restaurant-open-settings"].exists)
        XCTAssertEqual(search.value as? String, "Coffee")
        evidence("idle-ask-next-time-clears-cached-nearby-without-prompt")
        app.buttons["close"].firstMatch.tap()
        app.buttons["nearby-restaurants"].tap()
        XCTAssertTrue(permission.waitForExistence(timeout: 10), "An explicit Nearby retry must request permission again.")
        allow.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Nearby search enabled")).firstMatch.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Coffee")
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
        XCTAssertTrue(app.buttons["nearby-restaurants"].label.contains("Search near me"))
        XCTAssertTrue(app.links["restaurant-open-settings"].exists)
        XCTAssertEqual(search.value as? String, "Coffee", "Idle revocation preserves the independently editable restaurant query.")
        evidence("idle-location-revocation-clears-cached-nearby-status")
        app.buttons["close"].firstMatch.tap()
        app.navigationBars["Restaurant"].buttons["Cancel"].tap()
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
        app.buttons["close"].firstMatch.tap()
        app.navigationBars["Restaurant"].buttons["Cancel"].tap()
        app.buttons["Cancel"].tap()
        assertOriginalRestaurant()
        evidence("live-rapid-query-cancelled")
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
