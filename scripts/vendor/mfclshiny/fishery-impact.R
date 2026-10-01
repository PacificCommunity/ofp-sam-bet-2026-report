#' Calculate contemporaneous spawning-biomass fishery impacts
#'
#' Uses fixed-parameter, separate fishery-removal simulations. All inputs must
#' describe the same fitted model and calendar. The reference no-fishing series
#' must remove ALL extraction fisheries; each group run removes just its named
#' group, retaining the other fisheries and the same recruitment convention.
#' Groups must partition the extraction fisheries. This function reads results;
#' it does not run MFCL or infer removal settings from biomass values.
#'
#' Annual depletion is mean(SB) / mean(SB_F=0), using matching seasons. Group
#' gains are mean(SB_without_group) - mean(SB). Their relative proportions
#' allocate 100 * (1 - depletion). Separate removal effects overlap, so their
#' unscaled sum is also returned. This allocation is a convention, not a unique
#' causal decomposition. It follows ISC (2013, Appendix F), Tommasi et al.
#' (2023, ISC/23/PBFWG-1/12) and Harley (2024, SCRS/2024/147).
#'
#' @param reference An MFCLRep, a matching native `.rep` path, or a data frame
#'   with `year`, `season`, `region`, `sb` and `sb_nofish`. In the reference,
#'   `sb_nofish` is biomass with all fishing removed. Multi-unit, multi-age or
#'   multi-iteration MFCLRep inputs must be explicitly subset before use.
#' @param group_runs A nonempty named list of inputs in the same format. In each
#'   run `sb` is the unchanged fitted biomass and `sb_nofish` is biomass with
#'   that group removed. Names become legend labels.
#' @param seasons_per_year Positive integer. Defaults to the reference's observed
#'   season count; supply the model's count to also detect a wholly missing season.
#' @param include_overall Append an All regions series calculated from spatial
#'   sums of biomass, not from averages of regional ratios.
#' @param tolerance Relative numerical tolerance for matching fitted biomass and
#'   roundoff. Substantively negative impacts or group gains are rejected.
#' @return A `mfcl_fishery_impact` list containing `totals`, `groups`, `checks`,
#'   `method` and `sources`. Values labelled `impact_percent` are contributions
#'   in percentage points of contemporaneous unfished spawning biomass.
#' @export
calculate_fishery_impact <- function(reference, group_runs,
                                    seasons_per_year = NULL,
                                    include_overall = TRUE, tolerance = 1e-8) {
  if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) || tolerance < 0) {
    stop("tolerance must be one finite nonnegative number.", call. = FALSE)
  }
  if (!is.logical(include_overall) || length(include_overall) != 1L || is.na(include_overall)) {
    stop("include_overall must be TRUE or FALSE.", call. = FALSE)
  }
  groups <- names(group_runs)
  if (!is.list(group_runs) || !length(group_runs) || is.null(groups) ||
      anyNA(groups) || any(!nzchar(trimws(groups))) || anyDuplicated(groups)) {
    stop("group_runs must be a nonempty list with unique, nonempty group names.", call. = FALSE)
  }
  ref <- mfclshiny_impact_frame(reference, "reference")
  if ("All regions" %in% ref$region) stop("Supply regional biomass only, without All regions rows.", call. = FALSE)
  seasons <- sort(unique(ref$season))
  if (is.null(seasons_per_year)) seasons_per_year <- length(seasons)
  if (length(seasons_per_year) != 1L || !is.numeric(seasons_per_year) ||
      !is.finite(seasons_per_year) || seasons_per_year < 1 || seasons_per_year != as.integer(seasons_per_year)) {
    stop("seasons_per_year must be a positive integer.", call. = FALSE)
  }
  regions <- unique(ref$region)
  years <- sort(unique(ref$year))
  expected_n <- length(years) * length(regions) * seasons_per_year
  if (length(seasons) != seasons_per_year || nrow(ref) != expected_n ||
      !identical(years, seq.int(min(years), max(years)))) {
    stop("Reference must have a complete year-season-region grid with consecutive years.", call. = FALSE)
  }
  keys <- c("year", "season", "region")
  annual <- function(x) {
    ans <- stats::aggregate(cbind(sb, sb_nofish) ~ year + region, x, mean)
    if (include_overall) {
      overall <- stats::aggregate(cbind(sb, sb_nofish) ~ year, ans, sum)
      overall$region <- "All regions"
      ans <- rbind(ans, overall[, names(ans)])
    }
    ans[order(match(ans$region, c(regions, "All regions")), ans$year), , drop = FALSE]
  }
  totals <- annual(ref)
  if (any(totals$sb_nofish <= 0)) stop("Reference unfished SB must be positive.", call. = FALSE)
  if (any(totals$sb > totals$sb_nofish + tolerance * pmax(1, totals$sb_nofish))) {
    stop("Fished SB exceeds unfished SB; nonnegative stacked attribution is not applicable.", call. = FALSE)
  }
  totals$depletion <- totals$sb / totals$sb_nofish
  totals$impact_percent <- pmax(0, 100 * (1 - totals$depletion))
  gains <- matrix(0, nrow(totals), length(group_runs), dimnames = list(NULL, groups))
  max_fitted_error <- numeric(length(group_runs))
  names(max_fitted_error) <- groups
  sources <- data.frame(group = c("reference", groups), path = c(
    mfclshiny_impact_source(reference), vapply(group_runs, mfclshiny_impact_source, character(1))
  ), stringsAsFactors = FALSE)
  for (i in seq_along(group_runs)) {
    one <- mfclshiny_impact_frame(group_runs[[i]], paste0("group ", groups[[i]]))
    # Both frames have canonical row ordering; no recycling or partial joins.
    if (!identical(ref[keys], one[keys])) {
      stop("Year-season-region grid differs for group: ", groups[[i]], call. = FALSE)
    }
    error <- abs(one$sb - ref$sb)
    max_fitted_error[[i]] <- max(error)
    if (any(error > tolerance * pmax(1, abs(ref$sb)))) {
      stop("Fitted SB differs from reference for group: ", groups[[i]], call. = FALSE)
    }
    if (any(one$sb_nofish < ref$sb - tolerance * pmax(1, abs(ref$sb)))) {
      stop("Negative removal gain for group: ", groups[[i]], "; check model settings.", call. = FALSE)
    }
    a <- annual(one)
    gains[, i] <- pmax(0, a$sb_nofish - totals$sb)
  }
  gain_sum <- rowSums(gains)
  if (any(gain_sum == 0 & totals$impact_percent > 100 * tolerance)) {
    stop("Positive total impact with zero group gains; removal runs are incomplete or inconsistent.", call. = FALSE)
  }
  weights <- gains / ifelse(gain_sum == 0, 1, gain_sum)
  allocated <- weights * totals$impact_percent
  totals$sum_group_gain <- gain_sum
  totals$raw_group_sum_percent <- 100 * gain_sum / totals$sb_nofish
  rows <- lapply(seq_along(groups), function(i) {
    data.frame(year = totals$year, region = totals$region, group = groups[[i]],
               sb_without_group = totals$sb + gains[, i], gain = gains[, i],
               share = weights[, i], raw_impact_percent = 100 * gains[, i] / totals$sb_nofish,
               impact_percent = allocated[, i], stringsAsFactors = FALSE)
  })
  structure(list(
    totals = totals, groups = do.call(rbind, rows),
    checks = list(reference_season_region_points = nrow(ref),
                  seasons_per_year = as.integer(seasons_per_year),
                  max_fitted_sb_error_by_group = max_fitted_error,
                  max_allocation_sum_error = max(abs(rowSums(allocated) - totals$impact_percent))),
    method = list(reference = "contemporaneous annual mean SB / annual mean all-fishing-removed SB",
                  allocation = "proportional annual group-removal biomass gains",
                  overall = "spatial biomass sums before ratios and allocation",
                  provenance = "Caller must verify identical parameters/recruitment settings and a complete, non-overlapping fishery partition."),
    sources = sources
  ), class = "mfcl_fishery_impact")
}

