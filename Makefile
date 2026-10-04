.DEFAULT_GOAL := help
CASE ?= all
OUT ?=
export CASE OUT
.PHONY: help verify rerun restore build _check-output _check-build-output

help:
	@printf '%s\n' 'make verify                        Check preserved report and native recipe' 'make rerun CASE=all OUT=/tmp/bet-figure66' 'make restore CASE=reference OUT=/tmp/bet-inputs' 'make build OUT=/tmp/bet-report-build' 'Build copies committed sources to a fresh directory; published files stay in place.' 'Native reruns require Linux x86-64. PDF builds need the pinned runtime in docs/reproduction.md.'

verify:
	python3 ci/verify-preserved-files.py
	python3 reproduce/restore.py --verify
	Rscript scripts/audit-assessment-values.R .
	Rscript scripts/audit-cross-references.R .

rerun: _check-output
	python3 reproduce/run-native.py "$$CASE" "$$OUT"

restore: _check-output
	python3 reproduce/restore.py "$$CASE" "$$OUT"

build: _check-output _check-build-output
	@mkdir -p "$$(dirname -- "$$OUT")" && mkdir "$$OUT"
	@bash -o pipefail -c 'git archive HEAD | tar -x -C "$$OUT"'
	@cd "$$OUT" && Rscript scripts/audit-cross-references.R . && Rscript scripts/audit-assessment-values.R . && quarto render main.qmd --to pdf && python3 scripts/finalize-rev2-cover.py && python3 scripts/verify-rev2.py

_check-build-output:
	@python3 -c 'import os; from pathlib import Path; p=Path(os.environ["OUT"]).resolve(); root=Path.cwd().resolve(); assert root != p and root not in p.parents, "Build OUT must be outside this checkout"'

_check-output:
	@python3 -c 'import os; from pathlib import Path; raw=os.environ.get("OUT", ""); p=Path(raw); root=Path.cwd().resolve(); assert raw and p.is_absolute(), "Set OUT to an absolute, new directory"; assert not os.path.lexists(p), "OUT already exists; choose a new directory"; q=p.resolve(); assert q != root and (root not in q.parents or root/"outputs" in q.parents), "OUT inside the checkout must be beneath outputs/"'
