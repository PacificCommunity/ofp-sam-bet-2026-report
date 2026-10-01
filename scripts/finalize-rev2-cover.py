#!/usr/bin/env python3
"""Use the official cover at its exact original size after the Quarto build.

LaTeX's PDF-page embedding slightly scales the imported cover. Replacing that
page directly preserves its pixels outside the two revised issue fields.
All body pages, metadata and outline destinations are retained.
"""
from pathlib import Path
import pymupdf

root = Path(__file__).resolve().parents[1]
path = root / "WCPFC-SC22-2026-SA-WP-06.pdf"
cover_path = root / "sources/wcpfc-sc22-cover-rev2.pdf"
document = pymupdf.open(path)
cover = pymupdf.open(cover_path)
if len(document) != 148 or len(cover) != 1:
    raise SystemExit("Unexpected page count; refusing to replace the cover.")
if "WP06_Rev02" not in cover[0].get_text():
    raise SystemExit("The replacement cover is not Rev.02.")
toc = document.get_toc(simple=False)
document.delete_page(0)
document.insert_pdf(cover, from_page=0, to_page=0, start_at=0)
document.set_toc(toc)
temporary = path.with_suffix(".cover.tmp.pdf")
document.save(temporary, garbage=3, deflate=True)
document.close()
temporary.replace(path)
print("Official cover restored without LaTeX scaling; 148 pages retained.")