mfclshiny_impact_source <- function(x) {
  if (is.character(x) && length(x) == 1L) normalizePath(x, winslash = "/", mustWork = TRUE) else "in-memory"
}

mfclshiny_impact_frame <- function(x, label) {
  if (is.character(x) && length(x) == 1L) {
    if (!file.exists(x)) stop("Report file not found: ", x, call. = FALSE)
    x <- FLR4MFCL::read.MFCLRep(x)
  }
  if (methods::is(x, "MFCLRep")) {
    extract <- function(slot_name) {
      a <- methods::slot(x, slot_name)
      dims <- dim(a)
      if (length(dims) != 6L || any(dims[c(1, 3, 6)] != 1L)) {
        stop(label, ": subset age, unit and iteration dimensions to singletons first.", call. = FALSE)
      }
      # Do not rely on FLCore's attached as.data.frame generic: namespace-only
      # use otherwise dispatches to as.data.frame.array for this S4 object.
      # Singleton age/unit/iteration leave year varying fastest, then season,
      # then region in the underlying six-dimensional array.
      dn <- dimnames(a)
      coordinates <- expand.grid(year = dn[[2L]], season = dn[[4L]], region = dn[[5L]],
                                  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
      coordinates$year <- as.integer(coordinates$year)
      coordinates$value <- as.numeric(a)
      coordinates
    }
    b <- extract("adultBiomass")
    b0 <- extract("adultBiomass_nofish")
    if (!identical(b[c("year", "season", "region")], b0[c("year", "season", "region")])) {
      stop(label, ": fished and counterfactual SB coordinates differ.", call. = FALSE)
    }
    x <- b[c("year", "season", "region")]
    x$sb <- b$value
    x$sb_nofish <- b0$value
  }
  required <- c("year", "season", "region", "sb", "sb_nofish")
  if (!is.data.frame(x) || !nrow(x) || !all(required %in% names(x))) {
    stop(label, " must contain year, season, region, sb and sb_nofish.", call. = FALSE)
  }
  x <- x[required]
  if (!is.numeric(x$year) || any(!is.finite(x$year)) || any(x$year != as.integer(x$year))) {
    stop(label, ": years must be finite integers.", call. = FALSE)
  }
  x$year <- as.integer(x$year)
  x$season <- as.character(x$season)
  x$region <- as.character(x$region)
  if (anyNA(x) || any(!nzchar(trimws(x$season))) || any(!nzchar(trimws(x$region))) ||
      !is.numeric(x$sb) || !is.numeric(x$sb_nofish) ||
      any(!is.finite(x$sb)) || any(!is.finite(x$sb_nofish)) || any(x$sb < 0 | x$sb_nofish < 0)) {
    stop(label, ": missing, nonfinite or negative biomass/coordinates are not allowed.", call. = FALSE)
  }
  if (anyDuplicated(x[c("year", "season", "region")])) {
    stop(label, ": duplicate year-season-region rows.", call. = FALSE)
  }
  # Numeric region identifiers retain natural order even for 10+ regions.
  region_order <- if (all(grepl("^[0-9]+$", x$region))) as.numeric(x$region) else x$region
  x <- x[order(region_order, x$region, x$year, x$season), ]
  rownames(x) <- NULL
  x
}

#' Read named fishery-removal runs from a manifest
#' @param reference Reference input accepted by [calculate_fishery_impact()].
#' @param manifest CSV path containing unique `group` and `rep_file` columns.
#'   Relative report paths are resolved against the manifest directory.
#' @param ... Arguments passed to [calculate_fishery_impact()].
#' @return A `mfcl_fishery_impact` result, including the resolved manifest.
#' @export
read_fishery_impact <- function(reference, manifest, ...) {
  manifest <- normalizePath(manifest, winslash = "/", mustWork = TRUE)
  m <- utils::read.csv(manifest, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(m) || !all(c("group", "rep_file") %in% names(m)) ||
      anyNA(m[c("group", "rep_file")]) || any(!nzchar(trimws(m$group))) ||
      any(!nzchar(trimws(m$rep_file))) || anyDuplicated(m$group)) {
    stop("Manifest needs unique nonempty group names and rep_file paths.", call. = FALSE)
  }
  paths <- path.expand(m$rep_file)
  relative <- !grepl("^(/|[A-Za-z]:[/\\\\]|\\\\\\\\)", paths)
  paths[relative] <- file.path(dirname(manifest), paths[relative])
  paths <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  if (anyDuplicated(paths)) stop("Each group must have a separate report file.", call. = FALSE)
  result <- calculate_fishery_impact(reference, stats::setNames(as.list(paths), m$group), ...)
  m$rep_file <- paths
  result$manifest <- m
  result
}

#' Plot regional fishery impacts for any model configuration
#' @param x A result from [calculate_fishery_impact()].
#' @param ncol Facet columns, or NULL for an automatic layout.
#' @param colours Optional named vector with one colour per group. By default
#'   a qualitative palette is generated for the observed number of groups.
#' @param base_size Base text size.
#' @param base_family Font family, default sans.
#' @param region_labels Optional character vector named by every region in
#'   x$totals (including All regions when present), with unique display labels.
#' @param theme Optional ggplot2 theme added to the neutral default theme.
#'   Pass report-specific styling here rather than changing the calculation.
#' @param total_colour Colour of the line showing total impact.
#' @param legend_ncol Legend columns, or NULL to choose from the group count.
#' @return A ggplot with no title, subtitle, comparison curve or author label.
#' @export
plot_fishery_impact <- function(x, ncol = NULL, colours = NULL,
                                base_size = 12, base_family = "sans",
                                region_labels = NULL, theme = NULL,
                                total_colour = "black", legend_ncol = NULL) {
  if (!inherits(x, "mfcl_fishery_impact")) stop("x must be a mfcl_fishery_impact result.", call. = FALSE)
  valid_columns <- function(value) {
    is.null(value) || (is.numeric(value) && length(value) == 1L &&
      is.finite(value) && value >= 1 && value == as.integer(value))
  }
  if (!valid_columns(ncol) || !valid_columns(legend_ncol)) {
    stop("ncol and legend_ncol must be NULL or positive integers.", call. = FALSE)
  }
  if (!is.null(theme) && !inherits(theme, "theme")) {
    stop("theme must be a ggplot2 theme or NULL.", call. = FALSE)
  }
  groups <- unique(x$groups$group)
  regions <- unique(x$totals$region)
  data <- x$groups
  totals <- x$totals
  data$group <- factor(data$group, levels = groups)
  labels <- ifelse(grepl("^[0-9]+$", regions), paste("Region", regions), regions)
  if (!is.null(region_labels)) {
    if (!is.character(region_labels) || is.null(names(region_labels)) ||
        anyDuplicated(names(region_labels)) || !all(regions %in% names(region_labels)) ||
        anyNA(region_labels[regions]) || any(!nzchar(trimws(region_labels[regions]))) ||
        anyDuplicated(region_labels[regions])) {
      stop("region_labels must provide a unique, nonempty label for every region.", call. = FALSE)
    }
    labels <- unname(region_labels[regions])
  }
  data$region <- factor(data$region, levels = regions, labels = labels)
  totals$region <- factor(totals$region, levels = regions, labels = labels)
  if (is.null(colours)) {
    colours <- stats::setNames(grDevices::hcl.colors(length(groups), "Dark 3"), groups)
  }
  if (anyDuplicated(names(colours)) || !all(groups %in% names(colours)) || anyNA(colours[groups])) {
    stop("colours must be named for every group.", call. = FALSE)
  }
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$year, y = .data$impact_percent, fill = .data$group))
  if (length(unique(totals$year)) == 1L) {
    p <- p + ggplot2::geom_col(position = ggplot2::position_stack(reverse = TRUE), width = 0.65) +
      ggplot2::scale_x_continuous(breaks = unique(totals$year))
  } else {
    # stat_align pads the final year with an artificial zero just beyond it.
    # The calendar is already complete/aligned, so retain the actual endpoints.
    first <- min(totals$year)
    last <- max(totals$year)
    left <- floor(first / 10) * 10
    breaks <- if (last - first >= 20) seq(left, last, by = 20) else pretty(c(first, last), n = 4)
    breaks <- breaks[breaks >= left & breaks <= last & last - breaks > 0.08 * (last - left)]
    p <- p + ggplot2::geom_area(stat = "identity", position = ggplot2::position_stack(reverse = TRUE)) +
      ggplot2::geom_line(data = totals, ggplot2::aes(x = .data$year, y = .data$impact_percent),
                         inherit.aes = FALSE, colour = total_colour, linewidth = 0.55) +
      ggplot2::scale_x_continuous(limits = c(left, last), breaks = c(breaks, last),
                                 expand = ggplot2::expansion(mult = 0))
  }
  if (is.null(legend_ncol)) legend_ncol <- ceiling(sqrt(length(groups)))
  p +
    ggplot2::facet_wrap(~region, ncol = ncol) +
    ggplot2::scale_fill_manual(values = colours, breaks = groups) +
    ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                               expand = ggplot2::expansion(mult = 0)) +
    ggplot2::labs(x = "Year", y = "Fishery impact (%)", fill = NULL) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = ceiling(length(groups) / legend_ncol), byrow = TRUE)) +
    ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(), legend.position = "bottom") +
    theme
}

