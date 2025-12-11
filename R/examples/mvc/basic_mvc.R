# ---------------------------------------------------------------------------
# Simple (no-cache) greedy and feasibility functions
# ---------------------------------------------------------------------------

# Compute the "gain" of adding a candidate node:
# the number of uncovered edges that would be covered if this node were added.
vc_greedy_simple <- function(self, solution, candidate) {
  graph <- self$data$graph
  adj   <- graph$adj
  n     <- graph$num_nodes

  # Get neighbors of candidate
  neighbors <- which(adj[candidate, ] == 1L)

  # Find edges still uncovered (both endpoints not yet in solution)
  uncovered <- neighbors[!neighbors %in% solution]

  # Score = number of edges newly covered by adding this candidate
  length(uncovered)
}

# Feasibility check: TRUE if all edges are covered by the solution
vc_feasible_simple <- function(self, solution) {
  graph <- self$data$graph
  adj   <- graph$adj
  n     <- graph$num_nodes

  for (i in seq_len(n)) {
    for (j in which(adj[i, ] == 1L)) {
      if (!(i %in% solution || j %in% solution)) {
        return(FALSE)  # edge (i,j) not covered
      }
    }
  }
  TRUE
}

# ---------------------------------------------------------------------------
# Example execution using the simplified greedy version
# ---------------------------------------------------------------------------
# This demonstrates how to apply the Carousel Greedy library
# with the "no-cache" greedy and feasibility callbacks.
# ---------------------------------------------------------------------------

base_dir <- dirname(normalizePath(sys.frame(1)$ofile))
instance_path <- file.path(base_dir, "data", "100_nodes.mis")

cat("Loading instance:", instance_path, "\n")
graphM <- read_instance(instance_path)
dataM  <- list(graph = graphM)
elemsM <- seq_len(graphM$num_nodes)

# --- Carousel Greedy --------------------------------------------------------
cat("\nRunning simplified Carousel Greedy algorithm...\n")
cgM <- carousel_greedy(
  test_feasibility   = vc_feasible_simple,
  greedy_function    = vc_greedy_simple,
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
cat("Greedy solution size:", length(greedy_solution), "\n")
cat("Carousel Greedy solution size:", length(cg_solution), "\n")
cat("Time:", cg_time, "s\n")