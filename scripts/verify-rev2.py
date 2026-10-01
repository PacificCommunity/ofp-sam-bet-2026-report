#!/usr/bin/env python3
"""Compare Rev.02 with the official WCPFC Rev.01, page by page."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request

import pymupdf

BASELINE_URL = "https://meetings.wcpfc.int/file/21634/download"
BASELINE_SHA256 = "263726a1d8abce66a2b951b63e975961d9c945cb0d4d1ae80e200e33fec7934d"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized(text):
    return re.sub(r"\s+", "", text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=Path("sources/WCPFC-SC22-2026-SA-WP06_Rev01.pdf"))
    parser.add_argument("--report", type=Path, default=Path("WCPFC-SC22-2026-SA-WP-06.pdf"))
    parser.add_argument("--output", type=Path, default=Path("sources/rev2-verification.json"))
    args = parser.parse_args()
    if not args.baseline.exists():
        args.baseline.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(BASELINE_URL, args.baseline)
    if sha256(args.baseline) != BASELINE_SHA256:
        raise SystemExit("The WCPFC baseline checksum differs from the verified Rev.01.")

    baseline = pymupdf.open(args.baseline)
    report = pymupdf.open(args.report)
    expected_changes = {1: "revision and issue date on the official cover",
                        2: "Figure 66 replacement added to revision history",
                        133: "Figure 66 replaced; caption retained"}
    result = {
        "baseline_url": BASELINE_URL,
        "baseline_sha256": BASELINE_SHA256,
        "report_sha256": sha256(args.report),
        "baseline_pages": len(baseline), "report_pages": len(report),
        "expected_changed_pages": expected_changes,
        "render_dpi": 144, "renderer": f"PyMuPDF {pymupdf.VersionBind}",
        "text_changed_pages": [], "visually_changed_pages": [],
        "unexpected_changed_pages": [],
        "mfclshiny_commit": "9d8eab27696b6f72dabb25dfe2fc68fc296294ee",
    }
    if len(baseline) != 148 or len(report) != 148:
        raise SystemExit("Expected 148 pages in both report revisions.")
    for i in range(148):
        old, new = baseline[i], report[i]
        if normalized(old.get_text()) != normalized(new.get_text()):
            result["text_changed_pages"].append(i + 1)
        a, b = old.get_pixmap(dpi=144), new.get_pixmap(dpi=144)
        if (a.width, a.height, a.samples) != (b.width, b.height, b.samples):
            result["visually_changed_pages"].append(i + 1)
    changes = set(result["text_changed_pages"]) | set(result["visually_changed_pages"])
    result["unexpected_changed_pages"] = sorted(changes - set(expected_changes))
    cover = normalized(report[0].get_text())
    revision = normalized(report[1].get_text())
    result["revision_and_date_correct"] = "WP06_Rev02" in cover and "1October2026" in cover
    result["revision_note_present"] = "Revision2(1October2026)" in revision and "ReplacedFigure66" in revision
    old_revision = normalized(baseline[1].get_text()).removesuffix("2")
    result["revision1_history_retained"] = revision.startswith(old_revision)
    # Only the two issue fields on the official cover may change. Compare all
    # surrounding pixels too, including logo, title, authors and affiliations.
    width, height = baseline[0].rect.width, baseline[0].rect.height
    clips = [(0, 0, width, 231), (0, 265, width, height),
             (0, 231, 359, 265), (548, 231, width, 265)]
    result["cover_unchanged_outside_issue_fields"] = all(
        baseline[0].get_pixmap(dpi=144, clip=clip).samples
        == report[0].get_pixmap(dpi=144, clip=clip).samples for clip in clips)
    old_caption = baseline[132].get_text().split("Figure 66:", 1)[1]
    new_caption = report[132].get_text().split("Figure 66:", 1)[1]
    result["figure66_caption_unchanged"] = normalized(old_caption) == normalized(new_caption)
    result["unchanged_pages"] = 148 - len(changes)
    result["passed"] = (not result["unexpected_changed_pages"]
                        and result["revision_and_date_correct"]
                        and result["revision_note_present"]
                        and result["revision1_history_retained"]
                        and result["cover_unchanged_outside_issue_fields"]
                        and result["figure66_caption_unchanged"])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    if not result["passed"]:
        raise SystemExit("Rev.02 comparison failed; inspect the verification record.")


if __name__ == "__main__":
    main()
