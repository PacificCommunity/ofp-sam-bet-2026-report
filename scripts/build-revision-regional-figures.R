#!/usr/bin/env Rscript

# Build the Revision 1 regional time-series and length-frequency figures from
# the checked-in BET 2026 diagnostic-model payload.  The script deliberately
# writes new filenames in figures_new/ so that earlier report graphics remain
# available for comparison.

options(stringsAsFactors = FALSE, scipen = 8)

args <- commandArgs(trailingOnly = TRUE)
report_root <- if (length(args) >= 1L) {
  normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}
diagnostic_root <- if (length(args) >= 2L) {
  normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
} else {
  stop("Supply the BET 2026 diagnostic repository as the second argument.", call. = FALSE)
}
mfclshiny_root <- if (length(args) >= 3L) {
  normalizePath(args[[3L]], winslash = "/", mustWork = TRUE)
} else {
  stop("Supply the mfclshiny source repository as the third argument.", call. = FALSE)
}

required_packages <- c("ggplot2", "dplyr", "scales", "ragg", "mfclshiny")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1L), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing required package(s): ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

output_dir <- file.path(report_root, "figures_new")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
model_payload <- file.path(diagnostic_root, "results", "reference", "model_payload.rds")
fishery_map_file <- file.path(diagnostic_root, "model", "fishery_map.R")
predictive_helpers <- file.path(
  mfclshiny_root, "inst", "app", "R", "modules", "lf_predictive_helpers.R"
)
stopifnot(file.exists(model_payload), file.exists(fishery_map_file), file.exists(predictive_helpers))

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})
source(predictive_helpers, local = environment())
fishery_env <- new.env(parent = baseenv())
sys.source(fishery_map_file, envir = fishery_env)
fishery_map <- get("fishery_map", envir = fishery_env, inherits = FALSE)

staging_dir <- tempfile("bet-2026-revision-figures-")
dir.create(staging_dir)
on.exit(unlink(staging_dir, recursive = TRUE, force = TRUE), add = TRUE)
mfclshiny::restore_model_payload_files(
  model_payload, output_dir = staging_dir, overwrite = TRUE
)
file.copy(model_payload, file.path(staging_dir, "model_payload.rds"), overwrite = TRUE)
payload <- get("mfclshiny_diagnostic_payload", asNamespace("mfclshiny"))(
  staging_dir, roles = c("ParOut", "RepOut", "LengOut")
)
par_out <- payload$data$ParOut
rep_out <- payload$data$RepOut
leng_out <- payload$data$LengOut
if (is.null(par_out) || is.null(rep_out) || is.null(leng_out)) {
  stop("The diagnostic payload is missing ParOut, RepOut or LengOut.", call. = FALSE)
}

navy <- "#0B5267"
teal <- "#168A98"
purple <- "#4F2C7F"
observed_fill <- "#2C6E63"
observed_border <- "#173F39"
area_levels <- c(paste("Region", 1:5), "All regions")

theme_report <- function(base_size = 11) {
  theme_bw(base_size = base_size, base_family = "serif") +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#DCE5E8", linewidth = 0.36),
      strip.background = element_rect(fill = "#E7EEF1", colour = "#526B78"),
      strip.text = element_text(face = "bold", size = base_size),
      axis.text = element_text(colour = "#314B5B"),
      legend.position = "bottom",
      legend.title = element_blank(),
      panel.spacing = grid::unit(0.65, "lines"),
      plot.margin = margin(6, 8, 6, 6)
    )
}

save_plot <- function(plot, filename, width = 10.8, height = 12.0, dpi = 400) {
  ggplot2::ggsave(
    file.path(output_dir, filename), plot,
    width = width, height = height, units = "in", dpi = dpi,
    device = ragg::agg_png, bg = "white", limitsize = FALSE
  )
}

