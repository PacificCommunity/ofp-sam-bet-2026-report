# Separate current stock status figures

`kobe-status.png` and `majuro-status.png` are separate exports of the two panels in `figures/combined_kobe_majuro_status.png`. Each includes the full HDR and Hessian legend. They use the same retained models, Hessian mixture, category probabilities and plotting functions as the combined report figure; the individual layout is adapted for a two-row legend.

Generated from the [ensemble repository at fb715b2](https://github.com/PacificCommunity/ofp-sam-bet-2026-ensemble/tree/fb715b2) using `Rscript extra/export-separate-status.R`, with 300 dpi PNG output. See its `extra/README.md` for dependencies and reproduction details. The existing report and combined figure are unchanged.

The four `dynamic-*.png` files separately export panels (a)–(d) of `figures/time-dynamic-kobe-majuro.png`: Majuro diagnostic, Majuro 80-model median, Kobe diagnostic, and Kobe 80-model median, respectively. Each retains the original time series and common plot limits, and has its own year legend. Generated from the [ensemble repository at bd55352](https://github.com/PacificCommunity/ofp-sam-bet-2026-ensemble/tree/bd55352) using `Rscript extra/export-separate-dynamic-status.R`.

## High-resolution exports

The `highres/` directory contains six separate plots, each as a vector PDF and a 600 dpi PNG. Current-status PNGs are 3240 × 3120 pixels; dynamic PNGs are 3240 × 3000 pixels. The current-status legend labels the Hessian classifications as `PDH` and `Near-PDH`. Generated using the [ensemble export scripts at 16e25ad](https://github.com/PacificCommunity/ofp-sam-bet-2026-ensemble/tree/16e25ad/extra). The main report and original combined figures are unchanged.
