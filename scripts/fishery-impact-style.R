# BET 2026 report styling. Model-independent calculation and plotting live in
# mfclshiny; this report supplies its own palette, typography and layout.
bet_fishery_impact_style <- function() {
  list(
    ncol = 3, legend_ncol = 3, base_size = 12, base_family = "serif",
    total_colour = "#172B3A",
    colours = c("Longline" = "#164C63", "Pole-and-line" = "#B692AF",
                 "PS (unspecified)" = "#2C7F91", "PS-associated" = "#78B8C6",
                 "PS-unassociated" = "#B6DCE2", "Miscellaneous" = "#D9C39A"),
    theme = ggplot2::theme_bw(base_size = 12, base_family = "serif") +
      ggplot2::theme(
        panel.grid.minor = ggplot2::element_blank(),
        panel.grid.major = ggplot2::element_line(colour = "#E2E8EC", linewidth = 0.28),
        panel.border = ggplot2::element_rect(colour = "#263238", fill = NA, linewidth = 0.45),
        strip.background = ggplot2::element_rect(fill = "#E8F1F4", colour = "#B7C9D0", linewidth = 0.4),
        strip.text = ggplot2::element_text(size = 14, face = "bold", colour = "#172B3A"),
        axis.title = ggplot2::element_text(size = 16, face = "bold", colour = "#172B3A"),
        axis.text = ggplot2::element_text(size = 14, colour = "#172B3A"),
        axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 8)),
        axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 8)),
        axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 4)),
        axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 4)),
        legend.text = ggplot2::element_text(size = 13),
        panel.spacing.x = grid::unit(2.3, "lines"),
        legend.position = "bottom", legend.key.width = grid::unit(0.95, "cm"),
        plot.margin = ggplot2::margin(8, 16, 5, 8))
  )
}
