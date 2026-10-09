import XCTest
import UIKit

/// Exercises the app's real local SwiftData store and native navigation using an
/// isolated test store. Each journey starts empty; relaunch tests preserve it.
@MainActor
final class MealJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
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

    func testEveryoneDraftSharesCancellationAndSavedCompletion() throws {
        createMeal("Shared lunch")
        XCTAssertFalse(app.descendants(matching: .any)["meal-assignment-status"].firstMatch.exists,
                       "An empty bill must not claim assignment completion.")
        addPerson("Alice")
        addPerson("Bob")
        tapScrollable("add-item")
        fill("item-name", "Lunch")
        fill("item-price", "12.00")
        let everyone = revealButton("assign-everyone")
        XCTAssertTrue(everyone.isEnabled)
        XCTAssertTrue(app.frame.contains(everyone.frame))
        let beforeSelection = XCTAttachment(string: "Everyone target: \(everyone.debugDescription)\nFrame: \(everyone.frame)\nApp: \(app.frame)")
        beforeSelection.name = "everyone-native-full-row-target"
        beforeSelection.lifetime = .keepAlways
        add(beforeSelection)
        let originalKeyboard = XCTAttachment(string: app.keyboards.debugDescription)
        originalKeyboard.name = "everyone-original-native-keyboard-hierarchy"
        originalKeyboard.lifetime = .keepAlways
        add(originalKeyboard)
        screenshot("everyone-original-native-keyboard")
        everyone.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Bulk assignment must finish price entry without losing the draft.")
        XCTAssertEqual(app.textFields["item-price"].value as? String, "12.00")
        XCTAssertFalse(everyone.isEnabled)
        for name in ["Alice", "Bob"] {
            let person = app.switches["item-consumer-\(name)"]
            XCTAssertEqual(person.value as? String, "1")
            XCTAssertTrue(person.label.contains(name) && person.label.contains("6.00"), "The native switch must expose the person and exact item share.")
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.textFields["item-price"].tap()
            let nativeDone = app.keyboards.buttons["Done"].firstMatch
            let nativeReady = NSPredicate(format: "exists == 1 AND isHittable == 1")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: nativeReady, object: nativeDone)], timeout: 5), .completed,
                           "Price entry must provide a hittable native keyboard Done key.")
            XCTAssertTrue(nativeDone.exists)
            XCTAssertTrue(nativeDone.isHittable)
            let nativeKeyboard = XCTAttachment(string: "Native Done: \(nativeDone.debugDescription)\nDone frame: \(nativeDone.frame)\nKeyboard: \(app.keyboards.debugDescription)")
            nativeKeyboard.name = "everyone-pad-price-native-done-ready"
            nativeKeyboard.lifetime = .keepAlways
            add(nativeKeyboard)
            screenshot("everyone-pad-price-native-done-ready")
            nativeDone.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Native price Done must finish entry.")
            XCTAssertEqual(app.textFields["item-price"].value as? String, "12.00")
            for name in ["Alice", "Bob"] {
                XCTAssertEqual(app.switches["item-consumer-\(name)"].value as? String, "1")
            }
        }
        screenshot("satisfaction-everyone-draft-item-shares")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.buttons["item-Lunch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["meal-assignment-status"].firstMatch.exists)
        tapScrollable("item-Lunch")
        let alice = app.switches["item-consumer-Alice"]
        revealButton(alice, name: "item-consumer-Alice")
        alice.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(alice.value as? String, "0")
        XCTAssertTrue(app.switches["item-consumer-Bob"].label.contains("12.00"))
        screenshot("satisfaction-individual-exception-draft")
        app.buttons["Cancel"].tap()
        tapScrollable("item-Lunch")
        for name in ["Alice", "Bob"] {
            let person = app.switches["item-consumer-\(name)"]
            XCTAssertEqual(person.value as? String, "1", "Cancel must preserve saved assignments.")
            XCTAssertTrue(person.label.contains("6.00"))
        }
        replace("item-price", with: "12.345")
        XCTAssertFalse(app.switches["item-consumer-Alice"].label.contains("6.00"), "Invalid drafts must not retain stale monetary previews.")
        app.buttons["Cancel"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        app.buttons["meal-Shared lunch"].tap()
        XCTAssertTrue(app.buttons["item-Lunch"].waitForExistence(timeout: 5))
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["split-assignment-status"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "6.00")).firstMatch.exists)
        XCTAssertTrue(app.buttons["share-split"].isHittable)
        XCTAssertTrue(app.buttons["share-split"].label.contains("Share split"))
        screenshot("satisfaction-complete-split")
    }

    /// Uses the real system preference and restores its original value even after a journey assertion fails.
    func testReduceMotionPreservesDraftAssignmentsAndReachableLargestTextSplit() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let motion = openReduceMotionSetting(in: settings)
        let original = motion.value as? String
        XCTAssertTrue(original == "0" || original == "1", "Native Reduce Motion must expose its original switch value.")
        guard let original else { return }
        addTeardownBlock { @MainActor [self] () async throws in
            // Restoration must finish and report every failed check even when
            // the journey stopped at its first assertion.
            continueAfterFailure = true
            XCUIDevice.shared.orientation = .portrait
            settings.activate()
            XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
            let control = settings.switches["Reduce Motion"].firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 5), "The original native preference must remain available for restoration.")
            XCTAssertTrue(control.isHittable)
            if control.value as? String != original {
                control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", original), object: control)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
            let runnerRestored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                UIAccessibility.isReduceMotionEnabled == (original == "1")
            }, object: nil)
            let runnerRestoration = await XCTWaiter.fulfillment(of: [runnerRestored], timeout: 5)
            XCTAssertEqual(runnerRestoration, .completed,
                           "UIKit must receive the native preference-change notification.")
            let proof = XCTAttachment(string: "Original Reduce Motion: \(original)\nRestored switch: \(String(describing: control.value))\nRunner Reduce Motion: \(UIAccessibility.isReduceMotionEnabled)\nNative Settings hierarchy: \(settings.debugDescription)")
            proof.name = "reduce-motion-native-restoration"
            proof.lifetime = .keepAlways
            add(proof)
            let pixels = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            pixels.name = "reduce-motion-native-restored-setting"
            pixels.lifetime = .keepAlways
            add(pixels)
            XCTAssertEqual(UIAccessibility.isReduceMotionEnabled, original == "1", "UIKit must reflect the restored native preference.")
            settings.terminate()
            app.activate()
        }
        let baseline = XCTAttachment(string: "Original Reduce Motion: \(original)\nRunner Reduce Motion: \(UIAccessibility.isReduceMotionEnabled)")
        baseline.name = "reduce-motion-native-baseline"
        baseline.lifetime = .keepAlways
        add(baseline)
        // Settings exposes a labeled parent and a trailing nested switch.
        // Target the native switch rather than the center of its text label.
        if original == "0" { motion.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: motion)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        XCTAssertTrue(UIAccessibility.isReduceMotionEnabled, "The runner must observe the real native Reduce Motion preference.")
        launchDemo()
        openDemo()
        XCTAssertEqual(app.staticTexts["meal-total"].value as? String, "$113.66")
        screenshot("reduce-motion-normal-accessibility-meal")
        tapScrollable("item-Miso ramen")
        let originalPrice = app.textFields["item-price"].value as? String
        var originalAssignments: [String: String] = [:]
        for name in ["Alex", "Jordan", "Sam"] {
            let person = app.switches["item-consumer-" + name]
            revealButton(person, name: "reduce-motion-original-" + name)
            originalAssignments[name] = person.value as? String
        }
        replace("item-price", with: "0.01")
        let everyone = revealButton("assign-everyone")
        XCTAssertTrue(everyone.isEnabled)
        everyone.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        var previewLabels: [String] = []
        for name in ["Alex", "Jordan", "Sam"] {
            let person = app.switches["item-consumer-" + name]
            revealButton(person, name: "reduce-motion-everyone-" + name)
            XCTAssertEqual(person.value as? String, "1")
            previewLabels.append(person.label)
        }
        XCTAssertEqual(previewLabels.filter { $0.contains("0.01") }.count, 1)
        XCTAssertEqual(previewLabels.filter { $0.contains("0.00") }.count, 2)
        XCTAssertFalse(everyone.isEnabled)
        screenshot("reduce-motion-normal-accessibility-item-draft")
        app.buttons["Cancel"].tap()
        tapScrollable("item-Miso ramen")
        XCTAssertEqual(app.textFields["item-price"].value as? String, originalPrice)
        for name in ["Alex", "Jordan", "Sam"] {
            let person = app.switches["item-consumer-" + name]
            revealButton(person, name: "reduce-motion-cancelled-" + name)
            XCTAssertEqual(person.value as? String, originalAssignments[name], "Cancel must preserve the original saved assignment.")
        }
        app.buttons["Cancel"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchForMealTesting()
        XCTAssertTrue(app.buttons["meal-Dinner at Juniper"].waitForExistence(timeout: 5))
        screenshot("reduce-motion-largest-accessibility-library")
        openDemo()
        XCTAssertTrue(UIAccessibility.isReduceMotionEnabled)
        XCTAssertEqual(app.staticTexts["meal-total"].value as? String, "$113.66")
        screenshot("reduce-motion-largest-accessibility-meal")
        tapScrollable("item-Miso ramen")
        let preview = app.switches["item-consumer-Alex"]
        revealButton(preview, name: "reduce-motion-largest-item-share")
        XCTAssertEqual(preview.value as? String, "1")
        XCTAssertTrue(preview.label.contains("Alex") && preview.label.contains("19.00"))
        XCTAssertTrue(app.frame.contains(preview.frame))
        screenshot("reduce-motion-largest-accessibility-item-share")
        app.buttons["Cancel"].tap()
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.navigationBars["Split summary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["split-total"].value as? String, "$113.66")
        XCTAssertTrue(app.descendants(matching: .any)["split-assignment-status"].firstMatch.waitForExistence(timeout: 5))
        settleOrientation(.landscapeLeft)
        let total = app.staticTexts["split-total"]
        revealButton(total, name: "reduce-motion-largest-landscape-total")
        XCTAssertEqual(total.value as? String, "$113.66")
        screenshot("reduce-motion-largest-accessibility-landscape-total")
        let share = app.buttons["share-split"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(share.isHittable)
        XCTAssertTrue(share.isEnabled)
        XCTAssertTrue(app.frame.contains(share.frame), "The complete Share split target must remain inside the largest-text landscape viewport.")
        screenshot("reduce-motion-largest-accessibility-landscape-split")
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        screenshot("reduce-motion-native-share-sheet")
        closeShareSheet()
    }

    /// Opens Accessibility → Motion through native Settings rows, without relying on its search index.
    private func openReduceMotionSetting(in settings: XCUIApplication) -> XCUIElement {
        func capture(_ stage: String) {
            let tree = XCTAttachment(string: settings.debugDescription)
            tree.name = "reduce-motion-settings-" + stage + "-hierarchy"
            tree.lifetime = .keepAlways
            add(tree)
            let pixels = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            pixels.name = "reduce-motion-settings-" + stage
            pixels.lifetime = .keepAlways
            add(pixels)
        }
        settings.launch()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        capture("entry")
        let search = settings.searchFields["Search"].firstMatch
        if search.exists {
            let clear = search.buttons["Clear text"]
            if clear.exists {
                XCTAssertTrue(clear.isHittable)
                clear.tap()
            }
        }
        let close = settings.buttons["close"]
        if close.exists {
            XCTAssertTrue(close.isHittable)
            close.tap()
            XCTAssertTrue(settings.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        }
        if settings.keyboards.firstMatch.exists {
            let hide = settings.keyboards.buttons["Hide keyboard"]
            XCTAssertTrue(hide.waitForExistence(timeout: 5), "The native Settings keyboard must expose its dismissal control.")
            XCTAssertTrue(hide.isHittable)
            hide.tap()
            XCTAssertTrue(settings.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        }
        let sidebar = settings.collectionViews["com.apple.settings.sidebar.collectionView"]
        for _ in 0..<6 where !sidebar.exists {
            let back = settings.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["Settings", "Apps", "Split My Meal", "Accessibility", "Motion"])).firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Native Settings must expose its parent navigation before opening Accessibility.")
            XCTAssertTrue(back.isHittable)
            back.tap()
        }
        capture("root")
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.frame.intersects(sidebar.frame), "The native Settings sidebar must be inside its visible window.")
        let accessibility = sidebar.buttons["com.apple.settings.accessibility"]
        for _ in 0..<8 where !accessibility.isHittable { sidebar.swipeUp(velocity: .slow) }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 5), "Native Settings must expose the Accessibility row.")
        XCTAssertTrue(accessibility.isHittable)
        accessibility.tap()
        capture("accessibility")
        XCTAssertTrue(settings.navigationBars["Accessibility"].waitForExistence(timeout: 5))
        let motion = settings.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Motion")).firstMatch
        XCTAssertTrue(motion.waitForExistence(timeout: 5), "Accessibility must expose its native Motion row.")
        XCTAssertTrue(motion.isHittable)
        motion.tap()
        capture("motion")
        XCTAssertTrue(settings.navigationBars["Motion"].waitForExistence(timeout: 5))
        let control = settings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        XCTAssertTrue(control.isHittable)
        return control
    }

    func testInvalidInputsCannotBeSavedAndCancelLeavesMealUnchanged() throws {
        screenshot("library-empty-state")
        app.buttons["new-meal"].tap()
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.alerts["Couldn’t update meal"].waitForExistence(timeout: 5))
        screenshot("new-meal-validation-alert")
        app.alerts.buttons["OK"].tap()
        app.buttons["Cancel"].tap()
        createMeal("Validation dinner")
        tapScrollable("add-person")
        screenshot("new-person-with-no-items")
        app.buttons["save-person"].tap()
        XCTAssertTrue(app.alerts["Couldn’t update person"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        fill("person-name", "Unsaved person")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Unsaved person"].exists)
        tapScrollable("add-item")
        screenshot("new-item-with-no-people")
        fill("item-name", "Unsaved dessert")
        fill("item-price", "0")
        app.buttons["save-item"].tap()
        XCTAssertTrue(app.alerts["Couldn’t update item"].waitForExistence(timeout: 5))
        screenshot("item-price-validation-alert")
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
        XCTAssertTrue(app.buttons["confirm-delete-item"].firstMatch.waitForExistence(timeout: 5))
        screenshot("delete-item-confirmation")
        app.buttons["confirm-delete-item"].firstMatch.tap()
        XCTAssertTrue(app.buttons["item-Green salad"].waitForNonExistence(timeout: 5))
        tapScrollable("person-Casey")
        app.buttons["delete-person"].tap()
        XCTAssertTrue(app.buttons["confirm-delete-person"].firstMatch.waitForExistence(timeout: 5))
        screenshot("delete-person-confirmation")
        app.buttons["confirm-delete-person"].firstMatch.tap()
        XCTAssertTrue(app.buttons["person-Casey"].waitForNonExistence(timeout: 5))
        app.buttons["edit-meal"].tap()
        app.buttons["delete-meal"].tap()
        XCTAssertTrue(app.buttons["confirm-delete-meal"].firstMatch.waitForExistence(timeout: 5))
        screenshot("delete-meal-confirmation")
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
        for name in ["Alex", "Jordan", "Sam"] {
            let person = app.descendants(matching: .any)["split-" + name].firstMatch
            revealButton(person, name: "largest-split-" + name)
            XCTAssertTrue(person.isHittable, "Every person's share must remain reachable at the largest text size.")
        }
        let billDetails = app.descendants(matching: .any)["bill-details"].firstMatch
        revealButton(billDetails, name: "largest-bill-details")
        XCTAssertTrue(billDetails.isHittable)
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
        XCTAssertEqual(app.textFields["charge-value"].value as? String, "0", "Clear must stage a zero draft rather than closing the editor.")
        XCTAssertTrue(app.buttons["save-charge"].isHittable, "A staged clear requires the ordinary Save action.")
        screenshot("tax-cleared-draft-awaiting-save")
        app.buttons["Cancel"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$25.00", "Cancelling a cleared draft must preserve the saved tax.")
        tapScrollable("edit-tax")
        app.buttons["clear-charge"].tap()
        app.buttons["save-charge"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$23.00")
        tapScrollable("edit-tip")
        app.buttons["clear-charge"].tap()
        XCTAssertEqual(app.textFields["charge-value"].value as? String, "0")
        replace("charge-value", with: "1")
        app.buttons["save-charge"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$21.00", "Editing after Clear must replace the nil intent with the entered adjustment.")
        tapScrollable("edit-tip")
        app.buttons["clear-charge"].tap()
        app.buttons["Percentage"].tap()
        app.buttons["Amount"].tap()
        app.buttons["save-charge"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$20.00")
        screenshot("reverse-assignment-and-cleared-charges")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        app.buttons["meal-Assignment dinner"].tap()
        XCTAssertEqual((app.staticTexts["meal-total"].value as? String), "$20.00", "Saved charge removal must survive process relaunch.")
        tapScrollable("edit-tip")
        XCTAssertEqual(app.textFields["charge-value"].value as? String, "0")
        XCTAssertTrue(app.buttons["Percentage"].isSelected, "A cleared fixed tip must reopen in the canonical percentage mode rather than as a stored zero amount.")
        app.buttons["Cancel"].tap()
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

    func testDraftReceiptPreviewCanZoomAndCancelPreservesSavedPhoto() throws {
        createMeal("Draft preview dinner")
        app.buttons["edit-meal"].tap()
        choosePhoto(at: 0)
        app.buttons["save-meal"].tap()
        tapScrollable("View receipt")
        let original = receiptPixels("draft-preview-original-saved-image")
        app.buttons["Close"].tap()
        app.buttons["edit-meal"].tap()
        choosePhoto(at: 1)
        tapScrollable("preview-receipt")
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(receiptPixels("draft-preview-replacement-image"), original, "Preview must render the unsaved replacement rather than the stored photo.")
        let zoom = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Zoom ")).firstMatch
        XCTAssertEqual(zoom.label, "Zoom 100 percent")
        app.buttons["Zoom in"].tap()
        let magnified = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Zoom 100 percent"), object: zoom)
        XCTAssertEqual(XCTWaiter.wait(for: [magnified], timeout: 5), .completed, "An unsaved receipt preview must support the same native viewer controls.")
        screenshot("draft-receipt-preview-zoomed")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["save-meal"].waitForExistence(timeout: 5), "Closing preview returns to the unsaved meal editor.")
        app.buttons["Cancel"].tap()
        tapScrollable("View receipt")
        XCTAssertEqual(receiptPixels("draft-preview-cancel-preserves-saved-image"), original)
        app.buttons["Close"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        launchForMealTesting()
        app.buttons["meal-Draft preview dinner"].tap()
        tapScrollable("View receipt")
        XCTAssertEqual(receiptPixels("draft-preview-cancel-survives-relaunch"), original, "Viewing a draft must never commit its replacement photo.")
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
        XCTAssertTrue(app.staticTexts["Search by name, address or city."].waitForExistence(timeout: 5))
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
        tapScrollable("person-Alex")
        XCTAssertEqual(app.textFields["person-name"].value as? String, "Alex")
        screenshot("demo-person-editor-light")
        app.buttons["Cancel"].tap()
        tapScrollable("item-Miso ramen")
        XCTAssertEqual(app.textFields["item-name"].value as? String, "Miso ramen")
        screenshot("demo-item-editor-light")
        app.buttons["Cancel"].tap()
        tapScrollable("edit-tax")
        XCTAssertEqual(app.textFields["charge-value"].value as? String, "8.875")
        screenshot("demo-tax-editor-light")
        app.buttons["Cancel"].tap()
        tapScrollable("edit-tip")
        XCTAssertEqual(app.textFields["charge-value"].value as? String, "20")
        screenshot("demo-tip-editor-light")
        app.buttons["Cancel"].tap()
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["split-Alex"].firstMatch.waitForExistence(timeout: 5))
        screenshot("demo-split-light")
        app.descendants(matching: .any)["split-Alex"].firstMatch.tap()
        screenshot("demo-itemized-split-light")
        app.descendants(matching: .any)["split-Alex"].firstMatch.tap()
        let billDetails = app.descendants(matching: .any)["bill-details"].firstMatch
        revealButton(billDetails, name: "bill-details")
        let allocationRule = app.staticTexts["Shared items are divided equally. Tax and tip follow item shares. Percentage tips include tax. Rounding keeps totals exact."]
        XCTAssertFalse(allocationRule.exists, "Bill details must start collapsed so individual shares remain the main content.")
        screenshot("demo-bill-details-collapsed-light")
        billDetails.tap()
        revealButton(allocationRule, name: "bill-allocation-rule")
        screenshot("demo-bill-details-expanded-light")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Juniper · sample restaurant")).firstMatch
        revealButton(restaurant, name: "demo-restaurant").tap()
        XCTAssertTrue(app.navigationBars["Juniper · sample restaurant"].waitForExistence(timeout: 5))
        screenshot("demo-restaurant-map-light")
        settleOrientation(.landscapeLeft)
        screenshot("demo-restaurant-map-landscape-light")
        settleOrientation(.portrait)
        app.navigationBars["Juniper · sample restaurant"].buttons["Done"].tap()
        revealButton("View receipt")
        screenshot("demo-meal-footer-light")
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
        app.buttons["Error details"].tap()
        let details = app.staticTexts["A test store-open failure was requested. Your production meals are untouched."]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        screenshot("startup-recovery-expanded-error-details")
        app.buttons["Error details"].tap()
        XCTAssertTrue(details.waitForNonExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Some prices or charges are invalid. Edit them before settling."].exists)
        screenshot("historical-invalid-bill-warning")
        app.buttons["view-split"].tap()
        XCTAssertTrue(app.buttons["share-split"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["share-split"].isEnabled, "Invalid persisted values must prevent settlement sharing.")
        screenshot("historical-invalid-split")
        app.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch.tap()
        tapScrollable("View receipt")
        XCTAssertTrue(app.staticTexts["Receipt unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Zoom ")).firstMatch.exists, "An unreadable receipt must not expose a meaningless zoom readout.")
        XCTAssertFalse(app.buttons["Zoom in"].exists)
        XCTAssertFalse(app.buttons["Zoom out"].exists)
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
        // Hosted automation reached the repair/save steps after four minutes.
        // Keep the bounded relaunch journey budget separate from control waits.
        executionTimeAllowance = 420
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
        tapScrollable("custom-emoji")
        XCTAssertEqual(app.textFields["meal-emoji"].label, "Custom emoji", "The native labeled field must announce its visible name once.")
        replace("meal-emoji", with: "🦄")
        // A hardware-keyboard layout can expose an offscreen system return key;
        // use the editor's visible keyboard accessory instead of that placeholder.
        dismissKeyboard()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Custom icon Done must clear keyboard focus.")
        app.buttons["save-meal"].tap()
        XCTAssertTrue(app.navigationBars["🦄 Icon dinner"].waitForExistence(timeout: 5))
        app.buttons["edit-meal"].tap()
        XCTAssertEqual(app.textFields["meal-emoji"].value as? String, "🦄", "A saved custom icon must reopen with its field expanded.")
        screenshot("custom-icon-disclosure-reopened")
        app.buttons["Cancel"].tap()
        tapScrollable("add-item")
        fill("item-name", "Lemonade")
        fill("item-price", "4.50")
        dismissKeyboard()
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
        XCTAssertTrue(app.navigationBars["🦄 Icon dinner"].exists)
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

    func testRestaurantMapControlsRemainReachableAtLargestTextAndLandscape() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--seed-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchForMealTesting()
        openDemo()
        let restaurant = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Juniper · sample restaurant")).firstMatch
        revealButton(restaurant, name: "largest-restaurant").tap()
        let bar = app.navigationBars["Juniper · sample restaurant"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            settleOrientation(orientation)
            assertReadableRestaurantMap(app, title: "Juniper · sample restaurant", address: "Fictional dinner for app screenshots", orientation: orientation)
        }
        bar.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["edit-meal"].waitForExistence(timeout: 5))
        settleOrientation(.portrait)
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
            let exists = button.exists
            let frame = exists ? button.frame : nil
            if let frame, frame.minY > top && frame.maxY < bottom { break }
            let before = frame.map { String(describing: $0) } ?? "not instantiated"
            if let frame, frame.minY < top {
                scrollContent(up: false, distance: top - frame.minY + 12, context: context)
            } else if let frame, frame.maxY >= bottom {
                scrollContent(up: true, distance: frame.maxY - bottom + 12, context: context)
            } else {
                scrollContent(up: prefersTop ? attempt >= 12 : attempt < 12, context: context)
            }
            // Refresh after the native gesture; an earlier frame cannot describe its result.
            let afterExists = button.exists
            let afterFrame = afterExists ? button.frame : nil
            movements.append("Attempt \(attempt): before \(before); after \(afterFrame.map { String(describing: $0) } ?? "not instantiated"); viewport \(top)...\(bottom)")
        }
        if !movements.isEmpty {
            let record = XCTAttachment(string: movements.joined(separator: "\n"))
            record.name = "native-scroll-geometry-" + identifier
            record.lifetime = .keepAlways
            add(record)
        }
        let exists = button.exists
        XCTAssertTrue(exists, "Control must be reachable: \(identifier)")
        if exists {
            // Independently resolve the final foreground viewport and target after all gestures.
            let context = scrollingContext()
            let frame = button.frame
            XCTAssertGreaterThan(frame.minY, context.top, "List control must be below its foreground toolbar.")
            if frame.minY <= context.top || frame.maxY >= context.bottom {
                screenshot("unreachable-control-" + identifier)
            }
            XCTAssertLessThan(frame.maxY, context.bottom, "List control must remain within the foreground content viewport.")
        }
        return button
    }

    private typealias ScrollingContext = (surface: XCUIElement, frame: CGRect, top: CGFloat, bottom: CGFloat, leading: CGFloat)

    /// Identifies the foreground form from its native modal navigation bar and
    /// collection geometry; captured frames are valid only until the next native interaction.
    private func scrollingContext() -> ScrollingContext {
        let bars = app.navigationBars.allElementsBoundByIndex
        let modal = bars.last { $0.buttons["Cancel"].exists || $0.buttons["Done"].exists || $0.buttons["Close"].exists }
        let collections = app.collectionViews.allElementsBoundByIndex
        let appFrame = app.frame
        if let modal {
            let bar = modal.frame
            let belowBar = CGPoint(x: bar.midX, y: bar.maxY + 10)
            let candidates = collections.map { (element: $0, frame: $0.frame) }.filter {
                abs($0.frame.minX - bar.minX) < 2 && abs($0.frame.width - bar.width) < 2 && $0.frame.contains(belowBar)
            }
            let surface = candidates.min { $0.frame.height < $1.frame.height } ?? (element: app!, frame: appFrame)
            XCTAssertFalse(candidates.isEmpty, "A native editor must expose its foreground scrollable form.")
            let share = app.buttons["share-split"]
            let shareFrame = modal.identifier == "Split summary" && share.exists && share.isHittable ? share.frame : nil
            let bottom = min(surface.frame.maxY - 4, shareFrame.map { $0.minY - 4 } ?? surface.frame.maxY - 4)
            // Landscape lists include the device's horizontal safe area in their
            // AX frame. Drag inside the noninteractive total row, rather than
            // the screen-edge gutter outside the actual split content.
            let total = app.staticTexts["split-total"]
            let leading = modal.identifier == "Split summary" && total.exists ? total.frame.minX + 12 : bar.minX + 8
            return (surface.element, surface.frame, max(bar.maxY, surface.frame.minY), bottom, leading)
        }
        let surface = collections.last.map { (element: $0, frame: $0.frame) } ?? (element: app!, frame: appFrame)
        let footer = app.buttons["view-split"]
        let footerHittable = footer.isHittable
        let footerFrame = footerHittable ? footer.frame : nil
        let visibleBarFrames = bars.filter(\.isHittable).map(\.frame)
        let top = visibleBarFrames.map(\.maxY).max() ?? appFrame.minY
        let bottom = min(footerFrame.map { $0.minY - 4 } ?? appFrame.maxY - 20, surface.frame.maxY - 4)
        let leading = footerFrame.map { $0.minX - 8 } ?? surface.frame.minX + 8
        return (surface.element, surface.frame, max(top, surface.frame.minY), bottom, leading)
    }

    private func visibleNavigationBottom() -> CGFloat {
        scrollingContext().top
    }

    private func scrollContent(up: Bool, distance: CGFloat? = nil, context capturedContext: ScrollingContext? = nil) {
        let context = capturedContext ?? scrollingContext()
        let frame = context.frame
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
        let start = up ? lower : upper
        let end = up ? upper : lower
        if distance != nil {
            // Stop the finger before lifting on fine adjustments. Immediate
            // release added inertia and oscillated past otherwise reachable rows.
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        } else {
            start.press(forDuration: 0.1, thenDragTo: end)
        }
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
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text, "Entering a field must preserve the complete intended value.")
        // Software and hardware keyboards expose different native submit controls.
        if identifier == "person-name" {
            func visibleSubmit(_ element: XCUIElement, in viewport: CGRect) -> Bool {
                guard element.exists else { return false }
                let frame = element.frame
                guard [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
                      frame.width > 0, frame.height > 0, viewport.contains(frame) else { return false }
                return element.isHittable
            }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                guard let application = object as? XCUIApplication,
                      application.state == .runningForeground else { return false }
                let viewport = application.frame
                return visibleSubmit(application.keyboards.buttons["Done"].firstMatch, in: viewport)
                    || visibleSubmit(application.buttons["dismiss-person-keyboard"].firstMatch, in: viewport)
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                           "Person-name entry must expose a visible native submit control.")
            let viewport = app.frame
            let softwareDone = app.keyboards.buttons["Done"].firstMatch
            let toolbarDone = app.buttons["dismiss-person-keyboard"].firstMatch
            let useSoftwareDone = visibleSubmit(softwareDone, in: viewport)
            let done = useSoftwareDone ? softwareDone : toolbarDone
            XCTAssertEqual(app.state, .runningForeground)
            XCTAssertTrue(visibleSubmit(done, in: viewport))
            XCTAssertEqual(field.value as? String, text)
            let keyGeometry = XCTAttachment(string: "Selected path: \(useSoftwareDone ? "software-keyboard" : "person-toolbar")\nSelected identifier: \(done.identifier)\nSelected label: \(done.label)\nSelected frame: \(done.frame)\nApp viewport: \(viewport)\nSelected hierarchy: \(done.debugDescription)\nKeyboard hierarchy: \(app.keyboards.debugDescription)")
            keyGeometry.name = "native-keyboard-submit-ready-" + text
            keyGeometry.lifetime = .keepAlways
            add(keyGeometry)
            screenshot("native-keyboard-submit-ready-" + text)
            done.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
                          "Native submit must dismiss the keyboard before saving.")
            XCTAssertTrue(toolbarDone.waitForNonExistence(timeout: 5),
                          "The person keyboard accessory must disappear after native submit.")
            XCTAssertEqual(field.value as? String, text,
                           "Native submit must preserve the complete intended person name.")
        }
    }

    private func replace(_ identifier: String, with text: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        if identifier == "item-price" && UIDevice.current.userInterfaceIdiom == .pad {
            // Focus first: the sheet moves when the native keyboard appears.
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Price selection requires the actual native keyboard.")
            let currentField = app.textFields[identifier]
            let geometry = XCTAttachment(string: "Field before native double tap: \(currentField.debugDescription)\nField frame: \(currentField.frame)\nKeyboard: \(app.keyboards.debugDescription)\nKeyboard frame: \(app.keyboards.firstMatch.frame)")
            geometry.name = "item-price-before-native-double-tap"
            geometry.lifetime = .keepAlways
            add(geometry)
            screenshot("item-price-before-native-double-tap")
            currentField.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).doubleTap()
            currentField.typeText(XCUIKeyboardKey.delete.rawValue)
            screenshot("item-price-after-native-delete")
            let cleared = XCTAttachment(string: "Field after selected native deletion: \(currentField.debugDescription)")
            cleared.name = "item-price-after-native-delete-hierarchy"
            cleared.lifetime = .keepAlways
            add(cleared)
            // XCTest returns the placeholder for empty native fields; the exact
            // assertion below still rejects any text left behind by deletion.
            XCTAssertEqual(currentField.placeholderValue, "0.00")
            let clearedValue = currentField.value as? String
            XCTAssertTrue(clearedValue == "" || clearedValue == currentField.placeholderValue, "An empty native price field may report its placeholder; replacement must still match the complete intended text.")
        } else {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
            let existing = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
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

extension XCTestCase {
    /// Checks the actual visible map and fully rendered largest-text details;
    /// scrolling may reveal long address portions and individual native actions.
    @MainActor
    func assertReadableRestaurantMap(_ app: XCUIApplication, title: String, address expectedAddress: String, orientation: UIDeviceOrientation, capturePrefix: String = "restaurant-map-accessibility-text") {
        let bar = app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        func capture(_ name: String) {
            let captureName = name.replacingOccurrences(of: "restaurant-map-accessibility-text", with: capturePrefix)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = captureName
            attachment.lifetime = .keepAlways
            add(attachment)
            let geometry = XCTAttachment(string: "Application frame: \(app.frame)\nFull accessibility tree: \(app.debugDescription)")
            geometry.name = captureName + "-window-geometry"
            geometry.lifetime = .keepAlways
            add(geometry)
        }
        let suffix = orientation == .portrait ? "portrait" : "landscape"
        let openMaps = app.buttons["Open in Maps"]
        let showLocation = app.buttons["Show my location"]
        let done = bar.buttons["Done"]
        let address = app.staticTexts["restaurant-address"]
        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertEqual(address.label, expectedAddress)
        XCTAssertEqual(app.state, .runningForeground, "Map layout checks must observe the foreground app.")
        let compact = UIDevice.current.userInterfaceIdiom == .phone && orientation == .landscapeLeft
        let detailCandidates = app.scrollViews.containing(.staticText, identifier: "restaurant-address").allElementsBoundByIndex.filter { candidate in
            let frame = candidate.frame
            guard frame.width >= 100, frame.height >= 100, app.frame.intersects(frame) else { return false }
            return compact ? frame.minX >= map.frame.maxX - 2 : frame.minY >= map.frame.maxY - 2
        }
        XCTAssertLessThanOrEqual(detailCandidates.count, 1, "The address must identify one native details viewport beside or below the map.")
        let details = detailCandidates.first
        if compact { XCTAssertNotNil(details, "Compact landscape must give restaurant details their own native scroll viewport.") }
        let visibleMapTop = max(map.frame.minY, bar.frame.maxY)
        let visibleMapBottom: CGFloat
        if let details {
            if compact {
                XCTAssertLessThanOrEqual(map.frame.maxX, details.frame.minX + 2, "The visible map must sit beside the scrollable details, away from their text and actions.")
            } else {
                XCTAssertLessThanOrEqual(map.frame.maxY, details.frame.minY + 2, "The visible map must sit above the scrollable details, away from their text and actions.")
            }
            visibleMapBottom = min(map.frame.maxY, app.frame.maxY - 20)
            let viewport = details.frame.intersection(CGRect(x: app.frame.minX, y: bar.frame.maxY, width: app.frame.width, height: app.frame.maxY - 20 - bar.frame.maxY))
            enum Portion { case entire, top, bottom }
            func revealDetail(_ element: XCUIElement, portion: Portion = .entire) {
                revealLoop: for _ in 0..<8 {
                    let frame = element.frame
                    let upperGap = viewport.minY - frame.minY
                    let lowerGap = frame.maxY - viewport.maxY
                    let gap: CGFloat
                    switch portion {
                    case .entire:
                        if viewport.contains(frame) && element.isHittable { break revealLoop }
                        gap = upperGap > 0 ? -upperGap - 8 : lowerGap + 8
                    case .top:
                        if frame.minY >= viewport.minY && frame.minY < viewport.maxY { break revealLoop }
                        gap = -upperGap - 8
                    case .bottom:
                        if frame.maxY <= viewport.maxY && frame.maxY > viewport.minY { break revealLoop }
                        gap = lowerGap + 8
                    }
                    XCTAssertEqual(app.state, .runningForeground, "A map details pan must start in the foreground app.")
                    // Begin on visible non-action text or actual spacing, so
                    // scrolling cannot start by pressing a native action label.
                    let neutralTexts = [address, app.staticTexts["Location access is off."]].filter { $0.exists }.map { $0.frame.intersection(viewport) }.filter { !$0.isNull && $0.height >= 16 }
                    let startPoint: CGPoint
                    if let text = neutralTexts.max(by: { $0.height < $1.height }) {
                        startPoint = CGPoint(x: text.midX, y: gap > 0 ? text.maxY - 4 : text.minY + 4)
                    } else {
                        let actions = [openMaps, showLocation, app.links["map-open-settings"]].filter { $0.exists }.map { $0.frame.intersection(viewport) }.filter { !$0.isNull }.sorted { $0.minY < $1.minY }
                        var spaces: [CGRect] = []
                        var edge = viewport.minY
                        for action in actions {
                            if action.minY - edge >= 4 { spaces.append(CGRect(x: viewport.minX, y: edge, width: viewport.width, height: action.minY - edge)) }
                            edge = max(edge, action.maxY)
                        }
                        if viewport.maxY - edge >= 4 { spaces.append(CGRect(x: viewport.minX, y: edge, width: viewport.width, height: viewport.maxY - edge)) }
                        // Select room to move in the required direction. A
                        // taller gap at the viewport edge can allow only a tap.
                        guard let space = spaces.max(by: {
                            gap > 0 ? $0.midY < $1.midY : $0.midY > $1.midY
                        }) else {
                            XCTFail("Map details must expose visible non-action content for a native pan.")
                            return
                        }
                        startPoint = CGPoint(x: address.frame.minX + 8, y: space.midY)
                    }
                    let available = gap > 0 ? startPoint.y - viewport.minY - 2 : viewport.maxY - startPoint.y - 2
                    let travel = min(max(abs(gap), 20), available)
                    XCTAssertGreaterThan(travel, 0)
                    let endPoint = CGPoint(x: startPoint.x, y: startPoint.y + (gap > 0 ? -travel : travel))
                    let origin = details.coordinate(withNormalizedOffset: .zero)
                    let start = origin.withOffset(CGVector(dx: startPoint.x - details.frame.minX, dy: startPoint.y - details.frame.minY))
                    let end = origin.withOffset(CGVector(dx: endPoint.x - details.frame.minX, dy: endPoint.y - details.frame.minY))
                    start.press(forDuration: 0, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
                    XCTAssertEqual(app.state, .runningForeground, "Scrolling map details must preserve the app's foreground presentation.")
                }
                switch portion {
                case .entire: XCTAssertTrue(viewport.contains(element.frame), "The whole native action must remain within the foreground details viewport.")
                case .top: XCTAssertTrue(element.frame.minY >= viewport.minY && element.frame.minY < viewport.maxY, "The full address's first lines must be reachable.")
                case .bottom: XCTAssertTrue(element.frame.maxY <= viewport.maxY && element.frame.maxY > viewport.minY, "The full address's last lines must be reachable.")
                }
                XCTAssertTrue(element.isHittable)
            }
            if address.frame.height > viewport.height {
                revealDetail(address, portion: .top)
                capture("restaurant-map-accessibility-text-" + suffix + "-address-top")
                revealDetail(address, portion: .bottom)
            } else {
                revealDetail(address)
            }
            capture("restaurant-map-accessibility-text-" + suffix + "-address")
            var controls = [openMaps, showLocation]
            let locationError = app.staticTexts["Location access is off."]
            let openSettings = app.links["map-open-settings"]
            if locationError.exists { controls.append(locationError) }
            if openSettings.exists { controls.append(openSettings) }
            for control in controls {
                revealDetail(control)
                capture("restaurant-map-accessibility-text-" + suffix + "-" + control.label)
            }
        } else {
            visibleMapBottom = address.frame.minY - 16
            for control in [address, openMaps, showLocation] {
                XCTAssertTrue(control.isHittable)
                XCTAssertTrue(map.frame.contains(control.frame), "The complete address and native action must remain within the foreground map presentation.")
                XCTAssertTrue(app.frame.contains(control.frame))
            }
            capture("restaurant-map-accessibility-text-" + suffix)
        }
        // AX preserves the entire label even when text is visually ellipsized.
        // Compare its rendered height with the native font's complete layout.
        let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        let fullText = (address.label as NSString).boundingRect(with: CGSize(width: address.frame.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        XCTAssertGreaterThanOrEqual(address.frame.height + 4, fullText.height, "The full restaurant address must be rendered at the selected text size without an ellipsis.")
        XCTAssertGreaterThanOrEqual(visibleMapBottom - visibleMapTop, 100, "Restaurant details must leave a useful, unoccluded map viewport.")
        XCTAssertGreaterThanOrEqual(map.frame.width, 100)
        XCTAssertTrue(done.isHittable)
        XCTAssertTrue(bar.frame.contains(done.frame))
        XCTAssertTrue(app.frame.contains(done.frame))
        let geometry = XCTAttachment(string: "Map frame: \(map.frame)\nUnoccluded map height: \(visibleMapBottom - visibleMapTop)\nDetails frame: \(details.map { String(describing: $0.frame) } ?? "native bottom pane")\nAddress frame: \(address.frame)\nFull native text height: \(fullText.height)")
        geometry.name = "restaurant-map-" + suffix + "-visible-viewport"
        geometry.lifetime = .keepAlways
        add(geometry)
    }
}
