#!/usr/bin/env Rscript
# Base-R, offline Figure 66 reader. It never edits the report checkout.
options(stringsAsFactors = FALSE)
fail <- function(...) stop(..., call. = FALSE)
require_true <- function(value, ...) if (!isTRUE(value)) fail(...)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
require_true(length(script_arg) == 1L, "Run this reader with Rscript.")
here <- dirname(normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE))
repo <- dirname(here)
cases <- c("reference", "longline", "pole_line", "ps", "ps_associated", "ps_unassociated", "miscellaneous", "all_off")
base_files <- c("final.par", "bet.age_length", "bet.frq", "bet.ini", "bet.reg_scaling", "bet.tag", "mfcl.cfg", "doitall.sh", "mfclo64")
baseline <- c("1 1 1", "1 50 -4", "1 121 0", "1 246 1")

exists_path <- function(path) {
  link <- Sys.readlink(path)
  file.exists(path) || dir.exists(path) || (!is.na(link) && nzchar(link))
}
regular_file <- function(path) {
  info <- file.info(path)
  link <- Sys.readlink(path)
  require_true(nrow(info) == 1L && !is.na(info$isdir) && !info$isdir && file_test("-f", path) &&
                 (is.na(link) || !nzchar(link)), "Expected an ordinary file: ", path)
  invisible(info)
}
directory <- function(path) {
  info <- file.info(path)
  link <- Sys.readlink(path)
  require_true(nrow(info) == 1L && !is.na(info$isdir) && info$isdir &&
                 (is.na(link) || !nzchar(link)), "Expected an ordinary directory: ", path)
  invisible(path)
}
checked_command <- function(program, args) {
  found <- Sys.which(program)
  require_true(nzchar(found), "Required system command unavailable: ", program)
  result <- suppressWarnings(system2(found, args, stdout = TRUE, stderr = TRUE))
  status <- attr(result, "status")
  require_true(is.null(status) || status == 0L, program, " failed: ", paste(result, collapse = "\n"))
  result
}
sha256 <- function(paths) {
  invisible(lapply(paths, regular_file))
  program <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else "shasum"
  result <- checked_command(program, c(if (program == "shasum") c("-a", "256"), "--", shQuote(paths)))
  require_true(length(result) == length(paths) && all(grepl("^[0-9a-f]{64}[[:space:]]", result)), "Invalid SHA-256 utility output.")
  substring(result, 1L, 64L)
}
single_links <- function(paths) {
  args <- if (Sys.info()[["sysname"]] == "Darwin") c("-f", "%l") else c("-c", "%h")
  observed <- checked_command("stat", c(args, shQuote(paths)))
  require_true(length(observed) == length(paths) && all(observed == "1"), "Native inputs must be ordinary files with one link.")
}
safe_relative <- function(paths, allow_spaces = FALSE) {
  pattern <- if (allow_spaces) "^[A-Za-z0-9._/ -]+$" else "^[A-Za-z0-9._/-]+$"
  require_true(length(paths) > 0L && all(grepl(pattern, paths)) && !any(startsWith(paths, "/")) &&
                 !any(vapply(strsplit(paths, "/", fixed = TRUE), function(parts) any(parts %in% c("", ".", "..")), logical(1))),
               "Unsafe relative path.")
  invisible(paths)
}
read_csv <- function(path, columns) {
  regular_file(path)
  result <- utils::read.csv(path, check.names = FALSE, colClasses = "character", na.strings = NULL)
  require_true(identical(names(result), columns), "Unexpected CSV columns: ", path)
  result
}
ancestor_chain <- function(path) {
  require_true(startsWith(path, "/") && !grepl("[\r\n]", path), "Set OUT to an absolute, new directory.")
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]][-1L]
  require_true(length(parts) > 0L && !any(parts %in% c("", ".", "..")), "OUT contains an unsafe path component.")
  current <- "/"
  for (part in parts) {
    current <- file.path(current, part)
    if (exists_path(current)) directory(current)
  }
  invisible(path)
}
fresh_output <- function(path, build = FALSE, create = FALSE) {
  require_true(length(path) == 1L && nzchar(path) && startsWith(path, "/"), "Set OUT to an absolute, new directory.")
  require_true(!exists_path(path), "OUT already exists; choose a new directory.")
  ancestor_chain(path)
  inside <- identical(path, repo) || startsWith(path, paste0(repo, "/"))
  allowed <- startsWith(path, paste0(repo, "/outputs/"))
  require_true(!inside || (!build && allowed), if (build) "Build OUT must be outside this checkout." else
                 "OUT inside the checkout must be beneath outputs/.")
  if (create) {
    parent <- dirname(path)
    if (!dir.exists(parent)) require_true(dir.create(parent, recursive = TRUE, mode = "0700"), "Could not create OUT parent.")
    ancestor_chain(parent)
    require_true(dir.create(path, mode = "0700"), "OUT already exists or cannot be created.")
    directory(path)
  }
  path
}
check_files <- function(root, rows, exact = FALSE) {
  safe_relative(rows$path)
  paths <- file.path(root, rows$path)
  invisible(lapply(unique(dirname(paths)), directory))
  invisible(lapply(paths, regular_file))
  single_links(paths)
  info <- file.info(paths)
  require_true(identical(as.numeric(info$size), as.numeric(rows$bytes)), "Input size differs.")
  require_true(identical(as.integer(info$mode), as.integer(rows$mode)), "Input permission mode differs.")
  require_true(identical(sha256(paths), rows$sha256), "Input SHA-256 differs.")
  if (exact) require_true(setequal(list.files(root, recursive = TRUE, all.files = TRUE, no.. = TRUE), rows$path),
                         "Extracted native kit contains missing or extra files.")
  invisible(TRUE)
}
inventory <- function() {
  pins <- read_csv(file.path(here, "READER-PINS.csv"), c("path", "bytes", "sha256"))
  safe_relative(pins$path)
  require_true(!anyDuplicated(pins$path), "Duplicate reader checksum pin.")
  paths <- file.path(repo, pins$path)
  require_true(identical(as.numeric(file.info(paths)$size), as.numeric(pins$bytes)) &&
                 identical(sha256(paths), pins$sha256), "Reader or legacy recipe bytes differ.")
  files <- read_csv(file.path(here, "READER-FILES.csv"),
                    c("path", "bytes", "sha256", "mode", "source_repository", "source_commit", "source_path"))
  expected <- c(paste0("shared/", base_files), paste0("controls/", cases[-1L], ".txt"))
  require_true(nrow(files) == 16L && !anyDuplicated(files$path) && setequal(files$path, expected), "Expected exactly the 16 native kit files.")
  require_true(all(grepl("^[0-9]+$", files$bytes)) && all(as.numeric(files$bytes) > 0) &&
                 all(grepl("^[0-9a-f]{64}$", files$sha256)) && all(files$mode %in% c("420", "493")) &&
                 all(grepl("^PacificCommunity/ofp-sam-bet-2026-(diagnostic|report)$", files$source_repository)) &&
                 all(grepl("^[0-9a-f]{40}$", files$source_commit)), "Invalid native source record.")
  safe_relative(files$source_path)
  models <- read_csv(file.path(here, "READER-CASES.csv"), c("case", "controls_path", "report_sha256"))
  require_true(identical(models$case, cases) && all(grepl("^[0-9a-f]{64}$", models$report_sha256)) &&
                 identical(models$controls_path, c("", paste0("controls/", cases[-1L], ".txt"))), "Expected the original eight cases and whole-REP hashes.")
  list(files = files, models = models)
}
unpack <- function(data) {
  archive <- file.path(here, "reader-native.tar.xz")
  members <- checked_command("tar", c("-tJf", shQuote(archive)))
  safe_relative(members)
  require_true(!anyDuplicated(members) && setequal(members, data$files$path), "Native archive member list differs.")
  # The archive is checksum-pinned before decoding and contains regular files only.
  folder <- tempfile("bet-reader-")
  require_true(dir.create(folder, mode = "0700"), "Could not create native staging directory.")
  checked_command("tar", c("-xJf", shQuote(archive), "-C", shQuote(folder), "--no-same-owner"))
  check_files(folder, data$files, exact = TRUE)
  folder
}
verify_preserved <- function() {
  rows <- read_csv(file.path(here, "READER-PRESERVED.csv"), c("path", "mode", "sha256"))
  safe_relative(rows$path, allow_spaces = TRUE)
  require_true(nrow(rows) > 0L && !anyDuplicated(rows$path) && all(rows$mode %in% c("100644", "100755")), "Unexpected preserved-file manifest.")
  paths <- file.path(repo, rows$path)
  invisible(lapply(paths, regular_file))
  executable <- bitwAnd(as.integer(file.info(paths)$mode), 73L) != 0L
  require_true(identical(executable, rows$mode == "100755") && identical(sha256(paths), rows$sha256), "Preserved assessment file or permission changed.")
  cat("Preserved", nrow(rows), "assessment files.\n")
}
prepare_case <- function(model, output, data, kit) {
  require_true(model %in% cases, "Choose a listed Figure 66 case.")
  rows <- data$files[startsWith(data$files$path, "shared/") | data$files$path == paste0("controls/", model, ".txt"), ]
  rows$target <- ifelse(startsWith(rows$path, "shared/"), basename(rows$path), "controls.txt")
  require_true(!anyDuplicated(rows$target) && all(base_files %in% rows$target), "Incomplete native case.")
  fresh_output(output, create = TRUE)
  paths <- file.path(output, rows$target)
  for (i in seq_len(nrow(rows))) {
    ancestor_chain(output)
    require_true(!exists_path(paths[i]), "Existing staged target refused: ", rows$target[i])
    require_true(file.copy(file.path(kit, rows$path[i]), paths[i], overwrite = FALSE, copy.mode = TRUE), "Could not copy native file.")
    Sys.chmod(paths[i], mode = as.octmode(as.integer(rows$mode[i])))
  }
  saved <- rows[, c("target", "bytes", "sha256", "mode")]
  names(saved)[1L] <- "path"
  check_files(output, saved, exact = TRUE)
  utils::write.csv(saved, file.path(output, "saved-inputs.csv"), row.names = FALSE)
  cat("Prepared", model, "at", output, "\n")
  saved
}
prepare_collection <- function(model, output, data, kit) {
  require_true(model == "all" || model %in% cases, "Choose a listed Figure 66 case or all.")
  if (model == "all") {
    fresh_output(output, create = TRUE)
    result <- lapply(cases, function(case) prepare_case(case, file.path(output, case), data, kit))
    names(result) <- cases
    result
  } else setNames(list(prepare_case(model, output, data, kit)), model)
}
native_host <- function() {
  require_true(Sys.info()[["sysname"]] == "Linux" && Sys.info()[["machine"]] %in% c("x86_64", "amd64"), "Native MFCL requires 64-bit x86 Linux.")
}
par_values <- function(path) {
  regular_file(path)
  lines <- readLines(path, warn = FALSE)
  scalar <- function(label) {
    index <- which(trimws(lines) == label)
    require_true(length(index) == 1L && index < length(lines), "Missing or repeated PAR section: ", label)
    value <- suppressWarnings(as.numeric(strsplit(trimws(lines[index + 1L]), "[[:space:]]+")[[1L]][1L]))
    require_true(is.finite(value), "Nonfinite PAR value: ", label)
    value
  }
  c(parameters = scalar("# The number of parameters"), objective = scalar("# Objective function value"))
}
evaluate <- function(model, output, expected, saved) {
  check_files(output, saved)
  before <- par_values(file.path(output, "final.par"))
  input <- if (model == "reference") "10.par" else "base.par"
  result_par <- if (model == "reference") "11.par" else "evaluated.par"
  require_true(!exists_path(file.path(output, input)), "Existing native PAR refused.")
  require_true(file.copy(file.path(output, "final.par"), file.path(output, input), overwrite = FALSE), "Could not stage native PAR.")
  controls <- if (model == "reference") file.path(output, "baseline-controls.txt") else file.path(output, "controls.txt")
  if (model == "reference") writeLines(baseline, controls, useBytes = TRUE)
  original <- getwd()
  on.exit(setwd(original), add = TRUE)
  setwd(output)
  check_files(output, saved)
  log <- file.path(output, "mfcl-native.log")
  status <- suppressWarnings(system2("./mfclo64", c("bet.frq", input, result_par, "-file", "-"), stdin = controls,
                                    stdout = log, stderr = log, timeout = 600))
  require_true(status %in% c(0L, 3L), "Native evaluation failed for ", model, ": status ", status)
  check_files(output, saved)
  require_true(sha256(file.path(output, input)) == saved$sha256[saved$path == "final.par"], "Staged final PAR changed.")
  par <- file.path(output, result_par)
  report <- file.path(output, paste0("plot-", result_par, ".rep"))
  require_true(file.info(par)$size > 0 && file.info(report)$size > 0 && sha256(report) == expected, "Native whole-REP SHA-256 differs for ", model)
  observed <- par_values(par)
  require_true(observed[["parameters"]] == before[["parameters"]], "Active parameter count differs for ", model)
  if (model == "reference") {
    values <- grep("^[[:space:]]*Total func[[:space:]]+[^[:space:]]+[[:space:]]*$", readLines(log, warn = FALSE), value = TRUE)
    require_true(length(values) > 0L, "Missing fitted objective in native log.")
    logged <- suppressWarnings(as.numeric(trimws(sub("^[[:space:]]*Total func[[:space:]]+", "", values[1L]))))
    require_true(is.finite(logged) && abs(logged - before[["objective"]]) <= 1e-6 &&
                   abs(observed[["objective"]] - before[["objective"]]) <= 1e-6, "Fitted reference objective differs.")
  }
  receipt <- data.frame(case = model, input_par_sha256 = sha256(file.path(output, "final.par")), report_sha256 = sha256(report),
                        active_parameters = observed[["parameters"]], objective = observed[["objective"]], native_status = status,
                        function_evaluation_ceiling = 1L)
  utils::write.csv(receipt, file.path(output, "native-check.csv"), row.names = FALSE)
  cat(model, ": original whole native report reproduced\n", sep = "")
  receipt
}
main <- function(args) {
  require_true(length(args) > 0L, "Use list, verify, prepare, rerun, fullfit, check-output or check-build-output.")
  action <- args[1L]
  if (action == "list") {
    require_true(length(args) == 1L, "list takes no arguments.")
    cat(paste(cases, collapse = "\n"), "\n", sep = "")
    return(invisible(NULL))
  }
  if (action %in% c("check-output", "check-build-output")) {
    require_true(length(args) == 2L, "Provide an absolute new OUT.")
    fresh_output(args[2L], build = action == "check-build-output")
    return(invisible(NULL))
  }
  verification <- action %in% c("verify", "verify-native")
  require_true(action %in% c("verify", "verify-native", "prepare", "rerun", "fullfit"), "Unknown reader action.")
  require_true(length(args) == if (verification) 1L else 3L, "Provide CASE and an absolute new OUT.")
  if (action %in% c("rerun", "fullfit")) native_host()
  if (!verification) {
    require_true(args[2L] == "all" || args[2L] %in% cases, "Choose a listed Figure 66 case or all.")
    fresh_output(args[3L])
  }
  if (action == "fullfit") require_true(args[2L] == "reference", "Original Diagnostic fitting is supported only for CASE=reference.")
  data <- inventory()
  kit <- unpack(data)
  on.exit(unlink(kit, recursive = TRUE), add = TRUE)
  if (verification) {
    if (action == "verify") verify_preserved()
    cat("Verified 16 exact native files and all eight original whole-REP checksum pins.\n")
    return(invisible(NULL))
  }
  staged <- prepare_collection(args[2L], args[3L], data, kit)
  if (action == "prepare") return(invisible(NULL))
  if (action == "rerun") {
    receipts <- lapply(names(staged), function(case) {
      location <- if (args[2L] == "all") file.path(args[3L], case) else args[3L]
      evaluate(case, location, data$models$report_sha256[match(case, data$models$case)], staged[[case]])
    })
    if (args[2L] == "all") utils::write.csv(do.call(rbind, receipts), file.path(args[3L], "native-checks.csv"), row.names = FALSE)
    return(invisible(NULL))
  }
  # Exact original script: ordinary bet.ini -makepar initialisation, no saved-PAR seed.
  original <- getwd()
  on.exit(setwd(original), add = TRUE)
  setwd(args[3L])
  check_files(args[3L], staged[["reference"]])
  status <- suppressWarnings(system2("sh", "./doitall.sh", stdout = "fullfit.log", stderr = "fullfit.log"))
  require_true(status == 0L && file.exists("11.par") && file.info("11.par")$size > 0, "Original Diagnostic fit failed; retain fullfit.log.")
  check_files(args[3L], staged[["reference"]])
  cat("Original Diagnostic doitall completed; scientific fit equivalence has not been assessed.\n")
}
tryCatch(main(commandArgs(trailingOnly = TRUE)), error = function(error) {
  message(conditionMessage(error))
  quit(status = 1L)
})