mfclshiny_impact_caption <- function() {
  paste("Regional and overall fishing impacts from fixed-parameter removal simulations.",
        "Total impact is 100(1 - SB_y/SB_y,F=0), using contemporaneous annual mean spawning biomass.",
        "Group contributions allocate that total in proportion to annual biomass increases when each group is removed separately.",
        "Overall ratios use spatial biomass sums. Recruitment settings must be consistent across simulations.",
        "The allocation follows ISC (2013, 2023) and Harley (2024); it is not a unique causal decomposition.")
}

#' Export a fishery-impact figure and its calculation tables
#' @param x A result from [calculate_fishery_impact()].
#' @param output_dir Directory for figures, tables, result RDS and gallery index.
#'   Use a dedicated directory: its `figure-index.csv` is written by this function.
#' @param width,height Figure dimensions in inches.
#' @param dpi PNG resolution.
#' @param ... Arguments passed to [plot_fishery_impact()].
#' @return Invisibly, a list containing output_dir, plot and index.
#' @export
build_fishery_impact_report <- function(x, output_dir, width = 11.5, height = 7.5, dpi = 300, ...) {
  p <- plot_fishery_impact(x, ...)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  stem <- "fishery-impact"
  png_device <- if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else grDevices::png
  ggplot2::ggsave(file.path(output_dir, paste0(stem, ".png")), p, width = width, height = height,
                  dpi = dpi, bg = "white", device = png_device)
  ggplot2::ggsave(file.path(output_dir, paste0(stem, ".pdf")), p, width = width, height = height,
                  bg = "white", device = grDevices::pdf, useDingbats = FALSE)
  utils::write.csv(x$totals, file.path(output_dir, "fishery-impact-totals.csv"), row.names = FALSE)
  utils::write.csv(x$groups, file.path(output_dir, "fishery-impact-groups.csv"), row.names = FALSE)
  utils::write.csv(x$sources, file.path(output_dir, "fishery-impact-sources.csv"), row.names = FALSE)
  saveRDS(x, file.path(output_dir, "fishery-impact.rds"))
  caption <- mfclshiny_impact_caption()
  writeLines(c(caption, "", unlist(x$method)), file.path(output_dir, "fishery-impact-method.txt"))
  index <- data.frame(figure = stem, label = "Fishery impact", format = c("png", "pdf"),
                       relative_path = paste0(stem, c(".png", ".pdf")), caption = caption)
  utils::write.csv(index, file.path(output_dir, "figure-index.csv"), row.names = FALSE)
  invisible(list(output_dir = output_dir, plot = p, index = index))
}
