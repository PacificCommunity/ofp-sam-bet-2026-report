# Figure 66 native outputs

The fitted PAR, six MFCL inputs and executable reuse the public Diagnostic
repository at pinned commits. The seven removal controls are already retained
under `figures_new/fishery-impact/inputs/controls/`; generated REP files are
omitted from this bundle.

On 64-bit x86 Linux, from the report repository root:

```sh
python3 reproduce/run-native.py all /tmp/bet-fishery-impact
```

This downloads checksum-verified source files, evaluates each case once and
requires all eight native reports to match the original SHA-256 values.
Choose `reference`, `longline`, `pole_line`, `ps`, `ps_associated`,
`ps_unassociated`, `miscellaneous` or `all_off` instead of `all` for one case.
Use a new output directory each time.

The executable is the preserved public Diagnostic binary; matching outputs
establish compatibility, while the historical external executable hash remains
unknown. Full refits use the Diagnostic repository's original `./doitall`.

The published PDF, figures and calculations remain unchanged. See the
[Figure 66 methods](../figures_new/fishery-impact/README.md) to rebuild the
publication figure from its saved seasonal CSVs.
