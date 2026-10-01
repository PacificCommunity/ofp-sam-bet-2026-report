#!/usr/bin/env python3
"""Retain the published WCPFC cover while updating only its date and revision."""
import argparse
import hashlib
from pathlib import Path

import pymupdf


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path, help="Official WCPFC Rev.01 PDF")
    parser.add_argument("--output", type=Path, default=Path("sources/wcpfc-sc22-cover-rev2.pdf"))
    args = parser.parse_args()
    expected = "263726a1d8abce66a2b951b63e975961d9c945cb0d4d1ae80e200e33fec7934d"
    if hashlib.sha256(args.baseline.read_bytes()).hexdigest() != expected:
        raise SystemExit("The baseline is not the verified official WCPFC Rev.01.")
    source = pymupdf.open(args.baseline)
    document = pymupdf.open()
    document.insert_pdf(source, from_page=0, to_page=0)
    page = document[0]
    font_xref = next(item[0] for item in source[0].get_fonts()
                     if "Calibri-Bold" in item[3] and item[2] == "Type0")
    font_data = source.extract_font(font_xref)[3]
    font = pymupdf.Font(fontbuffer=font_data)
    updates = [("WCPFC-SC22-2026-SA-WP06_Rev01", "WCPFC-SC22-2026-SA-WP06_Rev02"),
               ("9 August 2026", "1 October 2026")]
    placements = []
    for old, new in updates:
        spans = [span for block in page.get_text("dict")["blocks"] if "lines" in block
                 for line in block["lines"] for span in line["spans"]
                 if span["text"].strip() == old]
        if len(spans) != 1:
            raise SystemExit(f"Expected one cover field: {old}")
        span = spans[0]
        rectangle = pymupdf.Rect(span["bbox"]) + (-1, -1, 1, 1)
        page.add_redact_annot(rectangle, fill=(1, 1, 1))
        placements.append((new, span["origin"][1], span["size"]))
    page.apply_redactions(images=0, graphics=0)
    page.insert_font(fontname="CoverCalibriBold", fontbuffer=font_data)
    for text, y, size in placements:
        x = 540.184 - font.text_length(text, fontsize=size)
        page.insert_text((x, y), text, fontsize=size, fontname="CoverCalibriBold", color=(0, 0, 0))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    document.save(args.output, garbage=4, deflate=True)
    print(args.output)


if __name__ == "__main__":
    main()
