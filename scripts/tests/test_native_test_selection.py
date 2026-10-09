"""Coverage failures must remain failures even when aggregate counts look correct."""
import copy
import importlib.util
import pathlib
import os
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "native-test-selection.py"
SPEC = importlib.util.spec_from_file_location("native_test_selection", SCRIPT)
selection = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(selection)

UNIT = "SplitMyMealTests/MealStoreTests/testSavedState()"
UI_A = "SplitMyMealUITests/MealJourneyTests/testCancel()"
UI_B = "SplitMyMealUITests/MealJourneyTests/testShare()"
LIVE = "SplitMyMealUITests/LiveMapKitTests/testProvider()"


def catalogue():
    return {"schemaVersion": 1, "partitions": {"a": [UNIT, UI_A], "b": [UI_B]}, "disabledLiveTests": [LIVE]}


def enumeration():
    return {"errors": [], "values": [{"testPlan": "Meal", "enabledTests": [
        {"identifier": value} for value in [UNIT, UI_A, UI_B]], "disabledTests": [{"identifier": LIVE}]}]}


def results(ids):
    bundles = []
    for target in ["SplitMyMealTests", "SplitMyMealUITests"]:
        cases = [{"nodeType": "Test Case", "nodeIdentifier": value.split("/", 1)[1], "result": "Passed"}
                 for value in ids if value.startswith(target + "/")]
        if cases:
            bundles.append({"nodeType": "Unit test bundle" if target == "SplitMyMealTests" else "UI test bundle",
                            "name": target, "children": [{"nodeType": "Test Suite", "children": cases}]})
    return {"testNodes": [{"nodeType": "Test Plan", "children": bundles}]}


def summary(count):
    return {"result": "Passed", "totalTestCount": count, "passedTests": count,
            "failedTests": 0, "skippedTests": 0, "expectedFailures": 0}


