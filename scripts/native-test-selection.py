#!/usr/bin/env python3
"""Bind hosted partitions to compiled XCTest identities and completed native results."""
import argparse
import hashlib
import json
import pathlib
import re
import sys


def read_json(path):
    """Read evidence, rejecting duplicate object keys rather than silently replacing them."""
    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(pathlib.Path(path).read_text(), object_pairs_hook=unique_keys)


def identifiers(values, label, full=True):
    """Require unique complete native case IDs; suite-level selectors cannot certify coverage."""
    if not isinstance(values, list) or not values:
        raise ValueError(f"{label} must be a nonempty list of case identifiers.")
    prefix = r"SplitMyMeal(?:UITests|Tests)/" if full else ""
    pattern = prefix + r"[A-Za-z_][A-Za-z0-9_]*/test[A-Za-z0-9_]+\(\)"
    if any(not isinstance(value, str) or not re.fullmatch(pattern, value) for value in values):
        raise ValueError(f"{label} contains an invalid or incomplete native case identifier.")
    if len(set(values)) != len(values):
        raise ValueError(f"{label} contains duplicate case identifiers.")
    return values


def select_tests(catalogue, enumeration, partition):
    """Return one disjoint partition only when its catalogue exactly covers compiled stable tests."""
    if partition not in {"a", "b"}:
        raise ValueError("VERIFICATION_PARTITION must be a or b.")
    groups = catalogue.get("partitions", {})
    if catalogue.get("schemaVersion") != 1 or set(groups) != {"a", "b"}:
        raise ValueError("Catalogue requires schemaVersion 1 and exactly partitions a and b.")
    a = identifiers(groups["a"], "Partition a")
    b = identifiers(groups["b"], "Partition b")
    stable = identifiers(a + b, "Combined partitions")
    disabled = identifiers(catalogue.get("disabledLiveTests"), "Disabled Live catalogue")
    if any("/LiveMapKitTests/" in value for value in stable) or any(
        not value.startswith("SplitMyMealUITests/LiveMapKitTests/") for value in disabled
    ):
        raise ValueError("Stable partitions and explicitly disabled Live cases must remain separate.")
    if enumeration.get("errors") != []:
        raise ValueError("Native enumeration reported errors; inspect test-enumeration.json.")
    configs = enumeration.get("values")
    if not isinstance(configs, list) or len(configs) != 1:
        raise ValueError("Native enumeration must contain exactly one test-plan configuration.")
    config = configs[0]
    enabled = identifiers([entry["identifier"] for entry in config["enabledTests"]], "Enabled native tests")
    native_disabled = identifiers([entry["identifier"] for entry in config["disabledTests"]], "Disabled native tests")
    if set(enabled) & set(native_disabled):
        raise ValueError("Native enumeration lists a case as both enabled and disabled.")
    missing = sorted(set(stable) - set(enabled))
    unexpected = sorted(set(enabled) - set(stable))
    if missing or unexpected:
        raise ValueError(f"Compiled stable coverage differs from catalogue: missing={missing}, unexpected={unexpected}")
    if set(native_disabled) != set(disabled):
        raise ValueError("Compiled disabled Live cases differ from the explicit catalogue.")
    return {"schemaVersion": 1, "partition": partition, "testIdentifiers": groups[partition],
            "stableTestCount": len(stable), "selectedTestCount": len(groups[partition]),
            "disabledLiveTests": disabled}


def native_cases(tree):
    """Infer each case's target from its native test-bundle ancestry, preserving duplicate cases."""
    cases = []
    def walk(node, target=None):
        if node.get("nodeType") in {"Unit test bundle", "UI test bundle"}:
            target = node["name"]
            if target not in {"SplitMyMealTests", "SplitMyMealUITests"}:
                raise ValueError(f"Unexpected native test bundle: {target}")
        if node.get("nodeType") == "Test Case":
            if target is None:
                raise ValueError("Native test case has no authoritative bundle ancestry.")
            identifier = node["nodeIdentifier"]
            identifiers([identifier], "Native result case", full=False)
            cases.append({"identifier": f"{target}/{identifier}", "status": node.get("result")})
        for child in node.get("children", []):
            walk(child, target)
    for node in tree["testNodes"]:
        walk(node)
    return cases


def verify_results(selection, tree, summary):
    """Reject missing, extra, duplicated, skipped, failed or incomplete selected native results."""
    expected = identifiers(selection["testIdentifiers"], "Selected tests")
    cases = native_cases(tree)
    actual = identifiers([case["identifier"] for case in cases], "Executed native tests")
    missing, unexpected = sorted(set(expected) - set(actual)), sorted(set(actual) - set(expected))
    if missing or unexpected:
        raise ValueError(f"Executed native coverage differs from selection: missing={missing}, unexpected={unexpected}")
    nonpassing = [case for case in cases if case["status"] != "Passed"]
    if nonpassing:
        raise ValueError(f"Every selected native case must pass: {nonpassing}")
    if (summary.get("result") != "Passed" or summary.get("totalTestCount") != len(expected)
            or summary.get("passedTests") != len(expected) or summary.get("failedTests") != 0
            or summary.get("skippedTests") != 0 or summary.get("expectedFailures", 0) != 0):
        raise ValueError("Native summary does not certify the exact completed selection without failures or skips.")
    return {"partition": selection["partition"], "result": "Passed", "verifiedCaseCount": len(cases), "cases": cases}