flatten_flquant <- function(x, value_name = "data") {
  value <- as.array(x)
  grid <- expand.grid(dimnames(value), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  names(grid) <- names(dimnames(value))
  grid[[value_name]] <- as.numeric(value)
  grid
}

# Recruitment: two columns and three panel rows avoid the visually compressed
# slopes produced by the earlier 3-by-2 arrangement.  Each panel still starts
# at zero and uses its own vertical scale, as indicated in the report caption.
rec <- flatten_flquant(rep_out@rec_region)
rec$year <- suppressWarnings(as.integer(rec$year))
rec$area <- suppressWarnings(as.integer(rec$area))
rec_regional <- rec |>
  group_by(year, area) |>
  summarise(recruitment = sum(data, na.rm = TRUE) / 1e6, .groups = "drop") |>
  mutate(area_label = paste("Region", area))
rec_total <- rec |>
  group_by(year) |>
  summarise(recruitment = sum(data, na.rm = TRUE) / 1e6, .groups = "drop") |>
  mutate(area_label = "All regions")
rec_plot_data <- bind_rows(
  select(rec_regional, year, recruitment, area_label),
  select(rec_total, year, recruitment, area_label)
) |>
  mutate(area_label = factor(area_label, levels = area_levels))

p_recruitment <- ggplot(rec_plot_data, aes(year, recruitment)) +
  geom_line(colour = navy, linewidth = 0.9, lineend = "round") +
  coord_cartesian(ylim = c(0, NA)) +
  facet_wrap(~area_label, ncol = 2, scales = "free_y") +
  labs(x = "Year", y = "Recruitment (millions of fish)") +
  theme_report(11.2)
save_plot(p_recruitment, "recruitment-by-area-2col.png", height = 12.2)

# Fished and dynamic no-fishing total biomass.  Colour and linetype both
# distinguish the two trajectories, while the taller two-column layout keeps
# long-term changes from appearing artificially steep.
biomass_series <- function(x, status) {
  z <- flatten_flquant(x)
  z$year <- suppressWarnings(as.integer(z$year))
  z$season <- suppressWarnings(as.integer(z$season))
  z$area <- suppressWarnings(as.integer(z$area))
  regional <- z |>
    group_by(year, area) |>
    summarise(biomass = mean(data, na.rm = TRUE) / 1e3, .groups = "drop") |>
    mutate(area_label = paste("Region", area), status = status)
  total <- z |>
    group_by(year, season) |>
    summarise(biomass = sum(data, na.rm = TRUE), .groups = "drop") |>
    group_by(year) |>
    summarise(biomass = mean(biomass, na.rm = TRUE) / 1e3, .groups = "drop") |>
    mutate(area_label = "All regions", status = status)
  bind_rows(
    select(regional, year, biomass, area_label, status),
    select(total, year, biomass, area_label, status)
  )
}
biomass_plot_data <- bind_rows(
  biomass_series(rep_out@totalBiomass, "Fished"),
  biomass_series(rep_out@totalBiomass_nofish, "No fishing")
) |>
  mutate(
    area_label = factor(area_label, levels = area_levels),
    status = factor(status, levels = c("Fished", "No fishing"))
  )

p_biomass <- ggplot(
  biomass_plot_data,
  aes(year, biomass, colour = status, linetype = status)
) +
  geom_line(linewidth = 0.92, alpha = 0.94, lineend = "round") +
  scale_colour_manual(values = c("Fished" = navy, "No fishing" = teal)) +
  scale_linetype_manual(values = c("Fished" = "solid", "No fishing" = "22")) +
  coord_cartesian(ylim = c(0, NA)) +
  facet_wrap(~area_label, ncol = 2, scales = "free_y") +
  labs(x = "Year", y = "Total biomass (thousand metric tonnes)") +
  theme_report(11.2) +
  guides(
    colour = guide_legend(override.aes = list(linewidth = 1.4)),
    linetype = "none"
  )
save_plot(p_biomass, "total-biomass-with-without-fishing-2col.png", height = 12.2)

# Annual juvenile and adult fishing mortality.  The life stages use different
# colours as well as linetypes so they remain distinguishable over the shaded
# report background and in colour-vision-deficient viewing.
fm <- flatten_flquant(rep_out@fm)
popn <- flatten_flquant(rep_out@popN)
for (field in c("age", "year", "season", "area")) {
  fm[[field]] <- suppressWarnings(as.integer(fm[[field]]))
  popn[[field]] <- suppressWarnings(as.integer(popn[[field]]))
}
names(fm)[names(fm) == "data"] <- "fishing_mortality"
names(popn)[names(popn) == "data"] <- "population"
maturity <- flatten_flquant(par_out@mat)
maturity <- maturity[order(
  suppressWarnings(as.numeric(maturity$age)),
  suppressWarnings(as.numeric(as.character(maturity$season)))
), , drop = FALSE]
maturity$age_index <- seq_len(nrow(maturity))
maturity <- maturity[, c("age_index", "data"), drop = FALSE]
names(maturity)[names(maturity) == "data"] <- "maturity"
f_components <- inner_join(
  fm, popn, by = c("age", "year", "unit", "season", "area", "iter")
) |>
  mutate(age_index = suppressWarnings(as.integer(age))) |>
  left_join(maturity, by = "age_index") |>
  mutate(
    juvenile = (1 - maturity) * population,
    adult = maturity * population,
    juvenile_catch = fishing_mortality * juvenile,
    adult_catch = fishing_mortality * adult
  )
if (any(!is.finite(f_components$maturity))) {
  stop("Maturity values do not align with fishing-mortality age classes.", call. = FALSE)
}
annual_f <- function(data, by_area = TRUE) {
  groups <- if (by_area) c("year", "season", "area") else c("year", "season")
  seasonal <- data |>
    group_by(across(all_of(groups))) |>
    summarise(
      juvenile_catch = sum(juvenile_catch, na.rm = TRUE),
      juvenile = sum(juvenile, na.rm = TRUE),
      adult_catch = sum(adult_catch, na.rm = TRUE),
      adult = sum(adult, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      juvenile_f = -log(pmax(1 - juvenile_catch / juvenile, 0.001)),
      adult_f = -log(pmax(1 - adult_catch / adult, 0.001))
    )
  if (by_area) {
    seasonal |>
      group_by(year, area) |>
      summarise(
        juvenile_f = sum(juvenile_f, na.rm = TRUE),
        adult_f = sum(adult_f, na.rm = TRUE),
        .groups = "drop"
      ) |>
      mutate(area_label = paste("Region", area))
  } else {
    seasonal |>
      group_by(year) |>
      summarise(
        juvenile_f = sum(juvenile_f, na.rm = TRUE),
        adult_f = sum(adult_f, na.rm = TRUE),
        .groups = "drop"
      ) |>
      mutate(area_label = "All regions")
  }
}
f_wide <- bind_rows(annual_f(f_components, TRUE), annual_f(f_components, FALSE))
f_plot_data <- bind_rows(
  transmute(
    f_wide, year, area_label, life_stage = "Juvenile F",
    fishing_mortality = juvenile_f
  ),
  transmute(
    f_wide, year, area_label, life_stage = "Adult F",
    fishing_mortality = adult_f
  )
) |>
  mutate(
    area_label = factor(area_label, levels = area_levels),
    life_stage = factor(life_stage, levels = c("Juvenile F", "Adult F"))
  )

p_fishing_mortality <- ggplot(
  f_plot_data,
  aes(year, fishing_mortality, colour = life_stage, linetype = life_stage)
) +
  geom_line(linewidth = 0.92, alpha = 0.95, lineend = "round") +
  scale_colour_manual(values = c("Juvenile F" = "#D67514", "Adult F" = navy)) +
  scale_linetype_manual(values = c("Juvenile F" = "22", "Adult F" = "solid")) +
  coord_cartesian(ylim = c(0, NA)) +
  facet_wrap(~area_label, ncol = 2, scales = "free_y") +
  labs(x = "Year", y = "Annual instantaneous fishing mortality") +
  theme_report(11.2) +
  guides(
    colour = guide_legend(override.aes = list(linewidth = 1.4)),
    linetype = "none"
  )
save_plot(p_fishing_mortality, "f-juvenile-adult-by-area-2col.png", height = 12.2)

# Static LF fit: aggregate the individual incident counts to model region, but
# retain the fitted observation model's pointwise predictive interval and the
# summed model-implied incident ESS.  Fishery-level panels remain available in
# the interactive diagnostic viewer.
incidents <- lf_prepare_predictive_incidents(
  leng_out@lenfits, par_obj = par_out, scenario = "Diagnostic"
) |>
  left_join(select(fishery_map, fishery, region), by = "fishery") |>
  filter(is.finite(region)) |>
  mutate(region_label = paste("Region", as.integer(region)))

regional_counts <- incidents |>
  group_by(region_label, length) |>
  summarise(
    observed = sum(obs_count, na.rm = TRUE),
    fitted = sum(pred_count, na.rm = TRUE),
    .groups = "drop"
  )
all_counts <- incidents |>
  group_by(length) |>
  summarise(
    observed = sum(obs_count, na.rm = TRUE),
    fitted = sum(pred_count, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(region_label = "All regions")
lf_counts <- bind_rows(regional_counts, all_counts)

regional_bands <- lf_predictive_pointwise_band(
  incidents, group_cols = "region_label", level = 95, nsim = 500L
)
all_incidents <- incidents |>
  mutate(region_label = "All regions")
all_bands <- lf_predictive_pointwise_band(
  all_incidents, group_cols = "region_label", level = 95, nsim = 500L
)
lf_bands <- bind_rows(regional_bands, all_bands)
lf_ess <- bind_rows(
  lf_predictive_ess_labels(incidents, panel_cols = "region_label"),
  lf_predictive_ess_labels(all_incidents, panel_cols = "region_label")
)
for (object_name in c("lf_counts", "lf_bands", "lf_ess")) {
  object <- get(object_name)
  object$region_label <- factor(object$region_label, levels = area_levels)
  assign(object_name, object)
}
length_values <- sort(unique(lf_counts$length))
bar_width <- if (length(length_values) > 1L) {
  min(diff(length_values)[diff(length_values) > 0]) * 0.96
} else {
  1.8
}

p_lf <- ggplot(lf_counts, aes(length)) +
  geom_ribbon(
    data = lf_bands,
    aes(x = length, ymin = band_low, ymax = band_high),
    inherit.aes = FALSE,
    fill = purple, alpha = 0.22
  ) +
  geom_col(
    aes(y = observed), width = bar_width,
    fill = observed_fill, colour = observed_border, linewidth = 0.12
  ) +
  geom_line(aes(y = fitted), colour = purple, linewidth = 0.95, lineend = "round") +
  geom_label(
    data = lf_ess,
    aes(x = Inf, y = Inf, label = ess_label),
    inherit.aes = FALSE, hjust = 1.04, vjust = 1.18,
    size = 3.1, linewidth = 0.22, fill = "white", colour = "#4B5563"
  ) +
  facet_wrap(~region_label, ncol = 2, scales = "free_y") +
  scale_x_continuous(expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(
    labels = scales::label_number(big.mark = ","),
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(x = "Length (cm)", y = "Sample count") +
  theme_report(11.2) +
  theme(legend.position = "none")
save_plot(p_lf, "length-frequency-fit-by-region.png", height = 12.2)

message("Wrote Revision 1 regional figures to ", output_dir)
