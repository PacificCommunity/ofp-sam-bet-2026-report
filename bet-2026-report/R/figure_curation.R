`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

source("R/report_helpers.R")
source("R/config.R")
source("R/catalog.R")
load_report_context("report-config.yml")

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) tolower(args[[1]]) else "review"
if (!mode %in% c("review", "build")) {
  stop("Unknown curation mode: ", mode, call. = FALSE)
}

curation_dir <- file.path("curation")
dir.create(curation_dir, recursive = TRUE, showWarnings = FALSE)

relative_from_report <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", root), "/?"), "", path)
}

html_src_from_curation <- function(path) {
  if (!nzchar(path) || !file.exists(path)) return("")
  paste0("../", markdown_path(relative_from_report(path)))
}

review_preview_file <- function(file) {
  stem <- sub("[.][^.]+$", "", file)
  for (candidate in c(paste0(stem, ".webp"), file)) {
    if (file.exists(candidate)) return(candidate)
  }
  file
}

figure_files_in_roots <- function(roots) {
  roots <- roots[dir.exists(roots)]
  if (!length(roots)) return(character())
  files <- sort(unique(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "[.](png|jpg|jpeg|pdf|svg)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE)))
  files[!is_optimized_sidecar_figure(files)]
}

table_files_in_roots <- function(roots) {
  roots <- roots[dir.exists(roots)]
  if (!length(roots)) return(character())
  files <- sort(unique(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "[.]csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE)))
  files[!is_internal_report_table(files)]
}

curation_row_for_file <- function(curation, file, kind = c("figures", "tables")) {
  kind <- match.arg(kind)
  matches <- if (identical(kind, "figures")) {
    figure_curation_matches_file(curation, file)
  } else {
    table_curation_matches_file(curation, file)
  }
  if (nrow(matches)) matches[nrow(matches), , drop = FALSE] else matches
}

row_value <- function(row, name, default = "") {
  if (!is.data.frame(row) || !nrow(row) || !name %in% names(row)) return(default)
  value <- clean_text(row[[name]][[1]])
  if (nzchar(value)) value else default
}

catalog_figure_rows <- function(catalog, curation, roots, metadata) {
  catalog <- apply_figure_curation(catalog, curation)
  if (!nrow(catalog)) return(data.frame(stringsAsFactors = FALSE))
  rows <- list()
  for (i in seq_len(nrow(catalog))) {
    key <- clean_text(catalog$key[[i]])
    files <- find_report_assets(catalog$file_candidates[[i]], roots = roots)
    placement <- normalize_figure_placement(catalog$placement[[i]], default = "main")
    title <- render_report_text(catalog$title[[i]])
    section <- render_report_text(catalog$section[[i]])
    caption_override <- render_report_text(catalog$caption_override[[i]])
    caption_default <- render_report_text(catalog$caption[[i]])
    if (!length(files)) {
      rows[[length(rows) + 1L]] <- data.frame(
        kind = "figure",
        target_type = "key",
        target = key,
        placement = placement,
        section = section,
        title = title,
        caption_override = caption_override,
        order = "",
        notes = clean_text(catalog$notes[[i]]),
        status = "missing",
        file = "",
        current_caption = polish_report_caption(caption_default),
        source = "catalog",
        stringsAsFactors = FALSE
      )
      next
    }
    for (file in files) {
      rows[[length(rows) + 1L]] <- data.frame(
        kind = "figure",
        target_type = "key",
        target = key,
        placement = placement,
        section = section,
        title = title,
        caption_override = caption_override,
        order = "",
        notes = clean_text(catalog$notes[[i]]),
        status = if (placement == "exclude") "excluded" else "included",
        file = relative_from_report(file),
        current_caption = figure_caption(file, caption_default, metadata, override = caption_override),
        source = "catalog",
        stringsAsFactors = FALSE
      )
    }
  }
  bind_report_rows(rows)
}

extra_figure_rows <- function(files, catalog, curation, metadata) {
  catalog_tokens <- catalog_all_candidate_tokens(catalog)
  rows <- list()
  for (file in files) {
    file_tokens <- file_match_tokens(file)
    if (any(file_tokens %in% catalog_tokens) || is_default_excluded_figure(file)) {
      next
    }
    match <- curation_row_for_file(curation, file, "figures")
    placement <- if (nrow(match)) normalize_figure_placement(match$placement[[1]], default = "appendix") else "appendix"
    title <- row_value(match, "title")
    if (!nzchar(title)) {
      title <- gsub("[-_]+", " ", tools::file_path_sans_ext(basename(file)))
      title <- paste0(toupper(substr(title, 1, 1)), substr(title, 2, nchar(title)))
    }
    section <- row_value(match, "section", if (placement == "main") "Curated generated figures" else "Supplemental generated figures")
    caption_override <- row_value(match, "caption_override")
    rows[[length(rows) + 1L]] <- data.frame(
      kind = "figure",
      target_type = "file",
      target = basename(file),
      placement = placement,
      section = section,
      title = title,
      caption_override = caption_override,
      order = row_value(match, "order"),
      notes = row_value(match, "notes"),
      status = if (placement == "exclude") "excluded" else if (placement == "main") "included" else "appendix",
      file = relative_from_report(file),
      current_caption = figure_caption(file, title, metadata, override = caption_override),
      source = if (nrow(match)) "curation" else "generated",
      stringsAsFactors = FALSE
    )
  }
  bind_report_rows(rows)
}

catalog_table_rows <- function(catalog, curation, roots, metadata) {
  catalog <- apply_table_curation(catalog, curation)
  if (!nrow(catalog)) return(data.frame(stringsAsFactors = FALSE))
  rows <- list()
  for (i in seq_len(nrow(catalog))) {
    key <- clean_text(catalog$key[[i]])
    file <- find_report_asset(catalog$file_candidates[[i]], roots = roots)
    placement <- normalize_figure_placement(catalog$placement[[i]], default = "main")
    caption_override <- render_report_text(catalog$caption_override[[i]])
    rows[[length(rows) + 1L]] <- data.frame(
      kind = "table",
      target_type = "key",
      target = key,
      placement = placement,
      section = render_report_text(catalog$section[[i]]),
      title = render_report_text(catalog$title[[i]]),
      caption_override = caption_override,
      order = "",
      notes = clean_text(catalog$notes[[i]]),
      status = if (!nzchar(file)) "missing" else if (placement == "exclude") "excluded" else "included",
      file = if (nzchar(file)) relative_from_report(file) else "",
      current_caption = table_caption(file, render_report_text(catalog$caption[[i]]), metadata, override = caption_override),
      source = "catalog",
      stringsAsFactors = FALSE
    )
  }
  bind_report_rows(rows)
}

extra_table_rows <- function(files, catalog, curation, metadata) {
  catalog_tokens <- catalog_all_candidate_tokens(catalog)
  rows <- list()
  for (file in files) {
    file_tokens <- file_match_tokens(file)
    if (any(file_tokens %in% catalog_tokens)) {
      next
    }
    match <- curation_row_for_file(curation, file, "tables")
    placement <- if (nrow(match)) normalize_figure_placement(match$placement[[1]], default = "appendix") else "appendix"
    title <- row_value(match, "title")
    if (!nzchar(title)) {
      title <- gsub("[-_]+", " ", tools::file_path_sans_ext(basename(file)))
      title <- paste0(toupper(substr(title, 1, 1)), substr(title, 2, nchar(title)))
    }
    rows[[length(rows) + 1L]] <- data.frame(
      kind = "table",
      target_type = "file",
      target = basename(file),
      placement = placement,
      section = row_value(match, "section", if (placement == "main") "Curated generated tables" else "Supplemental generated tables"),
      title = title,
      caption_override = row_value(match, "caption_override"),
      order = row_value(match, "order"),
      notes = row_value(match, "notes"),
      status = if (placement == "exclude") "excluded" else if (placement == "main") "included" else "appendix",
      file = relative_from_report(file),
      current_caption = table_caption(file, title, metadata, override = row_value(match, "caption_override")),
      source = if (nrow(match)) "curation" else "generated",
      stringsAsFactors = FALSE
    )
  }
  bind_report_rows(rows)
}

table_preview_html <- function(file) {
  if (!nzchar(file) || !file.exists(file)) return('<span class="missing">Missing file</span>')
  x <- read_report_csv(file)
  if (!nrow(x)) return('<span class="missing">Empty table</span>')
  x <- utils::head(x[, seq_len(min(5, ncol(x))), drop = FALSE], 6)
  header <- paste(sprintf("<th>%s</th>", html_escape(names(x))), collapse = "")
  rows <- apply(x, 1, function(row) {
    paste0("<tr>", paste(sprintf("<td>%s</td>", html_escape(row)), collapse = ""), "</tr>")
  })
  paste0("<table><thead><tr>", header, "</tr></thead><tbody>", paste(rows, collapse = ""), "</tbody></table>")
}

card_html <- function(rows) {
  if (!nrow(rows)) return(character())
  vapply(seq_len(nrow(rows)), function(i) {
    row <- rows[i, , drop = FALSE]
    file <- clean_text(row$file[[1]])
    status <- clean_text(row$status[[1]])
    if (!nzchar(status)) status <- if (nzchar(file)) "included" else "missing"
    absolute_file <- if (nzchar(file)) file.path(getwd(), file) else ""
    if (identical(row$kind[[1]], "figure")) {
      if (identical(status, "missing") && !nzchar(file)) {
        preview <- '<span class="missing">Not generated in this run</span>'
      } else {
        preview_file <- if (nzchar(absolute_file)) review_preview_file(absolute_file) else ""
        src <- html_src_from_curation(preview_file)
        preview <- if (nzchar(src) && grepl("[.](png|jpg|jpeg|svg|webp)$", preview_file, ignore.case = TRUE)) {
          sprintf('<img src="%s" alt="">', html_escape(src))
        } else if (nzchar(src)) {
          sprintf('<a class="file-link" href="%s">Open file</a>', html_escape(src))
        } else {
          '<span class="missing">Preview unavailable</span>'
        }
      }
    } else {
      preview <- if (identical(status, "missing") && !nzchar(file)) {
        '<span class="missing">Not generated in this run</span>'
      } else {
        table_preview_html(absolute_file)
      }
    }
    sprintf(
      '<article class="card" data-kind="%s" data-placement="%s" data-status="%s" data-search="%s"><div class="preview">%s</div><div class="meta"><span class="pill kind">%s</span><span class="pill %s">%s</span><span class="pill status-%s">%s</span><span>%s</span></div><h2>%s</h2><p class="target">%s: %s</p><p class="caption">%s</p><p class="notes">%s</p></article>',
      html_escape(row$kind[[1]]),
      html_escape(row$placement[[1]]),
      html_escape(status),
      html_escape(paste(row$kind, row$section, row$title, row$target, row$file, row$current_caption, row$notes, collapse = " ")),
      preview,
      html_escape(row$kind[[1]]),
      html_escape(row$placement[[1]]),
      html_escape(row$placement[[1]]),
      html_escape(status),
      html_escape(status),
      html_escape(row$section[[1]]),
      html_escape(row$title[[1]]),
      html_escape(row$target_type[[1]]),
      html_escape(row$target[[1]]),
      html_escape(row$current_caption[[1]]),
      html_escape(row$notes[[1]])
    )
  }, character(1))
}

qmd_caption_text <- function(x) {
  x <- clean_text(x)
  x <- gsub("\\s+", " ", x)
  x <- gsub("\\[", "\\\\[", x)
  x <- gsub("\\]", "\\\\]", x)
  x
}

r_string <- function(x) {
  paste(deparse(as.character(x), control = "keepNA"), collapse = "")
}

qmd_preferred_figure_path <- function(path) {
  sprintf("`r markdown_path(preferred_figure_file(%s))`", r_string(path))
}

write_figure_qmd_draft <- function(rows, path) {
  rows <- rows[rows$kind == "figure", , drop = FALSE]
  if (nrow(rows)) {
    placement <- vapply(rows$placement, normalize_figure_placement, character(1), default = "appendix")
    status <- clean_text(rows$status)
    keep <- placement %in% c("main", "appendix") & status != "missing" & nzchar(clean_text(rows$file))
    rows <- rows[keep, , drop = FALSE]
  }

  lines <- c(
    "<!--",
    "Generated figure-caption draft.",
    "",
    "Edit this file only when you want full manual control over figure text and ordering.",
    "To use it in the report, copy it to sections/Figures_manual.qmd and set",
    'manual_figures_qmd: "sections/Figures_manual.qmd" in report-config.yml.',
    "",
    "The image paths still call preferred_figure_file(), so HTML/PDF renders can use",
    "the compact sidecar images when they are available.",
    "-->",
    ""
  )

  if (!nrow(rows)) {
    writeLines(c(lines, "<!-- No generated figures were available for this run. -->"), path)
    return(invisible(FALSE))
  }

  rows$.original_order <- seq_len(nrow(rows))
  rows <- rows[order(match(rows$placement, c("main", "appendix")), rows$section, rows$title, rows$.original_order), , drop = FALSE]
  labels <- make.unique(vapply(rows$file, function(file) {
    slug_id(paste("manual", tools::file_path_sans_ext(basename(file))))
  }, character(1)), sep = "-")
  last_section <- ""
  wrote_appendix <- FALSE

  for (i in seq_len(nrow(rows))) {
    placement <- normalize_figure_placement(rows$placement[[i]], default = "appendix")
    if (identical(placement, "appendix") && !wrote_appendix) {
      lines <- c(lines, "", "# Appendix: Supplemental Figures", "")
      last_section <- ""
      wrote_appendix <- TRUE
    }
    section <- clean_text(rows$section[[i]])
    if (!nzchar(section)) {
      section <- if (identical(placement, "main")) "Curated figures" else "Supplemental figures"
    }
    if (!identical(section, last_section)) {
      lines <- c(lines, sprintf("## %s", section), "")
      last_section <- section
    }
    title <- clean_text(rows$title[[i]])
    if (!nzchar(title)) {
      title <- gsub("[-_]+", " ", tools::file_path_sans_ext(basename(rows$file[[i]])))
      title <- paste0(toupper(substr(title, 1, 1)), substr(title, 2, nchar(title)))
    }
    caption <- clean_text(rows$caption_override[[i]])
    if (!nzchar(caption)) {
      caption <- rows$current_caption[[i]]
    }
    caption <- qmd_caption_text(caption)
    file <- clean_text(rows$file[[i]])
    lines <- c(
      lines,
      sprintf("### %s", title),
      "",
      sprintf("![%s](%s){#fig-%s fig-align=\"center\" width=100%%}", caption, qmd_preferred_figure_path(file), labels[[i]]),
      ""
    )
  }

  writeLines(lines, path)
  invisible(TRUE)
}

write_review_html <- function(rows, path) {
  rows <- rows[order(rows$kind, match(rows$placement, c("main", "appendix", "exclude")), rows$section, rows$title, rows$target), , drop = FALSE]
  figure_count <- sum(rows$kind == "figure")
  table_count <- sum(rows$kind == "table")
  counts <- table(factor(rows$placement, levels = c("main", "appendix", "exclude")))
  status_counts <- table(factor(rows$status, levels = c("included", "appendix", "excluded", "missing")))
  available_count <- sum(rows$status != "missing")
  html <- c(
    "<!doctype html>",
    '<html lang="en">',
    "<head>",
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    "<title>BET 2026 Report Curation</title>",
    "<style>",
    "body{margin:0;font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f4f8fb;color:#143044}",
    ".shell{max-width:1500px;margin:0 auto;padding:28px}",
    "header{display:flex;gap:18px;align-items:flex-end;justify-content:space-between;margin-bottom:18px}",
    "h1{font-size:34px;line-height:1.05;margin:0}.sub{margin:8px 0 0;color:#5c7182;font-weight:650}",
    ".toolbar{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:18px 0}.toolbar input{min-width:280px;flex:1;padding:12px 14px;border:1px solid #c9d9e4;border-radius:10px;background:white;font:inherit}",
    ".filter{border:1px solid #c9d9e4;background:white;border-radius:999px;padding:10px 13px;font-weight:800;color:#24465d;cursor:pointer}.filter.is-active{background:#143044;color:white;border-color:#143044}",
    ".summary{display:flex;gap:10px;flex-wrap:wrap}.stat{background:white;border:1px solid #d5e2ea;border-radius:10px;padding:10px 13px;font-weight:850}.stat small{display:block;color:#6b7f8d;font-weight:750}",
    ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}.card{background:white;border:1px solid #d5e2ea;border-radius:10px;box-shadow:0 8px 22px rgba(33,70,92,.07);overflow:hidden}.card[data-status='missing']{background:#f8fbfd}.card[hidden]{display:none}",
    ".preview{height:220px;background:#e9f1f6;display:flex;align-items:center;justify-content:center;border-bottom:1px solid #d5e2ea;overflow:auto}.preview img{max-width:100%;max-height:100%;object-fit:contain}.missing,.file-link{font-weight:850;color:#60788b}",
    "table{border-collapse:collapse;background:white;font-size:11px;min-width:100%}th,td{border:1px solid #d5e2ea;padding:5px 6px;text-align:left;vertical-align:top;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}th{background:#f7fafc}",
    ".meta{display:flex;align-items:center;gap:8px;margin:12px 14px 0;color:#60788b;font-size:13px;font-weight:800;flex-wrap:wrap}.pill{border-radius:999px;padding:5px 9px;text-transform:uppercase;font-size:11px;letter-spacing:.04em}.pill.kind{background:#eaf3f8;color:#28556e}.pill.main{background:#e5f6ee;color:#19754e}.pill.appendix{background:#eef4ff;color:#2a5fa6}.pill.exclude{background:#fff0e9;color:#a04722}",
    ".pill.status-included,.pill.status-appendix{background:#edf7f0;color:#24724e}.pill.status-excluded{background:#fff0e9;color:#a04722}.pill.status-missing{background:#eef4f8;color:#60788b}",
    "h2{font-size:18px;line-height:1.2;margin:10px 14px 6px}.target{margin:0 14px 10px;color:#597082;font-weight:750}.caption{margin:0 14px 12px;line-height:1.45}.notes{margin:0 14px 16px;color:#7c5b22;font-weight:700}",
    ".guide{background:#eaf5fb;border:1px solid #cbe0ec;border-radius:12px;padding:14px 16px;margin:0 0 18px;color:#24465d;line-height:1.45}.guide code{background:white;border:1px solid #d4e2eb;border-radius:6px;padding:1px 5px}",
    "</style>",
    "</head>",
    "<body>",
    '<main class="shell">',
    "<header><div><h1>Report curation</h1><p class=\"sub\">Review generated figures and tables, then edit <code>catalog/curation.yml</code> or the generated QMD caption draft for final placement and captions.</p></div>",
    sprintf('<div class="summary"><div class="stat">%s<small>Figures</small></div><div class="stat">%s<small>Tables</small></div><div class="stat">%s<small>Available</small></div><div class="stat">%s<small>Main</small></div><div class="stat">%s<small>Appendix</small></div><div class="stat">%s<small>Needs source</small></div></div>',
            figure_count, table_count, available_count, counts[["main"]] %||% 0, counts[["appendix"]] %||% 0, status_counts[["missing"]] %||% 0),
    "</header>",
    '<section class="guide">Most report items come from the catalogs automatically. For targeted edits, use <code>catalog/curation.yml</code> with <code>placement</code>, <code>section</code>, <code>title</code>, <code>caption_override</code>, and <code>order</code>. For full manual caption editing, open <code>curation/figure-caption-draft.qmd</code>, copy it to <code>sections/Figures_manual.qmd</code>, edit the QMD text, and set <code>manual_figures_qmd</code> in <code>report-config.yml</code>.</section>',
    '<div class="toolbar"><input id="search" type="search" placeholder="Search title, file, section, caption..."><button class="filter is-active" data-filter-kind="all" data-filter-placement="all" data-filter-status="available">Available</button><button class="filter" data-filter-kind="all" data-filter-placement="all" data-filter-status="all">All</button><button class="filter" data-filter-kind="figure" data-filter-placement="all" data-filter-status="available">Figures</button><button class="filter" data-filter-kind="table" data-filter-placement="all" data-filter-status="available">Tables</button><button class="filter" data-filter-kind="all" data-filter-placement="main" data-filter-status="available">Main</button><button class="filter" data-filter-kind="all" data-filter-placement="appendix" data-filter-status="available">Appendix</button><button class="filter" data-filter-kind="all" data-filter-placement="exclude" data-filter-status="all">Excluded</button><button class="filter" data-filter-kind="all" data-filter-placement="all" data-filter-status="missing">Needs source</button></div>',
    '<section class="grid" id="grid">',
    card_html(rows),
    "</section>",
    "</main>",
    "<script>",
    "const search=document.querySelector('#search');const buttons=[...document.querySelectorAll('.filter')];const cards=[...document.querySelectorAll('.card')];let kind='all';let placement='all';let status='available';function sync(){const q=(search.value||'').toLowerCase().trim();cards.forEach(card=>{const okKind=kind==='all'||card.dataset.kind===kind;const okPlacement=placement==='all'||card.dataset.placement===placement;const okStatus=status==='all'||(status==='available'?card.dataset.status!=='missing':card.dataset.status===status);const okSearch=!q||(card.dataset.search||'').toLowerCase().includes(q);card.hidden=!(okKind&&okPlacement&&okStatus&&okSearch);});}buttons.forEach(btn=>btn.addEventListener('click',()=>{kind=btn.dataset.filterKind;placement=btn.dataset.filterPlacement;status=btn.dataset.filterStatus;buttons.forEach(b=>b.classList.toggle('is-active',b===btn));sync();}));search.addEventListener('input',sync);sync();",
    "</script>",
    "</body></html>"
  )
  writeLines(html, path)
}

write_yaml_template <- function(path, figure_rows, table_rows) {
  lines <- c(
    "# Copy rows from the review templates below when manual edits are needed.",
    "# placement: main | appendix | exclude",
    "# target_type: key for catalog rows, file for generated filenames",
    ""
  )
  excluded_figures <- figure_rows[figure_rows$placement == "exclude", , drop = FALSE]
  if (nrow(excluded_figures)) {
    lines <- c(lines, "figures:")
    for (i in seq_len(nrow(excluded_figures))) {
      lines <- c(lines,
                 sprintf("  - target_type: %s", excluded_figures$target_type[[i]]),
                 sprintf("    target: %s", excluded_figures$target[[i]]),
                 sprintf("    placement: %s", excluded_figures$placement[[i]]),
                 sprintf("    notes: %s", excluded_figures$notes[[i]] %||% ""))
    }
  } else {
    lines <- c(lines, "figures: []")
  }
  lines <- c(lines, "", "tables: []")
  writeLines(lines, path)
}

figure_catalog <- read_catalog("figures")
figure_curation <- read_figure_curation()
figure_roots <- unique(c(
  report_paths("figure_roots", c("Figures")),
  report_paths("extra_figure_roots", c("Figures"))
))
figure_metadata <- read_figure_metadata(figure_roots)
figure_files <- figure_files_in_roots(figure_roots)
figure_rows <- bind_report_rows(list(
  catalog_figure_rows(figure_catalog, figure_curation, figure_roots, figure_metadata),
  extra_figure_rows(figure_files, figure_catalog, figure_curation, figure_metadata)
))

table_catalog <- read_catalog("tables")
table_curation <- read_table_curation()
table_roots <- unique(c(
  report_paths("table_roots", c("pipeline-inputs", "tables/generated", "tables", "Tables")),
  report_paths("extra_table_roots", c("tables"))
))
table_metadata <- read_table_metadata(table_roots)
table_files <- table_files_in_roots(table_roots)
table_rows <- bind_report_rows(list(
  catalog_table_rows(table_catalog, table_curation, table_roots, table_metadata),
  extra_table_rows(table_files, table_catalog, table_curation, table_metadata)
))

template_cols <- c("target_type", "target", "placement", "section", "title", "caption_override", "order", "notes", "status", "file", "current_caption", "source")
for (name in setdiff(template_cols, names(figure_rows))) figure_rows[[name]] <- ""
for (name in setdiff(template_cols, names(table_rows))) table_rows[[name]] <- ""

utils::write.csv(figure_rows[, template_cols, drop = FALSE], file.path(curation_dir, "figure-curation-template.csv"), row.names = FALSE)
utils::write.csv(table_rows[, template_cols, drop = FALSE], file.path(curation_dir, "table-curation-template.csv"), row.names = FALSE)
write_yaml_template(file.path(curation_dir, "curation-template.yml"), figure_rows, table_rows)

all_rows <- bind_report_rows(list(figure_rows, table_rows))
if (!nrow(all_rows)) {
  all_rows <- data.frame(kind = character(), target_type = character(), target = character(), placement = character(), section = character(), title = character(), caption_override = character(), order = character(), notes = character(), status = character(), file = character(), current_caption = character(), source = character(), stringsAsFactors = FALSE)
}
review_path <- file.path(curation_dir, "report-curation-review.html")
write_review_html(all_rows, review_path)
write_figure_qmd_draft(all_rows, file.path(curation_dir, "figure-caption-draft.qmd"))
invisible(file.copy(review_path, file.path(curation_dir, "figure-curation-review.html"), overwrite = TRUE))
message("Wrote report curation review: ", review_path)
