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


if __name__ == "__main__":
    unittest.main()