class CompiledCoverageTests(unittest.TestCase):
    def test_disjoint_selection_covers_all_enabled_native_cases(self):
        a = selection.select_tests(catalogue(), enumeration(), "a")
        b = selection.select_tests(catalogue(), enumeration(), "b")
        self.assertFalse(set(a["testIdentifiers"]) & set(b["testIdentifiers"]))
        self.assertEqual(set(a["testIdentifiers"] + b["testIdentifiers"]), {UNIT, UI_A, UI_B})

    def test_same_count_with_omitted_and_unexpected_case_is_rejected(self):
        native = enumeration()
        native["values"][0]["enabledTests"][-1]["identifier"] = "SplitMyMealUITests/MealJourneyTests/testUnexpected()"
        with self.assertRaisesRegex(ValueError, "missing=.*unexpected="):
            selection.select_tests(catalogue(), native, "a")

    def test_duplicate_catalogue_and_duplicate_native_ids_are_rejected(self):
        conflict = catalogue()
        conflict["partitions"]["b"].append(UNIT)
        with self.assertRaisesRegex(ValueError, "duplicate"):
            selection.select_tests(conflict, enumeration(), "a")
        native = enumeration()
        native["values"][0]["enabledTests"].append({"identifier": UNIT})
        with self.assertRaisesRegex(ValueError, "duplicate"):
            selection.select_tests(catalogue(), native, "a")

    def test_errors_multiple_configurations_and_invalid_partition_fail_closed(self):
        for change in ["errors", "multiple", "partition"]:
            with self.subTest(change=change):
                native = enumeration()
                if change == "errors": native["errors"] = ["Enumeration failed"]
                if change == "multiple": native["values"].append(copy.deepcopy(native["values"][0]))
                with self.assertRaises(ValueError):
                    selection.select_tests(catalogue(), native, "unknown" if change == "partition" else "a")

    def test_live_suite_cannot_silently_move_into_stable_coverage(self):
        native = enumeration()
        native["values"][0]["enabledTests"].append({"identifier": LIVE})
        with self.assertRaisesRegex(ValueError, "both enabled and disabled"):
            selection.select_tests(catalogue(), native, "a")

    def test_duplicate_json_keys_are_not_silently_replaced(self):
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "catalogue.json"
            path.write_text('{"partitions": {}, "partitions": {"a": []}}')
            with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
                selection.read_json(path)

    def test_partition_runner_rejects_invalid_partition_and_caller_override_before_startup(self):
        runner = SCRIPT.parent / "verify-ios.sh"
        for partition, arguments in [("wrong", []), ("a", ["-only-testing:SplitMyMealTests"]),
                                     ("b", ["-default-test-execution-time-allowance", "999"]),
                                     ("a", ["-retry-tests-on-failure"])]:
            with self.subTest(partition=partition, arguments=arguments):
                result = subprocess.run(["/bin/bash", str(runner), *arguments],
                                        env={**os.environ, "VERIFICATION_PARTITION": partition},
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Partition" if arguments else "VERIFICATION_PARTITION", result.stderr)


class NativeResultTests(unittest.TestCase):
    def setUp(self):
        self.selected = selection.select_tests(catalogue(), enumeration(), "a")

    def test_native_bundle_ancestry_identifies_unit_and_ui_targets(self):
        verified = selection.verify_results(self.selected, results([UNIT, UI_A]), summary(2))
        self.assertEqual({case["identifier"] for case in verified["cases"]}, {UNIT, UI_A})

    def test_same_count_does_not_hide_missing_or_unexpected_execution(self):
        with self.assertRaisesRegex(ValueError, "missing=.*unexpected="):
            selection.verify_results(self.selected, results([UNIT, UI_B]), summary(2))

    def test_duplicate_executed_cases_fail_even_with_matching_pass_count(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            selection.verify_results(self.selected, results([UNIT, UNIT]), summary(2))

    def test_failed_skipped_and_unfinished_cases_cannot_be_certified_by_passed_summary(self):
        for status in ["Failed", "Skipped", "Not Run", None]:
            with self.subTest(status=status):
                tree = results([UNIT, UI_A])
                tree["testNodes"][0]["children"][1]["children"][0]["children"][0]["result"] = status
                with self.assertRaisesRegex(ValueError, "must pass"):
                    selection.verify_results(self.selected, tree, summary(2))

    def test_incomplete_summary_and_missing_bundle_ancestry_fail_closed(self):
        incomplete = summary(2)
        incomplete["result"] = "Unknown"
        with self.assertRaisesRegex(ValueError, "summary"):
            selection.verify_results(self.selected, results([UNIT, UI_A]), incomplete)
        with self.assertRaisesRegex(ValueError, "ancestry"):
            selection.native_cases({"testNodes": [{"nodeType": "Test Case", "nodeIdentifier": "MealStoreTests/testSavedState()", "result": "Passed"}]})


class FocusedSelectorTests(unittest.TestCase):
    def test_target_class_method_and_optional_parentheses_match_exact_native_paths(self):
        for requested in ["SplitMyMealUITests", "SplitMyMealUITests/MealJourneyTests",
                          UI_A, UI_A.removesuffix("()")]:
            with self.subTest(requested=requested):
                captured = selection.focused_selectors(["-only-testing:" + requested])
                proof = selection.verify_focused_results({"selectors": captured}, results([UI_A]), summary(1))
                self.assertEqual(proof["result"], "Passed")
                self.assertEqual(proof["matches"][0]["cases"], [{"identifier": UI_A, "status": "Passed"}])
                self.assertIn("full class coverage is not certified", proof["scope"])

    def test_overlapping_scopes_retain_matches_without_duplicating_actual_execution(self):
        request = {"selectors": ["SplitMyMealUITests", "SplitMyMealUITests/MealJourneyTests", UI_A]}
        proof = selection.verify_focused_results(request, results([UI_A, UI_B]), summary(2))
        self.assertEqual(proof["result"], "Passed")
        self.assertEqual(proof["actualCaseCount"], 2)
        self.assertEqual([len(match["cases"]) for match in proof["matches"]], [2, 2, 1])

    def test_valid_plus_unknown_selector_rejects_even_when_native_summary_passes(self):
        unknown = "SplitMyMealUITests/MealJourneyTests/testMissing()"
        proof = selection.verify_focused_results({"selectors": [UI_A, unknown]}, results([UI_A]), summary(1))
        self.assertEqual(proof["result"], "Rejected")
        self.assertEqual(proof["matches"][0]["cases"][0]["status"], "Passed")
        self.assertEqual(proof["matches"][1]["cases"], [])
        self.assertIn(unknown, ";".join(proof["reasons"]))

    def test_near_prefix_target_class_and_method_never_match(self):
        for selector in ["SplitMyMealUITest", "SplitMyMealUITests/MealJourneyTest",
                         "SplitMyMealUITests/MealJourneyTests/testCan()"]:
            with self.subTest(selector=selector):
                proof = selection.verify_focused_results({"selectors": [selector]}, results([UI_A]), summary(1))
                self.assertEqual(proof["result"], "Rejected")
                self.assertEqual(proof["matches"][0]["cases"], [])

    def test_malformed_and_duplicate_focused_requests_fail_before_execution(self):
        invalid = ["", "SplitMyMealUITests/", "/MealJourneyTests", "T/C/M/extra", "T//M",
                   "T/*", "@response-file", "T/C/M(x)", "T()", "T/C()"]
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(ValueError):
                selection.focused_selectors(["-only-testing:" + value])
        with self.assertRaisesRegex(ValueError, "colon-form"):
            selection.focused_selectors(["-only-testing", UI_A])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            selection.focused_selectors(["-only-testing:" + UI_A, "-only-testing:" + UI_A.removesuffix("()")])

    def test_duplicate_native_cases_cannot_inflate_focused_coverage(self):
        proof = selection.verify_focused_results({"selectors": [UI_A]}, results([UI_A, UI_A]), summary(2))
        self.assertEqual(proof["result"], "Rejected")
        self.assertIn("duplicate", ";".join(proof["reasons"]))

    def test_skipped_live_selection_is_reported_as_skipped_not_provider_execution_pass(self):
        tree = results([LIVE])
        tree["testNodes"][0]["children"][0]["children"][0]["children"][0]["result"] = "Skipped"
        native_summary = {**summary(1), "result": "Skipped", "passedTests": 0, "skippedTests": 1}
        proof = selection.verify_focused_results({"selectors": ["SplitMyMealUITests/LiveMapKitTests"]}, tree, native_summary)
        self.assertEqual(proof["result"], "Skipped")
        self.assertEqual(proof["passedCaseCount"], 0)
        self.assertEqual(proof["matches"][0]["cases"][0]["status"], "Skipped")
        missing = selection.verify_focused_results({"selectors": ["SplitMyMealUITests/LiveMapKitTests"]}, results([UI_A]), summary(1))
        self.assertEqual(missing["result"], "Rejected")

    def test_nonpassing_or_inconsistent_native_outcomes_are_not_certified(self):
        for state in ["Failed", "Not Run", None]:
            with self.subTest(state=state):
                tree = results([UI_A])
                tree["testNodes"][0]["children"][0]["children"][0]["children"][0]["result"] = state
                proof = selection.verify_focused_results({"selectors": [UI_A]}, tree, summary(1))
                self.assertEqual(proof["result"], "Rejected")

    def test_full_invocation_removes_checker_owned_stale_focused_request(self):
        with tempfile.TemporaryDirectory() as folder:
            request = pathlib.Path(folder) / "request.json"
            request.write_text('{"selectors": ["SplitMyMealUITests/OldClass"]}')
            result = subprocess.run(["python3", str(SCRIPT), "capture-focused", "--request", str(request), "--"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(request.exists())

    def test_missing_or_empty_native_evidence_writes_rejection_instead_of_bypassing_check(self):
        with tempfile.TemporaryDirectory() as folder:
            root = pathlib.Path(folder)
            request = root / "request.json"
            request.write_text('{"selectors": ["SplitMyMealUITests/MealJourneyTests/testCancel()"]}')
            native_summary = root / "summary.json"
            native_summary.write_text('{"result":"Passed","totalTestCount":1,"passedTests":1}')
            for content in [None, ""]:
                with self.subTest(content=content):
                    tree = root / "native-tests.json"
                    if content is not None:
                        tree.write_text(content)
                    report = root / "report.json"
                    result = subprocess.run(["python3", str(SCRIPT), "verify-focused", "--request", str(request),
                                             "--native-tests", str(tree), "--summary", str(native_summary),
                                             "--report", str(report)], capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(selection.read_json(report)["result"], "Rejected")
                    self.assertTrue(request.exists())

    def test_runner_rejects_separate_form_before_native_toolchain_access(self):
        with tempfile.TemporaryDirectory() as folder:
            env = {**os.environ, "SIMULATOR_UDID": "dedicated-test-placeholder", "ARTIFACTS_DIR": folder}
            env.pop("VERIFICATION_PARTITION", None)
            result = subprocess.run(["/bin/bash", str(SCRIPT.parent / "verify-ios.sh"), "-only-testing", UI_A],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("colon-form", result.stderr)
            self.assertFalse((pathlib.Path(folder) / "toolchain.txt").exists())


if __name__ == "__main__":
    unittest.main()
