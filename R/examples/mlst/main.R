# Run Carousel Greedy on all Group II small MLST instances.

ALPHA <- 50L
BETA <- 0.10
SEED <- 42L

script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0L) {
    stop("This example must be run with Rscript")
  }
  normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
}

example_dir <- dirname(script_path())
project_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
source(file.path(project_dir, "R", "carousel_greedy.R"))

load_native_mlst_kernel <- function() {
  source_path <- file.path(example_dir, "mlst_union_find.c")
  if (!file.exists(source_path)) return(FALSE)
  library_path <- file.path(tempdir(), paste0("mlst_union_find", .Platform$dynlib.ext))
  status <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "SHLIB", shQuote(source_path), "-o", shQuote(library_path)),
    stdout = FALSE, stderr = FALSE
  ))
  if (!identical(status, 0L) || !file.exists(library_path)) return(FALSE)
  dyn.load(library_path)
  TRUE
}

native_mlst_kernel <- load_native_mlst_kernel()

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  result <- list(
    instances_dir = file.path(project_dir, "instances", "group_II", "small"),
    output = file.path(example_dir, "mlst_group_II_small_results.csv"),
    averages_output = file.path(example_dir, "mlst_group_II_small_averages.csv"),
    alpha = ALPHA,
    beta = BETA,
    seed = SEED,
    feasibility_aware = TRUE
  )

  index <- 1L
  while (index <= length(args)) {
    option <- args[[index]]
    if (option == "--help") {
      cat(
        "Usage: Rscript examples/mlst/main.R [options]\n",
        "  --instances-dir PATH\n",
        "  --output PATH\n",
        "  --averages-output PATH\n",
        "  --alpha INTEGER\n",
        "  --beta NUMBER\n",
        "  --seed INTEGER\n",
        "  --feasibility-aware TRUE|FALSE\n",
        sep = ""
      )
      quit(status = 0L)
    }
    if (index == length(args)) stop("Missing value for ", option)
    value <- args[[index + 1L]]
    if (option == "--instances-dir") result$instances_dir <- value
    else if (option == "--output") result$output <- value
    else if (option == "--averages-output") result$averages_output <- value
    else if (option == "--alpha") result$alpha <- as.integer(value)
    else if (option == "--beta") result$beta <- as.numeric(value)
    else if (option == "--seed") result$seed <- as.integer(value)
    else if (option == "--feasibility-aware") {
      normalized <- tolower(value)
      if (!(normalized %in% c("true", "false"))) stop("feasibility-aware must be TRUE or FALSE")
      result$feasibility_aware <- normalized == "true"
    }
    else stop("Unknown option: ", option)
    index <- index + 2L
  }

  if (is.na(result$alpha) || result$alpha <= 0L) stop("alpha must be positive")
  if (is.na(result$beta) || result$beta < 0 || result$beta > 1) {
    stop("beta must be between 0 and 1")
  }
  result
}

new_connectivity_state <- function(size) {
  list(component_ids = seq_len(size), component_count = as.integer(size))
}

add_label_to_state_r <- function(state, instance, label) {
  edges <- instance$edges_by_label[[as.character(label)]]
  parent <- seq_len(state$component_count)
  merges <- 0L

  for (edge_index in seq_len(nrow(edges))) {
    root_first <- state$component_ids[[edges[edge_index, 1L]]]
    while (parent[[root_first]] != root_first) root_first <- parent[[root_first]]

    root_second <- state$component_ids[[edges[edge_index, 2L]]]
    while (parent[[root_second]] != root_second) root_second <- parent[[root_second]]

    if (root_first != root_second) {
      parent[[root_second]] <- root_first
      merges <- merges + 1L
    }
  }

  if (merges == 0L) return(state)

  roots <- parent
  for (component in seq_along(roots)) {
    root <- component
    while (parent[[root]] != root) root <- parent[[root]]
    roots[[component]] <- root
  }
  compact_ids <- match(roots, unique(roots))
  list(
    component_ids = compact_ids[state$component_ids],
    component_count = state$component_count - merges
  )
}