def focused_selectors(arguments):
    """Accept colon-form target/class/method scopes; optional method parentheses normalize to native IDs."""
    selectors = []
    for argument in arguments:
        if argument == "-only-testing":
            raise ValueError("Use colon-form -only-testing:Target[/Class[/testMethod]]; separate-form selectors are unsupported.")
        if not argument.startswith("-only-testing:"):
            continue
        value = argument[len("-only-testing:"):]
        parts = value.split("/")
        if not 1 <= len(parts) <= 3 or any(
            not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*(?:\(\))?" if index == 2
                             else r"[A-Za-z_][A-Za-z0-9_]*", part)
            for index, part in enumerate(parts)
        ):
            raise ValueError("Focused selectors require one to three exact path segments; empty segments, wildcards and response files are unsupported.")
        if len(parts) == 3 and not parts[2].endswith("()"):
            parts[2] += "()"
        selectors.append("/".join(parts))
    if len(set(selectors)) != len(selectors):
        raise ValueError("Focused selectors contain duplicate requests.")
    return selectors


def verify_focused_results(request, tree, summary):
    """Require each requested scope to match native identities; target/class scopes certify at least one case only."""
    selectors = focused_selectors(["-only-testing:" + value for value in request["selectors"]])
    if not selectors:
        raise ValueError("Focused verification requires at least one requested selector.")
    cases = native_cases(tree)
    errors = []
    actual = [case["identifier"] for case in cases]
    if len(set(actual)) != len(actual):
        errors.append("Executed native tests contain duplicate case identifiers.")
    matches = []
    covered = set()
    for selector in selectors:
        parts = selector.split("/")
        matched = [case for case in cases if case["identifier"].split("/")[:len(parts)] == parts]
        matches.append({"selector": selector, "cases": matched})
        covered.update(case["identifier"] for case in matched)
        if not matched:
            errors.append(f"Requested selector matched no actual native case: {selector}")
    unexpected = sorted(set(actual) - covered)
    if unexpected:
        errors.append(f"Native cases outside the requested scopes: {unexpected}")
    if any(case["status"] not in {"Passed", "Skipped"} for case in cases):
        errors.append("Focused native cases include failed or incomplete outcomes.")
    passed = sum(case["status"] == "Passed" for case in cases)
    skipped = sum(case["status"] == "Skipped" for case in cases)
    if (summary.get("result") not in {"Passed", "Skipped"} or summary.get("totalTestCount") != len(cases)
            or summary.get("passedTests") != passed or summary.get("skippedTests") != skipped
            or summary.get("failedTests") != 0 or summary.get("expectedFailures", 0) != 0):
        errors.append("Native summary does not match the actual completed focused identities and statuses.")
    report = {"scope": "Each target/class selector matches at least one actual native case; full class coverage is not certified.",
              "result": "Rejected" if errors else "Passed" if passed else "Skipped",
              "requestedSelectorCount": len(selectors), "actualCaseCount": len(cases),
              "passedCaseCount": passed, "skippedCaseCount": skipped,
              "matches": matches, "cases": cases}
    if errors:
        report["reasons"] = errors
    return report


def main():
    """Write reproducible selection or result evidence; validation failures exit nonzero."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    select = commands.add_parser("select")
    for name in ("catalogue", "enumeration", "partition", "selection", "response-file"):
        select.add_argument("--" + name, required=True)
    verify = commands.add_parser("verify")
    for name in ("selection", "native-tests", "summary", "report"):
        verify.add_argument("--" + name, required=True)
    capture = commands.add_parser("capture-focused")
    capture.add_argument("--request", required=True)
    capture.add_argument("arguments", nargs=argparse.REMAINDER)
    focused = commands.add_parser("verify-focused")
    for name in ("request", "native-tests", "summary", "report"):
        focused.add_argument("--" + name, required=True)
    args = parser.parse_args()
    try:
        if args.command == "select":
            result = select_tests(read_json(args.catalogue), read_json(args.enumeration), args.partition)
            for name in ("catalogue", "enumeration"):
                result[name + "Sha256"] = hashlib.sha256(pathlib.Path(getattr(args, name)).read_bytes()).hexdigest()
            pathlib.Path(args.selection).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
            pathlib.Path(args.response_file).write_text("\n".join(result["testIdentifiers"]) + "\n")
        elif args.command == "verify":
            result = verify_results(read_json(args.selection), read_json(args.native_tests), read_json(args.summary))
            pathlib.Path(args.report).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        elif args.command == "capture-focused":
            selectors = focused_selectors(args.arguments)
            if selectors:
                pathlib.Path(args.request).write_text(json.dumps({"selectors": selectors}, indent=2) + "\n")
            else:
                pathlib.Path(args.request).unlink(missing_ok=True)
            print(f"Focused native selectors captured: {len(selectors)}.")
            return
        else:
            result = verify_focused_results(read_json(args.request), read_json(args.native_tests), read_json(args.summary))
            pathlib.Path(args.report).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
            if result["result"] == "Rejected":
                parser.exit(1, "Focused native selection rejected: " + "; ".join(result["reasons"]) + "\n")
            print(f"Focused native results: {result['passedCaseCount']} passed, {result['skippedCaseCount']} skipped.")
            return
        print(f"Native partition {result['partition']}: {result.get('selectedTestCount', result.get('verifiedCaseCount'))} exact cases.")
    except (ValueError, KeyError, TypeError, OSError) as error:
        if args.command in {"verify", "verify-focused", "capture-focused"}:
            path = args.request if args.command == "capture-focused" else args.report
            pathlib.Path(path).write_text(json.dumps({"result": "Rejected", "reason": str(error)}, indent=2) + "\n")
        parser.exit(1, f"Native selection rejected: {error}\n")


if __name__ == "__main__":
    main()
