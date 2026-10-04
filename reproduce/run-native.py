#!/usr/bin/env python3
"""Regenerate the preserved Figure 66 native reports in a new directory."""
import argparse
import concurrent.futures
import contextlib
import hashlib
import json
import math
from pathlib import Path
import platform
import re
import subprocess
import sys
import restore
from native_directory import NativeDirectory, original_files

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


def evaluate(model, output, expected, directory=None):
    if directory is None:
        subprocess.run([sys.executable, str(HERE / "restore.py"), model, str(output)], check=True)
    with (contextlib.nullcontext(directory) if directory is not None else NativeDirectory(output)) as output:
        saved = json.loads(output.read_bytes("saved-inputs.json"))["files"]

        def unchanged():
            for name, row in saved.items():
                data = output.read_bytes(name)
                if len(data) != row["bytes"] or sha(data) != row["sha256"]:
                    raise ValueError("Saved input changed: " + name)

        unchanged()
        before = output.read_bytes("final.par")
        controls = BASELINE if model == "reference" else output.read_bytes("controls.txt")
        input_name, output_name = (("10.par", "11.par") if model == "reference"
                                   else ("base.par", "evaluated.par"))
        output.write_new(input_name, before)
        with output.open_input("mfclo64") as (engine_fd, engine_bytes):
            if sha(engine_bytes) != saved["mfclo64"]["sha256"]:
                raise ValueError("Native executable changed before evaluation")
            with output.open_new("mfcl-native.log") as log:
                result = subprocess.run(["./mfclo64", "bet.frq", input_name, output_name, "-file", "-"],
                                        input=controls, stdout=log, stderr=subprocess.STDOUT, timeout=600,
                                        executable=output.child_file(engine_fd),
                                        **output.child_kwargs(engine_fd))
        unchanged()
        if result.returncode not in (0, 3):
            raise ValueError(f"Native evaluation failed for {model}: status {result.returncode}")
        if sha(output.read_bytes(input_name)) != sha(before):
            raise ValueError("Staged final PAR changed for " + model)
        par = output.read_bytes(output_name)
        report = output.read_bytes("plot-" + output_name + ".rep")
        if not par or not report or sha(report) != expected:
            raise ValueError(f"Native report differs for {model}: {sha(report)}; expected {expected}")
        count = par_number(par, "# The number of parameters")
        if count != par_number(before, "# The number of parameters"):
            raise ValueError("Active parameter count differs for " + model)
        objective = par_number(par, "# Objective function value")
        if model == "reference":
            saved_objective = par_number(before, "# Objective function value")
            values = re.findall(r"^\s*Total func\s+([^\s]+)\s*$",
                                output.read_bytes("mfcl-native.log").decode(), re.MULTILINE)
            if not values or not math.isfinite(float(values[0])):
                raise ValueError("Missing fitted objective in native log")
            if abs(objective - saved_objective) > 1e-6 or abs(float(values[0]) - saved_objective) > 1e-6:
                raise ValueError("Fitted objective differs for reference")
        receipt = {"case": model, "input_par_sha256": sha(before), "report_sha256": sha(report),
                   "active_parameters": int(count), "objective": objective,
                   "native_status": result.returncode, "function_evaluations": 1}
        output.write_new("native-check.json", (json.dumps(receipt, indent=2) + "\n").encode())
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
        with NativeDirectory(args.output) as collection:
            def check(case, digest):
                files = original_files(restore, case)
                with collection.create_child(case) as directory:
                    directory.stage_files(files, case)
                    return evaluate(case, directory.path, digest, directory)
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(check, case, digest) for case, digest in expected.items()]
                receipts = [item.result() for item in futures]
            collection.write_new("native-checks.json", (json.dumps(receipts, indent=2) + "\n").encode())

    else:
        evaluate(args.case, args.output, expected[args.case])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error))