# Return only the number of component merges caused by a label.  Candidate
# scoring does not need the compact component vector built by add_label_to_state.
marginal_component_reduction_r <- function(state, instance, label) {
  if (state$component_count <= 1L) return(0L)

  edges <- instance$edges_by_label[[as.character(label)]]
  parent <- seq_len(state$component_count)
  merges <- 0L

  for (edge_index in seq_len(nrow(edges))) {
    root_first <- state$component_ids[[edges[edge_index, 1L]]]
    while (parent[[root_first]] != root_first) root_first <- parent[[root_first]]

    root_second <- state$component_ids[[edges[edge_index, 2L]]]
    while (parent[[root_second]] != root_second) root_second <- parent[[root_second]]

    if (root_first != root_second) {
      parent[[root_second]] <- root_first
      merges <- merges + 1L
    }
  }

  merges
}

add_label_to_state <- function(state, instance, label) {
  if (!native_mlst_kernel) return(add_label_to_state_r(state, instance, label))
  .Call("cg_add_label_to_state", state$component_ids, state$component_count,
        instance$edges_by_label[[as.character(label)]])
}

marginal_component_reduction <- function(state, instance, label) {
  if (!native_mlst_kernel) {
    return(marginal_component_reduction_r(state, instance, label))
  }
  .Call("cg_marginal_component_reduction", state$component_ids,
        state$component_count, instance$edges_by_label[[as.character(label)]])
}

solution_vector <- function(solution) {
  if (length(solution) == 0L) integer() else as.integer(unlist(solution, FALSE))
}

update_connectivity_state <- function(instance, solution) {
  cache <- instance$cache
  current_solution <- solution_vector(solution)

  if (!is.null(cache$last_solution) && identical(cache$last_solution, current_solution)) {
    return(cache$state)
  }

  can_append <- !is.null(cache$last_solution) &&
    length(current_solution) == length(cache$last_solution) + 1L &&
    identical(
      current_solution[seq_along(cache$last_solution)],
      cache$last_solution
    )

  if (can_append) {
    state <- add_label_to_state(
      cache$state, instance, tail(current_solution, 1L)
    )
  } else {
    state <- new_connectivity_state(instance$node_count)
    if (length(current_solution) > 0L) {
      for (label in current_solution) {
        state <- add_label_to_state(state, instance, label)
      }
    }
  }

  cache$last_solution <- current_solution
  cache$state <- state
  state
}

mlst_feasibility <- function(self, solution) {
  update_connectivity_state(self$data, solution)$component_count == 1L
}

mlst_greedy <- function(self, solution, candidate) {
  current <- update_connectivity_state(self$data, solution)
  marginal_component_reduction(current, self$data, candidate)
}

read_mlst <- function(path) {
  values <- scan(path, what = integer(), quiet = TRUE)
  if (length(values) < 3L || (length(values) - 3L) %% 3L != 0L) {
    stop("Invalid MLST file: ", path)
  }

  node_count <- values[[1L]]
  declared_edge_count <- values[[2L]]
  edge_values <- values[-seq_len(3L)]
  edges <- matrix(edge_values, ncol = 3L, byrow = TRUE)
  if (nrow(edges) != declared_edge_count) {
    stop(path, " declares ", declared_edge_count,
         " edges but contains ", nrow(edges))
  }
  if (any(edges[, 1:2, drop = FALSE] < 0L) ||
      any(edges[, 1:2, drop = FALSE] >= node_count)) {
    stop("Node outside the valid range in ", path)
  }

  # Instance vertices are zero-based; R vectors are one-based.
  edges[, 1:2] <- edges[, 1:2] + 1L
  edge_indices <- split(seq_len(nrow(edges)), edges[, 3L])
  edges_by_label <- lapply(
    edge_indices,
    function(indices) edges[indices, 1:2, drop = FALSE]
  )

  name <- basename(path)
  name_fields <- strsplit(tools::file_path_sans_ext(name), "_", fixed = TRUE)[[1L]]
  if (length(name_fields) < 4L || is.na(suppressWarnings(as.integer(name_fields[[4L]])))) {
    stop("Cannot extract optimum from instance name: ", name)
  }

  instance <- list(
    name = name,
    node_count = node_count,
    edge_count = nrow(edges),
    optimum = as.integer(name_fields[[4L]]),
    labels = sort(as.integer(names(edges_by_label))),
    edges_by_label = edges_by_label,
    cache = new.env(parent = emptyenv())
  )
  class(instance) <- "mlst_instance"

  if (!mlst_instance_connected(instance, instance$labels)) {
    stop("The graph is not connected: ", path)
  }
  instance
}

