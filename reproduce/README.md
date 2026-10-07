# Figure 66 native reader

The [standalone ZIP](figure66-standalone.zip) includes the fitted final.par,
all six MFCL inputs, mfclo64, original doitall.sh and the controls for eight
fishery-impact cases. Unzip it and enter `bet-figure66-standalone`, or use the
same commands from the report checkout:

```sh
make list
make verify
make prepare CASE=all OUT=/tmp/bet-inputs
make rerun CASE=all OUT=/tmp/bet-figure66
```

Use Make and base R; native MFCL runs require Linux x86-64. No network or
additional R packages are needed. System tar/XZ, `stat` and a SHA-256 utility must be
available. Choose a new absolute output directory; on macOS use `/private/tmp`.

Cases are `reference`, `longline`, `pole_line`, `ps`, `ps_associated`,
`ps_unassociated`, `miscellaneous` and `all_off`. `make restore` also prepares
inputs. `CASE=all` processes all eight sequentially.

Each rerun uses the saved PAR and original controls, then checks its **whole
REP checksum** against [READER-CASES.csv](READER-CASES.csv). Outputs include the
evaluated PAR, REP, other native reports, log and CSV check. The reference also
checks objective agreement within `1e-6`; every case checks its parameter count.
The prescribed evaluation ceiling is one; the receipt does not measure a
native function counter.

[READER-FILES.csv](READER-FILES.csv) records exact input sources and checksums.
The original [closure.json](closure.json), manifests and 45-byte
[native.tar.gz](native.tar.gz) placeholder remain available. The complete
offline inputs are in [reader-native.tar.xz](reader-native.tar.xz). Whole-REP
checks establish compatibility with the supplied binary; the historical
external executable hash remains unknown.

For a new fit from the original Diagnostic inputs:

```sh
make fullfit CASE=reference OUT=/tmp/bet-fullfit
```

This runs the preserved doitall, which includes its own settings. Full fitting
applies to `reference`; removal cases evaluate that fitted model. No full-fit
equivalence is claimed.

The published PDF, figures and calculations are preserved. See
[Figure 66 methods](../figures_new/fishery-impact/README.md) for the figure and
[document reproduction](../docs/reproduction.md) for the separate, original
`make build` workflow.
