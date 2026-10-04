# Figure 66 native outputs

The [source list](closure.json) pins each file used for restoration. The shared
helper uses an empty `native.tar.gz`; the model files are fetched from those
checksum-verified public Git sources. A normal clone retains the controls and
restoration recipe.

The fitted PAR, six MFCL inputs and executable reuse the public Diagnostic
repository at pinned commits. The seven removal controls are already retained
under `figures_new/fishery-impact/inputs/controls/`; generated REP files are
omitted from this bundle.

Restore inputs without executing MFCL, from the repository root:

```sh
make restore CASE=reference OUT=/tmp/bet-fishery-impact-inputs
```

To regenerate all eight Figure 66 REP reports on 64-bit x86 Linux:

```sh
make rerun CASE=all OUT=/tmp/bet-fishery-impact
```

This downloads checksum-verified source files, evaluates each case once and
requires all eight native reports to match the original SHA-256 values.
Set `CASE=reference`, `longline`, `pole_line`, `ps`, `ps_associated`,
`ps_unassociated`, `miscellaneous` or `all_off` instead of `all` for one case.
Use a new output directory each time. `make verify` checks preserved files
and report values. Make, Python 3 and R are required.

The executable is the preserved public Diagnostic binary; matching outputs
establish compatibility, while the historical external executable hash remains
unknown. Full refits use the Diagnostic repository's original `./doitall`.

The published PDF, figures and calculations remain unchanged. See the
[Figure 66 methods](../figures_new/fishery-impact/README.md) to rebuild the
publication figure from its saved seasonal CSVs.

Use `make build OUT=/tmp/bet-report-build` to build the PDF from a fresh copy
of committed sources with the [pinned runtime](../docs/reproduction.md).
The build directory must be outside the checkout; published files stay in place.