mlst_instance_connected <- function(instance, solution) {
  update_connectivity_state(instance, as.list(solution))$component_count == 1L
}

solve_instance <- function(instance, alpha, beta, seed, feasibility_aware) {
  solver <- carousel_greedy(
    test_feasibility = mlst_feasibility,
    greedy_function = mlst_greedy,
    candidate_elements = instance$labels,
    data = instance,
    seed = seed,
    feasibility_aware = feasibility_aware
  )

  start <- proc.time()[["elapsed"]]
  best_solution <- solver$minimize(alpha = alpha, beta = beta)
  elapsed <- proc.time()[["elapsed"]] - start
  greedy_solution <- solution_vector(solver$greedy_solution)
  cg_solution <- solution_vector(solver$cg_solution)
  best_solution <- solution_vector(best_solution)

  data.frame(
    instance = instance$name,
    nodes = instance$node_count,
    edges = instance$edge_count,
    labels = length(instance$labels),
    optimum = instance$optimum,
    alpha = alpha,
    beta = beta,
    seed = seed,
    feasibility_aware = feasibility_aware,
    greedy_value = length(greedy_solution),
    cg_value = length(cg_solution),
    best_value = length(best_solution),
    improvement = length(greedy_solution) - length(best_solution),
    elapsed_seconds = elapsed,
    greedy_feasible = mlst_instance_connected(instance, greedy_solution),
    cg_feasible = mlst_instance_connected(instance, cg_solution),
    best_labels = paste(best_solution, collapse = " "),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

write_averages <- function(results, output_path) {
  group_columns <- c("nodes", "edges", "labels", "optimum")
  keys <- unique(results[group_columns])
  keys <- keys[do.call(order, keys), , drop = FALSE]

  rows <- lapply(seq_len(nrow(keys)), function(index) {
    key <- keys[index, , drop = FALSE]
    selected <- results$nodes == key$nodes &
      results$edges == key$edges &
      results$labels == key$labels &
      results$optimum == key$optimum
    group <- results[selected, , drop = FALSE]
    average_cg_objective <- mean(group$cg_value)
    average_best_objective <- mean(group$best_value)
    data.frame(
      nodes = key$nodes,
      edges = key$edges,
      labels = key$labels,
      optimum = key$optimum,
      avg_cg_objective = round(average_cg_objective, 1L),
      avg_best_objective = round(average_best_objective, 1L),
      avg_time_seconds = round(mean(group$elapsed_seconds), 6L),
      num_optimal = sum(group$best_value == key$optimum),
      avg_gap_percent = round(100 * (average_best_objective - key$optimum) / key$optimum, 1L),
      instances = nrow(group),
      check.names = FALSE
    )
  })

  write.csv(do.call(rbind, rows), output_path, row.names = FALSE, quote = FALSE)
}

main <- function() {
  args <- parse_args()
  paths <- sort(list.files(args$instances_dir, pattern = "\\.mlst$", full.names = TRUE))
  if (length(paths) == 0L) stop("No .mlst instances found in ", args$instances_dir)

  dir.create(dirname(args$output), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(args$averages_output), recursive = TRUE, showWarnings = FALSE)
  results <- vector("list", length(paths))

  for (index in seq_along(paths)) {
    result <- solve_instance(
      read_mlst(paths[[index]]), args$alpha, args$beta, args$seed,
      args$feasibility_aware
    )
    results[[index]] <- result

    # Rewrite incrementally so completed rows survive an interrupted batch.
    detailed <- do.call(rbind, results[seq_len(index)])
    write.csv(detailed, args$output, row.names = FALSE, quote = FALSE)
    cat(sprintf(
      "[%03d/%03d] %s: greedy=%d cg=%d best=%d time=%.6fs\n",
      index, length(paths), result$instance, result$greedy_value,
      result$cg_value, result$best_value, result$elapsed_seconds
    ))
  }

  detailed <- do.call(rbind, results)
  write_averages(detailed, args$averages_output)
  cat("Results written to", args$output, "\n")
  cat("Averages written to", args$averages_output, "\n")
}

main()
