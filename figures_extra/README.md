# Separate current stock status figures

`kobe-status.png` and `majuro-status.png` are separate exports of the two panels in `figures/combined_kobe_majuro_status.png`. Each includes the full HDR and Hessian legend. They use the same retained models, Hessian mixture, category probabilities and plotting functions as the combined report figure; the individual layout is adapted for a two-row legend.

Generated from the [ensemble repository at fb715b2](https://github.com/PacificCommunity/ofp-sam-bet-2026-ensemble/tree/fb715b2) using `Rscript extra/export-separate-status.R`, with 300 dpi PNG output. See its `extra/README.md` for dependencies and reproduction details. The existing report and combined figure are unchanged.
