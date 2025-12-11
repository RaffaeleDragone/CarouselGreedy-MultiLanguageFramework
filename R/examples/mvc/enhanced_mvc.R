# for file_path_sans_ext
library(tools)  # for file_path_sans_ext
# Carousel Greedy library already loaded
devtools::load_all()

# ---------------------------------------------------------------------------
# read_instance()
# Variant that directly returns the adjacency MATRIX 0/1 and the
# degree vector; useful for testing the “matrix + degree” implementation.
# ---------------------------------------------------------------------------
read_instance <- function(file) {
  lines <- readLines(file)
  n <- 0
  edges <- list()
  for (line in lines) {
    if (startsWith(line, "p")) {
      n <- as.integer(strsplit(trimws(line), "\\s+")[[1]][3])
    } else if (startsWith(line, "e")) {
      parts <- as.integer(strsplit(trimws(line), "\\s+")[[1]][2:3])
      edges[[length(edges) + 1]] <- parts
    }
  }
  mat <- matrix(0L, n, n)
  for (e in edges) {
    u <- e[1]; v <- e[2]
    mat[u, v] <- 1L
    mat[v, u] <- 1L
  }
  list(adj = mat, num_nodes = n, degree = rowSums(mat))
}

# ---------------------------------------------------------------------------
# Helper (matrix): update cache using only the adjacency matrix
# ---------------------------------------------------------------------------
vc_update_cache_mat <- function(cache, graph, solution) {
  n   <- graph$num_nodes
  adj <- graph$adj         # 0/1 matrix

  # if solution does not change, exit
  if (!is.null(cache$last_solution) && identical(cache$last_solution, solution))
    return(invisible(NULL))

  # --- O(n) version: compute added/removed using logical vectors ---
  curr_vec <- if (is.list(solution)) unlist(solution, FALSE) else solution
  curr_mask <- logical(n)
  if (length(curr_vec)) curr_mask[curr_vec] <- TRUE

  if (is.null(cache$in_cover)) {
    prev_mask <- logical(n)
  } else {
    prev_mask <- cache$in_cover
  }

  added   <- which(!prev_mask &  curr_mask)
  removed <- which( prev_mask & !curr_mask)

  # initialize at first run
  if (is.null(cache$in_cover)) {
    cache$in_cover        <- logical(n)
    cache$uncovered_degree<- graph$degree  # initial “uncovered” degree
  }

  in_cover <- cache$in_cover
  deg      <- cache$uncovered_degree

  # ---------- additions ----------
  for (u in added) {
    if (!in_cover[u]) {
      in_cover[u] <- TRUE
      neigh <- which(adj[u, ] == 1L)
      open  <- neigh[!in_cover[neigh]]
      deg[open] <- deg[open] - 1L
      deg[u] <- 0L
    }
  }

  # ---------- removals ----------
  for (u in removed) {
    if (in_cover[u]) {
      in_cover[u] <- FALSE
      neigh <- which(adj[u, ] == 1L)
      open  <- neigh[!in_cover[neigh]]
      deg[open] <- deg[open] + 1L
      # new degree of u = edges with neighbors not in cover
      deg[u] <- length(open)
    }
  }

  cache$last_solution     <- solution
  cache$in_cover          <- in_cover
  cache$uncovered_degree  <- deg
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Callbacks based on MATRIX + degree vector
# ---------------------------------------------------------------------------
vc_greedy_eval_mat <- function(self, solution, candidate) {
  cache <- self$data$cache
  graph <- self$data$graph
  vc_update_cache_mat(cache, graph, solution)
  cache$uncovered_degree[candidate]
}

vc_is_admissible_mat <- function(self, solution) {
  cache <- self$data$cache
  graph <- self$data$graph
  vc_update_cache_mat(cache, graph, solution)
  all(cache$uncovered_degree == 0L)
}

# ---------------------------------------------------------------------------
# Example execution on a single instance
# ---------------------------------------------------------------------------
# This script demonstrates how to apply the Carousel Greedy library
# to the Minimum Vertex Cover problem. It loads one example instance
# and compares a simple greedy heuristic with the Carousel Greedy algorithm.
# ---------------------------------------------------------------------------

# Path of the instance (relative to this example folder)
base_dir <- dirname(normalizePath(sys.frame(1)$ofile))
instance_path <- file.path(base_dir, "data", "100_nodes.mis")

cat("Loading instance:", instance_path, "\n")
graphM <- read_instance(instance_path)
cacheM <- new.env(parent = emptyenv())
dataM  <- list(graph = graphM, cache = cacheM)
elemsM <- seq_len(graphM$num_nodes)


# --- Carousel Greedy --------------------------------------------------------
cat("\nRunning Carousel Greedy algorithm...\n")
cgM <- carousel_greedy(
  test_feasibility   = vc_is_admissible_mat,
  greedy_function    = vc_greedy_eval_mat,
  candidate_elements = elemsM,
  data   = dataM,
  alpha  = 10,
  beta   = 0.1,
  random_tie_break = TRUE,
  seed = 1
)
cg_start <- Sys.time()
best_solution <- cgM$minimize()
cg_end <- Sys.time()
cg_time <- as.numeric(difftime(cg_end, cg_start, units = "secs"))

greedy_solution = cgM$greedy_solution
cg_solution = cgM$cg_solution
cat("Greedy solution size:", length(greedy_solution),"\n")
cat("Carousel Greedy solution size:", length(cg_solution),
    "\n")
cat("Time:",cg_time, "s\n")