import XCTest
import UIKit

/// Exercises the app's real local SwiftData store and native navigation using an
/// isolated test store. Each journey starts empty; relaunch tests preserve it.
@MainActor
final class MealJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        launchForMealTesting()
    }

    override func tearDown() async throws {
        if let run = testRun, run.failureCount > 0 {
            screenshot("failure-" + name)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "failure-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    func testCreateEditSplitShareAndPersistence() throws {
        // Hosted iOS 27 automation reached the share/relaunch steps after four
        // minutes. Budget the complete multi-launch journey without extending
        // its individual control waits or retrying a failed test.
        executionTimeAllowance = 420
        createMeal("Dinner with friends")
        addPerson("Alice")
        addPerson("Bob")
        tapScrollable("add-item")
        fill("item-name", "Pizza")
        fill("item-price", "24.00")
        enableSwitch("item-consumer-Alice")
        enableSwitch("item-consumer-Bob")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.buttons["item-Pizza"].waitForExistence(timeout: 5))

        tapScrollable("edit-tax")
        replace("charge-value", with: "10")
        app.buttons["save-charge"].tap()
        tapScrollable("edit-tip")
        replace("charge-value", with: "20")
        app.buttons["save-charge"].tap()
        screenshot("meal-with-people-items-and-charges")

        app.buttons["view-split"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["split-Alice"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["split-Bob"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "15.84")).firstMatch.exists)
        screenshot("balanced-split")
        app.buttons["share-split"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].waitForExistence(timeout: 5), "The native share sheet should open.")
        screenshot("native-share-sheet")
        closeShareSheet()
        app.terminate()

        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["meal-Dinner with friends"].firstMatch.waitForExistence(timeout: 5), "Saved meals survive a real process relaunch.")
        app.buttons["meal-Dinner with friends"].firstMatch.tap()
        XCTAssertTrue(app.buttons["item-Pizza"].waitForExistence(timeout: 5))
        app.buttons["edit-meal"].tap()
        replace("meal-title", with: "Updated dinner")
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.navigationBars.containing(NSPredicate(format: "identifier CONTAINS %@", "Updated dinner")).firstMatch.waitForExistence(timeout: 5))
        screenshot("edited-meal")
    }

    func testCancelledMealDoesNotPersist() throws {
        app.buttons["new-meal"].tap()
        fill("meal-title", "Cancelled dinner")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["meal-Cancelled dinner"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        XCTAssertFalse(app.buttons["meal-Cancelled dinner"].exists)
    }

    func testInvalidInputsCannotBeSavedAndCancelLeavesMealUnchanged() throws {
        app.buttons["new-meal"].tap()
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.alerts["Couldn’t update meal"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["Cancel"].tap()
        createMeal("Validation dinner")
        tapScrollable("add-person")
        app.buttons["save-person"].tap()
        XCTAssertTrue(app.alerts["Couldn’t update person"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        fill("person-name", "Unsaved person")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Unsaved person"].exists)
        tapScrollable("add-item")
        fill("item-name", "Unsaved dessert")
        fill("item-price", "0")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.alerts["Couldn’t update item"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Unsaved dessert"].exists)
    }

    func testEditAndDeleteItemPersonAndMeal() throws {
        createMeal("Cleanup dinner")
        addPerson("Charlie")
        tapScrollable("person-Charlie")
        replace("person-name", with: "Casey")
        app.buttons["save-person"].tap()
        XCTAssertTrue(app.buttons["person-Casey"].waitForExistence(timeout: 5))
        tapScrollable("add-item")
        fill("item-name", "Salad")
        fill("item-price", "12.00")
        enableSwitch("item-consumer-Casey")
        app.buttons["save-item"].tap()
        tapScrollable("item-Salad")
        replace("item-name", with: "Green salad")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.buttons["item-Green salad"].waitForExistence(timeout: 5))
        tapScrollable("item-Green salad")
        app.buttons["delete-item"].tap()
        app.buttons["confirm-delete-item"].firstMatch.tap()
        XCTAssertTrue(app.buttons["item-Green salad"].waitForNonExistence(timeout: 5))
        tapScrollable("person-Casey")
        app.buttons["delete-person"].tap()
        app.buttons["confirm-delete-person"].firstMatch.tap()
        XCTAssertTrue(app.buttons["person-Casey"].waitForNonExistence(timeout: 5))
        app.buttons["edit-meal"].tap()
        app.buttons["delete-meal"].tap()
        app.buttons["confirm-delete-meal"].firstMatch.tap()
        XCTAssertTrue(app.buttons["new-meal"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        XCTAssertFalse(app.buttons["meal-Cleanup dinner"].exists)
    }

    func testLargeTextAndLandscapeNavigation() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["new-meal"].waitForExistence(timeout: 5))
        screenshot("home-accessibility-text")
        app.buttons["new-meal"].tap()
        XCTAssertTrue(app.textFields["meal-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        app.buttons["Cancel"].tap()
        openDemo()
        screenshot("meal-accessibility-text")
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.navigationBars["Split summary"].waitForExistence(timeout: 5))
        let largeSplit = app.descendants(matching: .any)["split-Alex"].firstMatch
        for _ in 0..<12 where !largeSplit.exists { scrollContent(up: true) }
        XCTAssertTrue(largeSplit.exists, "A person’s split must remain reachable at the largest text size.")
        screenshot("split-accessibility-text")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        tapScrollable("person-Alex")
        screenshot("person-editor-accessibility-text")
        app.buttons["Cancel"].tap()
        tapScrollable("item-Miso ramen")
        screenshot("item-editor-accessibility-text")
        app.buttons["Cancel"].tap()
        tapScrollable("edit-tax")
        XCTAssertTrue(app.textFields["charge-value"].waitForExistence(timeout: 5))
        screenshot("charge-editor-accessibility-text")
        app.buttons["Cancel"].tap()
        app.buttons["edit-meal"].tap()
        XCTAssertTrue(app.textFields["meal-title"].waitForExistence(timeout: 5))
        screenshot("meal-editor-accessibility-text-title")
        revealButton("choose-receipt")
        screenshot("meal-editor-accessibility-text-receipt")
        app.buttons["Cancel"].tap()
        returnToLibrary()
        settleOrientation(.landscapeLeft)
        XCTAssertTrue(app.buttons["new-meal"].waitForExistence(timeout: 5))
        screenshot("home-landscape-accessibility-text")
    }

    func testReverseAssignmentFixedChargesConversionCancelAndClear() throws {
        createMeal("Assignment dinner")
        addPerson("Riley")
        tapScrollable("add-item")
        fill("item-name", "Noodles")
        fill("item-price", "20")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["unassigned-warning"].firstMatch.waitForExistence(timeout: 5))
        tapScrollable("person-Riley")
        enableSwitch("person-item-Noodles")
        app.buttons["save-person"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["unassigned-warning"].firstMatch.exists)
        tapScrollable("edit-tax")
        app.buttons["Amount"].tap()
        replace("charge-value", with: "2")
        dismissKeyboard()
        app.buttons["Percentage"].tap()
        XCTAssertEqual(app.textFields["charge-value"].value as? String, "10")
        app.buttons["save-charge"].tap()
        tapScrollable("edit-tip")
        app.buttons["Amount"].tap()
        replace("charge-value", with: "3")
        app.buttons["save-charge"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$25.00")
        tapScrollable("edit-tax")
        replace("charge-value", with: "50")
        app.buttons["Cancel"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$25.00")
        tapScrollable("edit-tax")
        app.buttons["clear-charge"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$23.00")
        tapScrollable("edit-tip")
        app.buttons["clear-charge"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$20.00")
        screenshot("reverse-assignment-and-cleared-charges")
    }

    func testReceiptViewZoomShareAndDraftRemoval() throws {
        launchDemo()
        openDemo()
        tapScrollable("View receipt")
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 5))
        let photo = app.images["receipt-photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        let zoom = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Zoom ")).firstMatch
        screenshot("receipt-before-native-pinch")
        let beforePinch = XCTAttachment(string: "Image frame: \(photo.frame); zoom: \(zoom.label)")
        beforePinch.name = "receipt-before-native-pinch-geometry"
        beforePinch.lifetime = .keepAlways
        add(beforePinch)
        // On iPad a 2x synthesized pinch travels only about 14 points per finger.
        // A wider native gesture exercises the same shipped zoom interaction.
        photo.pinch(withScale: 4, velocity: 1)
        let afterPinch = XCTAttachment(string: "Image frame: \(photo.frame); zoom: \(zoom.label)")
        afterPinch.name = "receipt-after-native-pinch-geometry"
        afterPinch.lifetime = .keepAlways
        add(afterPinch)
        let magnified = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Zoom 100 percent"), object: zoom)
        XCTAssertEqual(XCTWaiter.wait(for: [magnified], timeout: 5), .completed)
        screenshot("receipt-native-pinch-zoom")
        photo.doubleTap()
        let fitted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Zoom 100 percent"), object: zoom)
        XCTAssertEqual(XCTWaiter.wait(for: [fitted], timeout: 5), .completed)
        photo.doubleTap()
        let doubleMagnified = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Zoom 100 percent"), object: zoom)
        XCTAssertEqual(XCTWaiter.wait(for: [doubleMagnified], timeout: 5), .completed)
        settleOrientation(.landscapeLeft)
        let rotationFit = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Zoom 100 percent"), object: zoom)
        XCTAssertEqual(XCTWaiter.wait(for: [rotationFit], timeout: 5), .completed)
        screenshot("receipt-native-rotation-fit-landscape")
        settleOrientation(.portrait)
        app.buttons["Zoom in"].tap()
        XCTAssertTrue(app.buttons["Zoom out"].isEnabled)
        screenshot("receipt-zoomed")
        app.buttons["Zoom out"].tap()
        app.buttons["share-receipt"].tap()
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5) || app.otherElements["ActivityListView"].exists)
        screenshot("receipt-native-sharing")
        closeShareSheet()
        app.buttons["Close"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        openDemo()
        app.buttons["edit-meal"].tap()
        tapScrollable("Remove receipt")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(revealButton("View receipt").exists, "Cancelled receipt removal preserves the original photo.")
        app.buttons["edit-meal"].tap()
        tapScrollable("Remove receipt")
        app.buttons["save-meal"].tap()
        XCTAssertTrue(revealButton("Attach receipt").exists)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        openDemo()
        XCTAssertTrue(revealButton("Attach receipt").exists, "Saved receipt removal survives a process relaunch.")
    }

    func testNativePhotoAttachmentReplacementCancelAndSave() throws {
        createMeal("Photo dinner")
        app.buttons["edit-meal"].tap()
        choosePhoto(at: 0)
        XCTAssertTrue(revealButton("Remove receipt").exists)
        screenshot("photo-attachment-draft")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(revealButton("Attach receipt").exists)
        app.buttons["edit-meal"].tap()
        choosePhoto(at: 0)
        XCTAssertTrue(revealButton("Remove receipt").exists)
        app.buttons["save-meal"].tap()
        XCTAssertTrue(revealButton("View receipt").exists)
        tapScrollable("View receipt")
        let originalImage = receiptPixels("photo-original-saved-image")
        app.buttons["Close"].tap()
        app.buttons["edit-meal"].tap()
        choosePhoto(at: 1)
        XCTAssertTrue(revealButton("Remove receipt").exists)
        screenshot("photo-replacement-draft")
        app.buttons["Cancel"].tap()
        tapScrollable("View receipt")
        XCTAssertEqual(receiptPixels("photo-cancelled-replacement-preserves-image"), originalImage, "Cancelling replacement must preserve the saved image pixels.")
        app.buttons["Close"].tap()
        app.buttons["edit-meal"].tap()
        choosePhoto(at: 1)
        XCTAssertTrue(revealButton("Remove receipt").exists)
        app.buttons["save-meal"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        app.buttons["meal-Photo dinner"].tap()
        tapScrollable("View receipt")
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(receiptPixels("photo-saved-replacement-survives-relaunch"), originalImage, "Saving another fixture must replace the actual image, including after a process relaunch.")
        screenshot("photo-replacement-persisted")
    }

    func testLibrarySearchSortAndRestaurantPickerCancellation() throws {
        launchDemo()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("No matching meal xyz")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "No Results")).firstMatch.waitForExistence(timeout: 5))
        screenshot("library-search-no-results")
        clearLibrarySearch()
        app.buttons["Sort meals"].tap()
        app.buttons["Title"].tap()
        openDemo()
        app.buttons["edit-meal"].tap()
        app.buttons["choose-restaurant"].tap()
        XCTAssertTrue(app.navigationBars["Restaurant"].waitForExistence(timeout: 5))
        let restaurantSearch = app.searchFields.firstMatch
        restaurantSearch.tap()
        restaurantSearch.typeText("X")
        XCTAssertTrue(app.staticTexts["Enter a restaurant name, address, or city."].waitForExistence(timeout: 5))
        screenshot("restaurant-text-search")
        let closeSearch = app.buttons["close"].firstMatch
        if closeSearch.exists { closeSearch.tap() }
        XCTAssertTrue(app.navigationBars["Restaurant"].buttons["Cancel"].isHittable)
        app.navigationBars["Restaurant"].buttons["Cancel"].tap()
        app.buttons["Cancel"].tap()
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Juniper · sample restaurant")).firstMatch
        XCTAssertTrue(revealButton(restaurant, name: "saved-restaurant-after-cancel").exists)
    }

    /// Produces principal screen evidence and a repeatable source for simulator video capture.
    func testDemoWalkthrough() throws {
        launchDemo()
        screenshot("demo-library-light")
        openDemo()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$113.66")
        screenshot("demo-meal-light")
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["split-Alex"].firstMatch.waitForExistence(timeout: 5))
        screenshot("demo-split-light")
        app.descendants(matching: .any)["split-Alex"].firstMatch.tap()
        screenshot("demo-itemized-split-light")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        tapScrollable("View receipt")
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 5))
        screenshot("demo-receipt-light")
        app.buttons["Close"].tap()
        app.buttons["edit-meal"].tap()
        screenshot("demo-meal-editor-light")
        app.buttons["Cancel"].tap()
        settleOrientation(.landscapeLeft)
        screenshot("demo-meal-landscape-light")
        settleOrientation(.portrait)
        app.terminate()
        app.launchArguments = ["--uitesting", "--appearance-dark"]
        launchForMealTesting()
        screenshot("demo-library-dark")
        openDemo()
        screenshot("demo-meal-dark")
    }

    func testDismissedDraftLeavesSavedMealUnchanged() throws {
        createMeal("Saved dinner")
        app.buttons["edit-meal"].tap()
        replace("meal-title", with: "Abandoned draft")
        dismissKeyboard()
        let bar = app.navigationBars["Edit meal"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        if UIDevice.current.userInterfaceIdiom == .pad {
            bar.buttons["Cancel"].tap()
        } else {
            bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        }
        XCTAssertTrue(app.textFields["meal-title"].waitForNonExistence(timeout: 5))
        app.buttons["edit-meal"].tap()
        XCTAssertEqual(app.textFields["meal-title"].value as? String, "Saved dinner")
        app.buttons["Cancel"].tap()
    }

    func testCollectAllTypeAccessibilityIssueInventory() throws {
        var failures: [String] = []
        var exceptions: [String] = []
        var reports: [[String: Any]] = []
        func audit(_ surface: String) throws {
            screenshot("accessibility-" + surface)
            try app.performAccessibilityAudit { issue in
                let details = "\(surface): \(issue.compactDescription)\n\(issue.detailedDescription)\nElement: \(issue.element?.debugDescription ?? "unavailable")"
                let finding = XCTAttachment(string: details)
                finding.name = "accessibility-finding-" + surface
                finding.lifetime = .keepAlways
                self.add(finding)
                reports.append([
                    "surface": surface,
                    "auditType": issue.auditType.rawValue,
                    "compactDescription": issue.compactDescription,
                    "detailedDescription": issue.detailedDescription,
                    "elementIdentifier": issue.element?.identifier ?? "unavailable",
                    "elementLabel": issue.element?.label ?? "unavailable",
                    "elementFrame": issue.element.map { String(describing: $0.frame) } ?? "unavailable"
                ])
                // The OS-rendered decorative library glyph has no semantic
                // information. Exempt only this observed raster contrast match;
                // meaningful emoji controls and every other finding remain in the review inventory.
                if issue.auditType == .contrast,
                   let element = issue.element,
                   element.identifier == "decorative-meal-charm",
                   element.elementType == .staticText,
                   element.label == "🍜" {
                    exceptions.append(details)
                } else {
                    failures.append(details)
                }
                // This explicitly named inventory retains all reports, including
                // unavailable elements. It is observational; native control gates,
                // actual font-growth journeys and rendered review run separately.
                return true
            }
        }
        launchDemo()
        try audit("library")
        openDemo()
        try audit("meal")
        app.buttons["view-split"].tap()
        try audit("split")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        app.buttons["edit-meal"].tap()
        try audit("meal-editor")
        let inventory = XCTAttachment(string: "Non-exempt findings: \(failures.count)\nDecorative glyph exceptions: \(exceptions.count)\n" + (failures + exceptions).joined(separator: "\n\n"))
        inventory.name = "accessibility-complete-inventory"
        inventory.lifetime = .keepAlways
        add(inventory)
        let data = try JSONSerialization.data(withJSONObject: ["issuesReported": reports.count, "knownDecorativeRasterReports": exceptions.count, "requiresReview": failures.count, "reports": reports], options: [.prettyPrinted, .sortedKeys])
        let json = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        json.name = "all-type-accessibility-issue-inventory.json"
        json.lifetime = .keepAlways
        add(json)
    }

    func testNativeAccessibleControlSemanticsAndHitRegions() throws {
        let controlAudits: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription, .trait, .elementDetection]
        func audit(_ surface: String) throws {
            try app.performAccessibilityAudit(for: controlAudits) { issue in
                let element = issue.element
                let finding = XCTAttachment(string: """
                    Surface: \(surface)
                    Audit type: \(issue.auditType.rawValue)
                    \(issue.compactDescription)
                    \(issue.detailedDescription)
                    Identifier: \(element?.identifier ?? "unavailable")
                    Label: \(element?.label ?? "unavailable")
                    Frame: \(element.map { String(describing: $0.frame) } ?? "unavailable")
                    Element: \(element?.debugDescription ?? "unavailable")
                    """)
                finding.name = "gated-accessibility-finding-" + surface
                finding.lifetime = .keepAlways
                self.add(finding)
                // Preserve the native failure, including reports with no element.
                return false
            }
        }
        launchDemo()
        screenshot("gated-accessibility-library")
        try audit("library")
        openDemo()
        screenshot("gated-accessibility-meal")
        try audit("meal")
        app.buttons["view-split"].tap()
        screenshot("gated-accessibility-split")
        try audit("split")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        app.buttons["edit-meal"].tap()
        screenshot("gated-accessibility-meal-editor")
        try audit("meal-editor")
    }

    func testDynamicTypeReallyGrowsAmountsAndInputs() throws {
        var frames: [[String: CGFloat]] = []
        for category in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            app.terminate()
            app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "-UIPreferredContentSizeCategoryName", category]
            launchForMealTesting()
            let libraryTotal = app.buttons["meal-Dinner at Juniper"].staticTexts["$113.66"]
            XCTAssertTrue(libraryTotal.waitForExistence(timeout: 5))
            var measurements = ["libraryAmountHeight": libraryTotal.frame.height]
            screenshot("accessibility-growth-library-" + category)
            openDemo()
            measurements["mealAmountHeight"] = app.staticTexts["meal-total"].frame.height
            XCTAssertEqual(app.staticTexts["meal-total"].value as? String, "$113.66")
            screenshot("accessibility-growth-meal-" + category)
            app.buttons["edit-meal"].tap()
            XCTAssertTrue(app.textFields["meal-title"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.textFields["meal-title"].value as? String, "Dinner at Juniper")
            measurements["titleInputHeight"] = app.textFields["meal-title"].frame.height
            XCTAssertTrue(app.buttons["Cancel"].isHittable)
            screenshot("accessibility-growth-title-" + category)
            measurements["receiptControlHeight"] = revealButton("choose-receipt").frame.height
            screenshot("accessibility-growth-receipt-" + category)
            app.buttons["Cancel"].tap()
            frames.append(measurements)
        }
        let record = XCTAttachment(string: String(describing: frames))
        record.name = "normal-and-xxxl-frame-growth-measurements"
        record.lifetime = .keepAlways
        add(record)
        for name in frames[0].keys {
            XCTAssertGreaterThan(frames[1][name]!, frames[0][name]!, "Actual semantic text must grow: \(name)")
        }
    }

    func testStartupRecoveryRetriesWithoutDiscardingSavedMeals() throws {
        createMeal("Recovery dinner")
        app.terminate()
        app.launchArguments = ["--uitesting", "--fail-first-store-open"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        screenshot("startup-recovery-keeps-saved-data")
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.buttons["meal-Recovery dinner"].waitForExistence(timeout: 10))
        app.buttons["meal-Recovery dinner"].tap()
        XCTAssertTrue(app.buttons["edit-meal"].exists)
    }

    func testHistoricalInvalidValuesAndUnreadableReceiptRemainRepairable() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-invalid-demo"]
        launchForMealTesting()
        openDemo()
        XCTAssertTrue(app.staticTexts["Some saved prices or charges are invalid. Edit them before settling this bill."].exists)
        screenshot("historical-invalid-bill-warning")
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.buttons["share-split"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["share-split"].isEnabled, "Invalid persisted values must prevent settlement sharing.")
        screenshot("historical-invalid-split")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        tapScrollable("View receipt")
        XCTAssertTrue(app.staticTexts["Receipt unavailable"].waitForExistence(timeout: 5))
        screenshot("unreadable-receipt-recovery")
        app.buttons["Close"].tap()
        app.buttons["edit-meal"].tap()
        tapScrollable("Remove receipt")
        tapScrollable("reset-meal-emoji")
        app.buttons["save-meal"].tap()
        XCTAssertTrue(revealButton("Attach receipt").exists)
    }

    func testRenamingHistoricalPersonPreservesAuthoritativeItemShares() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-invalid-demo"]
        launchForMealTesting()
        openDemo()
        let originalTotal = app.staticTexts["meal-total"].value as? String
        XCTAssertNotNil(originalTotal)
        app.buttons["view-split"].tap()
        let originalRow = app.descendants(matching: .any)["split-Alex"].firstMatch
        XCTAssertTrue(originalRow.waitForExistence(timeout: 5))
        let originalAmounts = originalRow.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.hasPrefix("$") }
        XCTAssertFalse(originalAmounts.isEmpty, "Capture the authoritative split before changing the name.")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        tapScrollable("person-Alex")
        let assigned = ["Edamame", "Miso ramen", "Matcha ice cream", "Iced tea"]
        for item in assigned {
            let control = app.switches["person-item-" + item]
            for _ in 0..<8 where !control.exists { scrollContent(up: true) }
            XCTAssertTrue(control.exists)
            XCTAssertEqual(control.value as? String, "1", "A stale historical reverse index must not clear saved item consumers.")
        }
        revealButton(app.textFields["person-name"], name: "person-name").tap()
        replace("person-name", with: "Alexandra")
        app.buttons["save-person"].tap()
        XCTAssertEqual(app.staticTexts["meal-total"].value as? String, originalTotal)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        openDemo()
        XCTAssertEqual(app.staticTexts["meal-total"].value as? String, originalTotal)
        tapScrollable("person-Alexandra")
        for item in assigned {
            let control = app.switches["person-item-" + item]
            for _ in 0..<8 where !control.exists { scrollContent(up: true) }
            XCTAssertTrue(control.exists)
            XCTAssertEqual(control.value as? String, "1")
        }
        app.buttons["Cancel"].tap()
        app.buttons["view-split"].tap()
        let renamedRow = app.descendants(matching: .any)["split-Alexandra"].firstMatch
        XCTAssertTrue(renamedRow.waitForExistence(timeout: 5))
        XCTAssertEqual(renamedRow.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.hasPrefix("$") }, originalAmounts)
        screenshot("historical-person-name-change-preserves-item-shares")
    }

    func testHistoricalUnknownItemConsumerCanBeRepairedWithoutChangingKnownShares() throws {
        // This repair checks every person's shares before Cancel, after Save,
        // and after relaunch; hosted automation exceeded the four-minute default.
        executionTimeAllowance = 420
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "--unknown-item-consumer"]
        launchForMealTesting()
        openDemo()
        let people = ["Alex", "Jordan", "Sam"]
        func savedAmounts() -> [String: [String]] {
            let total = revealButton(app.staticTexts["meal-total"], name: "meal-total").value as? String
            XCTAssertEqual(total, "$113.66")
            app.buttons["view-split"].tap()
            var amounts: [String: [String]] = [:]
            for person in people {
                let row = app.descendants(matching: .any)["split-" + person].firstMatch
                XCTAssertTrue(row.waitForExistence(timeout: 5))
                amounts[person] = row.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.hasPrefix("$") }
                XCTAssertFalse(amounts[person]!.isEmpty)
            }
            app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
            return amounts
        }
        func verifyKnownConsumers() {
            for person in people {
                let control = app.switches["item-consumer-" + person]
                revealButton(control, name: "known-item-consumer-" + person)
                XCTAssertEqual(control.value as? String, "1", "Opening a historical item must preserve every live consumer.")
            }
        }
        let originalAmounts = savedAmounts()
        tapScrollable("item-Edamame")
        verifyKnownConsumers()
        replace("item-name", with: "Cancelled edamame draft")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(revealButton("item-Edamame").exists)
        XCTAssertEqual(savedAmounts(), originalAmounts, "Cancelling a repair draft preserves the stored item and known shares.")
        tapScrollable("item-Edamame")
        verifyKnownConsumers()
        replace("item-name", with: "Shared edamame")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.textFields["item-name"].waitForNonExistence(timeout: 5), "Saving must canonicalize the hidden obsolete consumer and close the editor.")
        XCTAssertTrue(revealButton("item-Shared edamame").exists)
        XCTAssertEqual(savedAmounts(), originalAmounts, "Unknown consumers were already excluded from the authoritative calculation.")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        openDemo()
        tapScrollable("item-Shared edamame")
        verifyKnownConsumers()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(savedAmounts(), originalAmounts, "The repaired item, known assignments and amounts survive process relaunch.")
        screenshot("historical-unknown-consumer-repair-preserves-known-shares")
    }

    func testHistoricalInvalidRestaurantLocationCanBeRemovedWithoutOpeningMaps() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "--invalid-restaurant-location"]
        launchForMealTesting()
        openDemo()
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Juniper · sample restaurant")).firstMatch
        revealButton(restaurant, name: "invalid-historical-restaurant").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Restaurant location unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open in Maps"].exists, "Invalid historical coordinates must never be passed to Maps.")
        screenshot("historical-restaurant-location-unavailable")
        app.buttons["Done"].tap()
        app.buttons["edit-meal"].tap()
        tapScrollable("remove-restaurant")
        app.buttons["Cancel"].tap()
        revealButton(restaurant, name: "invalid-restaurant-preserved-after-cancel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Restaurant location unavailable"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["edit-meal"].tap()
        tapScrollable("remove-restaurant")
        app.buttons["save-meal"].tap()
        XCTAssertTrue(revealButton("Add restaurant").exists)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        openDemo()
        XCTAssertTrue(revealButton("Add restaurant").exists, "Removing an invalid saved restaurant survives process relaunch.")
    }

    func testLibrarySortOrderingAndSearchByPeopleAndRestaurant() throws {
        createMeal("Zebra dinner")
        returnToLibrary()
        createMeal("Alpha dinner")
        returnToLibrary()
        app.buttons["Sort meals"].tap()
        app.buttons["Title"].tap()
        XCTAssertLessThan(app.buttons["meal-Alpha dinner"].frame.minY, app.buttons["meal-Zebra dinner"].frame.minY)
        app.buttons["Sort meals"].tap()
        app.buttons["Newest first"].tap()
        XCTAssertLessThan(app.buttons["meal-Alpha dinner"].frame.minY, app.buttons["meal-Zebra dinner"].frame.minY)
        app.buttons["meal-Zebra dinner"].tap()
        addPerson("Morgan")
        returnToLibrary()
        app.buttons["Sort meals"].tap()
        app.buttons["Recently edited"].tap()
        XCTAssertLessThan(app.buttons["meal-Zebra dinner"].frame.minY, app.buttons["meal-Alpha dinner"].frame.minY)
        screenshot("library-sorting-actual-row-order")
        launchDemo()
        for term in ["Jordan", "Juniper"] {
            let search = app.searchFields.firstMatch
            search.tap()
            search.typeText(term)
            XCTAssertTrue(app.buttons["meal-Dinner at Juniper"].waitForExistence(timeout: 5), "Search must match \(term).")
            clearLibrarySearch()
        }
    }

    func testDeletingAssignedPersonPreservesItemAndShowsUnassignedBalance() throws {
        createMeal("Person deletion dinner")
        addPerson("Taylor")
        tapScrollable("add-item")
        fill("item-name", "Soup")
        fill("item-price", "10")
        enableSwitch("item-consumer-Taylor")
        app.buttons["save-item"].tap()
        tapScrollable("person-Taylor")
        app.buttons["delete-person"].tap()
        app.buttons["confirm-delete-person"].firstMatch.tap()
        XCTAssertTrue(app.buttons["person-Taylor"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-Soup"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["unassigned-warning"].firstMatch.exists)
        screenshot("assigned-person-deleted-item-preserved")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        app.buttons["meal-Person deletion dinner"].tap()
        XCTAssertFalse(app.buttons["person-Taylor"].exists)
        XCTAssertTrue(app.buttons["item-Soup"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["unassigned-warning"].firstMatch.exists)
    }

    func testNativeCategoryAndCustomIconEditingPersists() throws {
        createMeal("Icon dinner")
        app.buttons["edit-meal"].tap()
        XCTAssertEqual(app.textFields["meal-emoji"].label, "Custom emoji", "The native labeled field must announce its visible name once.")
        replace("meal-emoji", with: "🍕")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Custom icon Done must clear keyboard focus.")
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.navigationBars["🍕 Icon dinner"].waitForExistence(timeout: 5))
        tapScrollable("add-item")
        fill("item-name", "Lemonade")
        fill("item-price", "4.50")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Done must dismiss the price keyboard before opening the category picker.")
        app.buttons["item-category"].tap()
        screenshot("native-item-category-menu")
        app.buttons["Drink"].firstMatch.tap()
        app.buttons["save-item"].tap()
        let item = revealButton("item-Lemonade")
        XCTAssertTrue(item.label.contains("Drink"))
        item.tap()
        app.buttons["item-category"].tap()
        app.buttons["Dessert"].firstMatch.tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(revealButton("item-Lemonade").label.contains("Drink"), "Cancelled category selection preserves the saved category.")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        app.buttons["meal-Icon dinner"].tap()
        XCTAssertTrue(app.navigationBars["🍕 Icon dinner"].exists)
        XCTAssertTrue(revealButton("item-Lemonade").label.contains("Drink"))
        screenshot("custom-icon-and-category-persisted")
    }

    func testTaxAndTipRowsRespondAcrossTheirFullWidth() throws {
        createMeal("Charge controls")
        screenshot("charge-row-before-center-tap")
        let tax = revealButton("edit-tax")
        tax.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.textFields["charge-value"].waitForExistence(timeout: 5), "The middle of the advertised tax row must open its editor.")
        app.buttons["Cancel"].tap()
        let tip = revealButton("edit-tip")
        tip.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        XCTAssertTrue(app.textFields["charge-value"].waitForExistence(timeout: 5), "The labeled leading edge must open the tip editor.")
        app.buttons["Cancel"].tap()
    }

    func testLargestTextMealEditorIsReadableAndReceiptControlsRemainReachable() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchForMealTesting()
        screenshot("library-direct-accessibility-text")
        openDemo()
        app.buttons["edit-meal"].tap()
        XCTAssertTrue(app.textFields["meal-title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["meal-title"].value as? String, "Dinner at Juniper")
        screenshot("meal-editor-direct-accessibility-text-title")
        revealButton("choose-receipt")
        screenshot("meal-editor-direct-accessibility-text-receipt")
        let title = app.textFields["meal-title"]
        for _ in 0..<12 {
            if title.exists && title.frame.minY > visibleNavigationBottom() { break }
            scrollContent(up: false)
        }
        XCTAssertTrue(title.exists, "The native title input must be reachable after scrolling back from receipt controls.")
        title.tap()
        replace("meal-title", with: "Complete largest-text draft title")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        XCTAssertEqual(title.value as? String, "Complete largest-text draft title")
        screenshot("meal-editor-largest-title-edited-full-value")
        app.buttons["Cancel"].tap()
        app.buttons["edit-meal"].tap()
        XCTAssertEqual(app.textFields["meal-title"].value as? String, "Dinner at Juniper", "Cancelling a largest-text title edit must preserve the complete saved value.")
        screenshot("meal-editor-largest-title-cancel-preserves-saved-value")
        app.buttons["Cancel"].tap()
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

    /// Compares the real, fitted UIImageView content without screenshot metadata.
    private func receiptPixels(_ name: String) -> Data {
        let photo = app.images["receipt-photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        let capture = photo.screenshot()
        let attachment = XCTAttachment(screenshot: capture)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let image = capture.image.cgImage,
              let pixels = UIImage(cgImage: image).pngData() else {
            XCTFail("The native receipt image must expose readable rendered pixels.")
            return Data()
        }
        return pixels
    }

    private func choosePhoto(at index: Int) {
        tapScrollable("choose-receipt")
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: index)
        // Hosted Photos initially exposes PUPickerUnavailableView and Loading…;
        // wait for the actual selectable fixture, rather than its loading chrome.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND isHittable == true"), object: photo)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed, "The native Photos picker must load a selectable fictional receipt fixture.")
        XCTAssertTrue(app.navigationBars["Photos"].exists)
        XCTAssertTrue(photo.exists, "The verification script must import the fictional receipt fixtures before testing.")
        screenshot("native-photos-picker")
        photo.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForNonExistence(timeout: 15), "Selecting an actual photo dismisses the native picker.")
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: app.buttons["save-meal"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 15), .completed)
    }

    private func launchDemo() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["meal-Dinner at Juniper"].waitForExistence(timeout: 5))
    }

    private func openDemo() {
        app.buttons["meal-Dinner at Juniper"].tap()
        XCTAssertTrue(app.buttons["edit-meal"].waitForExistence(timeout: 5))
    }

    private func tapScrollable(_ identifier: String) {
        revealButton(identifier).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @discardableResult
    private func revealButton(_ identifier: String) -> XCUIElement {
        revealButton(app.buttons[identifier], name: identifier)
    }

    @discardableResult
    private func revealButton(_ button: XCUIElement, name identifier: String) -> XCUIElement {
        let prefersTop = ["edit-tax", "edit-tip", "reset-meal-emoji", "meal-total", "person-name"].contains(identifier)
        var movements: [String] = []
        for attempt in 0..<24 {
            let context = scrollingContext()
            let top = context.top
            let bottom = context.bottom
            if button.exists && button.frame.minY > top && button.frame.maxY < bottom { break }
            let before = button.exists ? String(describing: button.frame) : "not instantiated"
            if button.exists && button.frame.minY < top {
                scrollContent(up: false, distance: top - button.frame.minY + 12)
            } else if button.exists && button.frame.maxY >= bottom {
                scrollContent(up: true, distance: button.frame.maxY - bottom + 12)
            } else {
                scrollContent(up: prefersTop ? attempt >= 12 : attempt < 12)
            }
            movements.append("Attempt \(attempt): before \(before); after \(button.exists ? String(describing: button.frame) : "not instantiated"); viewport \(top)...\(bottom)")
        }
        if !movements.isEmpty {
            let record = XCTAttachment(string: movements.joined(separator: "\n"))
            record.name = "native-scroll-geometry-" + identifier
            record.lifetime = .keepAlways
            add(record)
        }
        XCTAssertTrue(button.exists, "Control must be reachable: \(identifier)")
        let context = scrollingContext()
        XCTAssertGreaterThan(button.frame.minY, context.top, "List control must be below its foreground toolbar.")
        XCTAssertLessThan(button.frame.maxY, context.bottom, "List control must remain within the foreground content viewport.")
        return button
    }

    /// Identifies the foreground form from its native modal navigation bar and
    /// collection geometry; a backing split-view footer can remain hittable.
    private func scrollingContext() -> (surface: XCUIElement, top: CGFloat, bottom: CGFloat, leading: CGFloat) {
        let bars = app.navigationBars.allElementsBoundByIndex
        let modal = bars.last { $0.buttons["Cancel"].exists || $0.buttons["Done"].exists || $0.buttons["Close"].exists }
        let collections = app.collectionViews.allElementsBoundByIndex
        if let modal {
            let bar = modal.frame
            let belowBar = CGPoint(x: bar.midX, y: bar.maxY + 10)
            let candidates = collections.filter {
                let frame = $0.frame
                return abs(frame.minX - bar.minX) < 2 && abs(frame.width - bar.width) < 2 && frame.contains(belowBar)
            }
            let surface = candidates.min { $0.frame.height < $1.frame.height } ?? app!
            XCTAssertFalse(candidates.isEmpty, "A native editor must expose its foreground scrollable form.")
            return (surface, max(bar.maxY, surface.frame.minY), surface.frame.maxY - 4, bar.minX + 8)
        }
        let surface = collections.last ?? app!
        let footer = app.buttons["view-split"]
        let top = bars.filter(\.isHittable).map { $0.frame.maxY }.max() ?? app.frame.minY
        let bottom = min(footer.isHittable ? footer.frame.minY - 4 : app.frame.maxY - 20, surface.frame.maxY - 4)
        let leading = footer.isHittable ? footer.frame.minX - 8 : surface.frame.minX + 8
        return (surface, max(top, surface.frame.minY), bottom, leading)
    }

    private func visibleNavigationBottom() -> CGFloat {
        scrollingContext().top
    }

    private func scrollContent(up: Bool, distance: CGFloat? = nil) {
        let context = scrollingContext()
        let frame = context.surface.frame
        let top = context.top + 20
        let bottom = context.bottom - 20
        XCTAssertGreaterThan(bottom, top, "The foreground form must have a usable scroll viewport.")
        let origin = context.surface.coordinate(withNormalizedOffset: .zero)
        let x = max(8, context.leading - frame.minX)
        let travel = distance.map { min(max($0, 20), min(150, (bottom - top) * 0.5)) } ?? (bottom - top) * 0.6
        let middle = (top + bottom) * 0.5 - frame.minY
        let upper = origin.withOffset(CGVector(dx: x, dy: middle - travel * 0.5))
        let lower = origin.withOffset(CGVector(dx: x, dy: middle + travel * 0.5))
        // Keep native gutter drags inside the current sheet or detail column so
        // the background dismissal region and fixed footer cannot consume them.
        if up { lower.press(forDuration: 0.1, thenDragTo: upper) }
        else { upper.press(forDuration: 0.1, thenDragTo: lower) }
    }

    private func dismissKeyboard() {
        if app.keyboards.firstMatch.exists {
            let done = app.buttons.matching(NSPredicate(format: "label == %@", "Done")).allElementsBoundByIndex.first { $0.isHittable }
            XCTAssertNotNil(done, "The focused editor must expose its keyboard Done action.")
            done?.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "The keyboard must dismiss before another control can be tapped.")
        }
    }

    private func enableSwitch(_ identifier: String) {
        dismissKeyboard()
        let control = app.switches[identifier]
        revealButton(control, name: identifier)
        // SwiftUI exposes the whole labeled row as the switch; the native knob
        // is at its trailing edge, while tapping the row label only clears focus.
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed, "Assignment toggle must actually change state.")
    }

    private func closeShareSheet() {
        let activity = app.otherElements["ActivityListView"]
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        let close = app.buttons["header.closeButton"]
        if close.exists && close.isHittable {
            close.tap()
        } else {
            // Text shares use a native floating activity panel without the image
            // preview's Close control. Its outside-tap dismissal is native.
            let outside = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * 0.5, dy: activity.frame.minY - 30))
            outside.tap()
        }
        XCTAssertTrue(activity.waitForNonExistence(timeout: 5), "The native sharing panel must dismiss before the next journey step.")
    }

    private func settleOrientation(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let landscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = XCUIApplication().frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        // Allow UIKit's native rotation animation to complete after geometry flips.
        Thread.sleep(forTimeInterval: 1)
    }

    private func returnToLibrary() {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        XCTAssertTrue(app.buttons["new-meal"].waitForExistence(timeout: 5))
    }

    private func clearLibrarySearch() {
        app.buttons["Clear text"].tap()
        let closeSearch = app.buttons["close"].firstMatch
        if closeSearch.exists { closeSearch.tap() }
        XCTAssertTrue(app.buttons["new-meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["new-meal"].isHittable, "Clearing search must make the library toolbar usable.")
    }

    private func createMeal(_ title: String) {
        app.buttons["new-meal"].tap()
        fill("meal-title", title)
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.buttons["edit-meal"].waitForExistence(timeout: 5))
    }

    private func addPerson(_ name: String) {
        tapScrollable("add-person")
        fill("person-name", name)
        app.buttons["save-person"].tap()
        XCTAssertTrue(app.buttons["person-\(name)"].waitForExistence(timeout: 5))
    }

    private func fill(_ identifier: String, _ text: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field: \(identifier)")
        field.tap()
        // Submit person names in the same native key sequence so the existing
        // onSubmit clears focus before XCTest waits for the next UI event.
        field.typeText(identifier == "person-name" ? text + "\n" : text)
        XCTAssertEqual(field.value as? String, text, "Entering a field must preserve the complete intended value.")
    }

    private func replace(_ identifier: String, with text: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text, "Replacement must update the complete field before saving or converting modes.")
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if name.contains("landscape") || name.contains("accessibility") || name.hasPrefix("demo-") {
            let geometry = XCTAttachment(string: "Application frame: \(app.frame)\nWindows: \(app.windows.debugDescription)\nFull accessibility tree: \(app.debugDescription)")
            geometry.name = name + "-window-geometry"
            geometry.lifetime = .keepAlways
            add(geometry)
        }
    }
}
