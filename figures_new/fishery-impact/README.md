# Figure 66, Revision 2

Recalculated from BET 2026 diagnostic Job 21641, using its fitted spawning
biomass and matching native all-fishing-off and six group-removal outputs.
The model parameters and stock-recruitment correction (age flag 171 = 1)
were retained. All group runs reproduce the reference fitted biomass at all
1,460 season-region coordinates. Extraction fisheries 1-28 are partitioned
between the groups; index fisheries 29-33 do not contribute removals.

The annual total is `100 * (1 - mean(SB) / mean(SB_F=0))`, with matching
seasons. The same-year unfished biomass is used, rather than the multi-year
denominator of the recent management depletion statistic. Group shares are
proportional to the spawning-biomass gains from removing each group separately.
Regional biomasses are summed before computing the overall ratios and shares.
The separate removal effects overlap; the allocation is a stated convention,
not a unique causal decomposition. It follows the proportional allocation
described in ISC (2013, Appendix F), Tommasi et al. (2023,
ISC/23/PBFWG-1/12), and Harley (2024, SCRS/2024/147).

The original Figure 66 generating code was unavailable; its exact coding error
has not been established. These files document the replacement calculation.

## Validation and reproduction

- An independent R/FLR4MFCL reading and calculation matches all 438 Figure 29
  depletion points within `4.996e-16` and all 2,628 previously calculated
  group/year/region allocations within `8.882e-16` percentage points.
- Terminal impacts are 70.83064%, 93.31058%, 83.74622%, 88.03544%, and
  72.50455% for Regions 1-5, and 83.83296% overall.
- `fishery-impact.rds` retains the calculation tables, checks and method.
  The CSV files make the annual totals and allocation independently inspectable.
- The figure uses `mfclshiny` commit
  `6df3d40a1621ec3e6cac4646ed77df98cfc32579`. The area plot retains the actual
  terminal observations, without automatic zero padding after 2024.

## Rebuild from a clean checkout

The report embeds `fishery-impact.png`: RGB, 3450 x 2250 pixels, 300 dpi,
white background and serif text. This follows the PNG format and 300 dpi
resolution of Figure 29. There is no overall title, subtitle or comparison
curve. The original report caption and Figure 66 cross-reference are retained.
The companion PDF is an optional vector export, not the embedded report asset.

Run this from the repository root with Docker and access to the report's
existing GHCR container. Its digest pins R, packages, fonts and rendering tools:

```sh
docker run --rm --platform linux/amd64 --network none \
  -v "$PWD:/work" -w /work --entrypoint Rscript \
  ghcr.io/pacificcommunity/tuna-flow-private:v2.7@sha256:4fee4c40cb6439ff920b1dd233a84bf19d5cc0e37278c99ceff3fd79cb9c8852 \
  scripts/build-fishery-impact.R .
```

Append `--check` to recalculate into a temporary directory and compare the
annual CSV tables and exact PNG SHA-256 with the committed publication assets.
The report's GitHub workflow runs this check before compiling and verifying
the full PDF. A differing calculation or PNG fails the build.

No local model directories, existing result RDS, installed development package
or access to the mfclshiny repository are needed. The checked-in function copy
is byte-identical to the upstream commit identified above; its original
copyright and license are included under `scripts/vendor/mfclshiny/`.
With equivalent local packages, `Rscript scripts/build-fishery-impact.R .`
also works, but another operating system's fonts can change PNG pixels.

The reusable mfclshiny functions infer model years, regions, groups and seasons
from their inputs. BET-specific fishery IDs and numerical reference checks are
confined to this report's build script and archived input files. The palette,
serif font, panel layout and other report styling are supplied separately by
`scripts/fishery-impact-style.R`. The generic plotting function supports an
automatic layout, any number of groups, custom region labels and caller-supplied
colours and ggplot2 themes. This separation reproduces the published BET PNG
without making other assessments inherit the BET appearance or configuration.

## Inputs and checks

`inputs/reference.csv` stores `year,season,region,sb,sb_nofish` extracted
using FLR4MFCL 1.7.2 from the native diagnostic report. Its 1,460 rows span
1952-2024, four quarters and five regions. `all_off.csv` independently stores
the matching all-fishing-off run and must agree exactly. The six named group
CSVs have the same schema; their `sb_nofish` is the counterfactual spawning
biomass when only that group (plus inactive index fisheries) is removed.

The calculation starts from these seasonal model outputs, not from the annual
impact CSVs or RDS. `groups.json` and `controls/` archive the fishery partition
and native run settings. `provenance.json` identifies the source reports by
SHA-256 and records the fitted parameter checksum. `checksums.csv` protects
the archived inputs and pinned function source against accidental changes.

Every rebuild checks all 438 diagnostic depletion points against the separate
Figure 29 source extract, unchanged fitted biomass across removal runs, the
complete fishery partition and quarterly calendar, additive allocated impacts,
and the true nonzero 2024 endpoint of the plotted areas.

This reproduces the calculation and figure **from archived native model
outputs**; it does not refit the assessment or rerun the native MFCL simulations.
Custodians of the original run directory can repeat the extraction with
`scripts/extract-fishery-impact-inputs.R`; the script checks each native report
against its recorded SHA-256 before reading it. The original extraction runtime
was `ghcr.io/pacificcommunity/bet-2026:v1.9` at digest
`sha256:798eb25f8e5e9d97b53c5a682f9597bd74e7e42ec2e02a65ec1e066db5c08386`.
For other assessments, use the upstream `mfclshiny::read_fishery_impact()` with
the reference report and a `group,rep_file` manifest of completed removal runs.
