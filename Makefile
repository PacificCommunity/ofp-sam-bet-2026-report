.DEFAULT_GOAL := help
CASE ?= all
OUT ?=
export CASE OUT
.PHONY: help list verify prepare rerun restore fullfit build _check-output _check-build-output

help:
	@printf '%s\n' 'make list                          List the eight Figure 66 cases' 'make verify                        Check preserved report and native inputs' 'make prepare CASE=all OUT=/tmp/bet-inputs' 'make rerun CASE=all OUT=/tmp/bet-figure66' 'make restore CASE=reference OUT=/tmp/bet-inputs' 'make fullfit CASE=reference OUT=/tmp/bet-fullfit' 'make build OUT=/tmp/bet-report-build' 'Readers need Make, base R, tar/XZ and a SHA-256 system utility.' 'Native runs require Linux x86-64. PDF builds use the original pinned document runtime.'

list:
	Rscript reproduce/reader.R list

verify:
	Rscript reproduce/reader.R verify
	Rscript scripts/audit-assessment-values.R .
	Rscript scripts/audit-cross-references.R .

rerun: _check-output
	Rscript reproduce/reader.R rerun "$$CASE" "$$OUT"

restore: _check-output
	Rscript reproduce/reader.R prepare "$$CASE" "$$OUT"

prepare: restore

fullfit: _check-output
	Rscript reproduce/reader.R fullfit "$$CASE" "$$OUT"

build: _check-output _check-build-output
	@mkdir -p "$$(dirname -- "$$OUT")" && mkdir "$$OUT"
	@bash -o pipefail -c 'git archive HEAD | tar -x -C "$$OUT"'
	@cd "$$OUT" && Rscript scripts/audit-cross-references.R . && Rscript scripts/audit-assessment-values.R . && quarto render main.qmd --to pdf && python3 scripts/finalize-rev2-cover.py && python3 scripts/verify-rev2.py

_check-build-output:
	@Rscript reproduce/reader.R check-build-output "$$OUT"

_check-output:
	@Rscript reproduce/reader.R check-output "$$OUT"
