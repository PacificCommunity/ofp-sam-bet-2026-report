#!/usr/bin/env python3
"""Regenerate the preserved Figure 66 native reports in a new directory."""
import argparse
import concurrent.futures
import hashlib
import json
import math
from pathlib import Path
import platform
import re
import subprocess
import sys
import restore

HERE = Path(__file__).resolve().parent
BASELINE = b"1 1 1\n1 50 -4\n1 121 0\n1 246 1\n"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def par_number(data, heading):
    lines = data.decode().splitlines()
    for index, line in enumerate(lines):
        if line.strip() == heading:
            value = float(lines[index + 1].split()[0])
            if not math.isfinite(value):
                raise ValueError("Nonfinite PAR value: " + heading)
            return value
    raise ValueError("Missing PAR value: " + heading)


def evaluate(model, output, expected):
    subprocess.run([sys.executable, str(HERE / "restore.py"), model, str(output)], check=True)
    saved = json.loads((output / "saved-inputs.json").read_text())["files"]

    def unchanged():
        for name, row in saved.items():
            path = output / name
            if path.is_symlink() or not path.is_file():
                raise ValueError("Saved input replaced: " + name)
            data = path.read_bytes()
            if len(data) != row["bytes"] or sha(data) != row["sha256"]:
                raise ValueError("Saved input changed: " + name)

    unchanged()
    before = (output / "final.par").read_bytes()
    controls = BASELINE if model == "reference" else (output / "controls.txt").read_bytes()
    with (output / "mfcl-native.log").open("xb") as log:
        result = subprocess.run(["./mfclo64", "bet.frq", "final.par", "evaluated.par", "-file", "-"],
                                input=controls, cwd=output, stdout=log, stderr=subprocess.STDOUT,
                                timeout=600)
    unchanged()
    if result.returncode not in (0, 3):
        raise ValueError(f"Native evaluation failed for {model}: status {result.returncode}")
    par = (output / "evaluated.par").read_bytes()
    report = (output / "plot-evaluated.par.rep").read_bytes()
    if not par or not report or sha(report) != expected:
        raise ValueError(f"Native report differs for {model}: {sha(report)}; expected {expected}")
    count = par_number(par, "# The number of parameters")
    if count != par_number(before, "# The number of parameters"):
        raise ValueError("Active parameter count differs for " + model)
    objective = par_number(par, "# Objective function value")
    if model == "reference":
        saved_objective = par_number(before, "# Objective function value")
        values = re.findall(r"^\s*Total func\s+([^\s]+)\s*$",
                            (output / "mfcl-native.log").read_text(), re.MULTILINE)
        if not values or not math.isfinite(float(values[0])):
            raise ValueError("Missing fitted objective in native log")
        if abs(objective - saved_objective) > 1e-6 or abs(float(values[0]) - saved_objective) > 1e-6:
            raise ValueError("Fitted objective differs for reference")
    receipt = {"case": model, "input_par_sha256": sha(before), "report_sha256": sha(report),
               "active_parameters": int(count), "objective": objective,
               "native_status": result.returncode, "function_evaluations": 1}
    (output / "native-check.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(model + ": original native report reproduced", flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", help="reference, a removal group, or all")
    parser.add_argument("output", type=Path, help="a new output directory")
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "amd64"):
        parser.error("Native MFCL requires 64-bit x86 Linux")
    with restore.frozen_bytes(HERE / "package.json") as recipe_bytes:
        recipe = json.loads(recipe_bytes)
    expected = restore.read_json(recipe["expected_reports"])
    if args.case not in expected and args.case != "all":
        parser.error("Choose " + ", ".join(expected) + ", or all")
    if args.output.exists() or args.output.is_symlink():
        parser.error("Choose a new output directory")
    args.output = args.output.resolve()
    if (args.output == restore.REPO
            or restore.REPO in args.output.parents and restore.REPO / "outputs" not in args.output.parents):
        parser.error("Output inside the checkout must be beneath outputs/")
    if args.case == "all":
        restore.save_files(args.output, {}, "fishery-impact-collection")
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(evaluate, case, args.output / case, digest)
                       for case, digest in expected.items()]
            receipts = [item.result() for item in futures]
        (args.output / "native-checks.json").write_text(json.dumps(receipts, indent=2) + "\n")
    else:
        evaluate(args.case, args.output, expected[args.case])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error))
