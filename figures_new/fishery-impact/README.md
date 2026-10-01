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
  `9d8eab27696b6f72dabb25dfe2fc68fc296294ee`. The area plot retains the actual
  terminal observations, without automatic zero padding after 2024.
- Run `Rscript scripts/build-fishery-impact.R .` from the repository root to
  regenerate the figure with that package version. For recalculation from raw
  native reports, use `mfclshiny::read_fishery_impact()` with the reference and
  a `group,rep_file` manifest of completed removal runs.

The publication figure has no overall title, subtitle or comparison curve.
Its original report caption and Figure 66 cross-reference are retained.
