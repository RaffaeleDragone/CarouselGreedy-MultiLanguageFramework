# =============================================================================
#  carousel_greedy.R
#  Core implementation of the Carousel Greedy metaheuristic.
#  Author: Raffaele Dragone
#  License: BSD 3-Clause
#  Description:
#    This file defines the constructor and main logic of the Carousel Greedy
#    algorithm, including construction, removal, iterative, and completion phases.
# =============================================================================
#' Carousel Greedy Algorithm Constructor
#'
#' Creates a new Carousel Greedy object to solve optimization problems using a
#' greedy construction phase, followed by removal, iterative replacement, and completion phases.
#' The object returned is an environment containing all relevant methods.
#'
#' @param test_feasibility A user-defined function \code{f(self, solution)} that returns TRUE if the solution is feasible.
#' @param greedy_function A user-defined function \code{f(self, solution, candidate)} that returns a numeric score for a candidate.
#' @param alpha Integer. Multiplier used to compute the number of iterations in the iterative phase. Default is 10.
#' @param beta Numeric. Fraction (between 0 and 1) of elements to remove from the greedy solution. Default is 0.2.
#' @param candidate_elements A vector of elements (e.g., strings, integers) from which the solution is built.
#' @param data Optional. Additional data needed by your custom functions (e.g., a graph structure).
#' @param random_tie_break Logical. Whether to break ties randomly among candidates with the same score. Default is TRUE.
#' @param seed Optional. Integer seed for reproducibility (used in tie-breaking).
#'
#' @return An environment (object) containing the algorithm's state and methods:
#' \itemize{
#'   \item \code{construction_phase(problem_type)}: builds the initial solution (MIN or MAX).
#'   \item \code{removal_phase()}: removes a fraction \code{beta} of the current solution.
#'   \item \code{iterative_phase(iterations)}: improves the solution by replacing elements.
#'   \item \code{completion_phase()}: adds candidates to complete the solution.
#'   \item \code{greedy_minimize()}, \code{greedy_maximize()}: execute only the greedy phase.
#'   \item \code{minimize(alpha, beta)}, \code{maximize(alpha, beta)}: run the full algorithm.
#'   \item Fields: \code{solution}, \code{greedy_solution}, \code{cg_solution}, \code{alpha}, \code{beta}, etc.
#' }
#'
#' @examples
#' candidates <- c("A", "B", "C", "D", "E")
#' greedy_scores <- c(A = 5, B = 2, C = 4, D = 3, E = 1)
#' greedy_function <- function(self, solution, candidate) greedy_scores[[candidate]]
#' test_feasibility <- function(self, solution) length(solution) >= 3
#'
#' cg <- carousel_greedy(test_feasibility, greedy_function, candidate_elements = candidates)
#' result <- cg$minimize()
#' print(result)
#'
#' @export
carousel_greedy <- function(test_feasibility,
                                   greedy_function,
                                   alpha = 10,
                                   beta = 0.1,
                                   candidate_elements,
                                   data = NULL,
                                   random_tie_break = TRUE,
                                   seed = 42) {

  if (!is.numeric(alpha) || alpha <= 0) stop("alpha must be a positive integer")
  if (!(beta >= 0 && beta <= 1)) stop("beta must be between 0 and 1")
  if (missing(candidate_elements)) stop("candidate_elements must be provided")

  self <- new.env(parent = emptyenv())

  self$alpha <- alpha
  self$beta <- beta
  self$data <- data
  self$solution <- list()
  self$greedy_solution <- list()
  self$cg_solution <- list()
  self$random_tie_break <- random_tie_break
  self$seed <- seed
  self$iteration <- 0
  self$test_feasibility <- test_feasibility
  self$greedy_function <- greedy_function
  self$candidate_elements <- candidate_elements

  set.seed(seed)  # per random_tie_break con sample()

  self$select_best_candidate <- function() {
    # 1) Costruisci un vettore logico che indica se il candidato è già in soluzione
    #    (evita allocazioni di setdiff a ogni chiamata)
    if (length(self$candidate_elements) == 0) return(NULL)

    # self$solution può essere lista o vettore; normalizziamo in intero/char
    sol_vec <- if (is.list(self$solution)) unlist(self$solution, use.names = FALSE) else self$solution
    in_solution <- self$candidate_elements %in% sol_vec

    # Se tutti i candidati sono già nella soluzione → NULL
    if (all(in_solution)) return(NULL)

    # 2) Scan lineare con "best‑so‑far": evita sapply/allocazione vettore scores
    best_score <- -Inf
    best_cands <- vector(mode = mode(self$candidate_elements), length = 0)

    # iteriamo direttamente sugli indici per evitare subset che crea copia
    for (idx in which(!in_solution)) {
      cand <- self$candidate_elements[[idx]]
      score <- self$greedy_function(self, self$solution, cand)

      if (is.na(score)) next         # sicurezza: salta candidati con punteggio NA
      if (score > best_score) {
        best_score <- score
        best_cands <- cand
      } else if (score == best_score) {
        best_cands <- c(best_cands, cand)
      }
    }

    if (length(best_cands) == 0) return(NULL)

    # 3) Tie‑break
    if (self$random_tie_break && length(best_cands) > 1) {
      return(sample(best_cands, 1))
    } else {
      return(best_cands[[1]])
    }
  }

  #' @description Greedy construction phase (MIN or MAX mode)
  self$construction_phase <- function(problem_type = "MIN") {
    self$problem_type <- problem_type

    if (problem_type == "MIN") {
      # Add elements until the solution becomes feasible
      while (!self$test_feasibility(self, self$solution)) {
        candidate <- self$select_best_candidate()
        if (is.null(candidate)) break
        self$solution <- append(self$solution, candidate)
      }
    } else if (problem_type == "MAX") {
      # Keep adding candidates as long as the solution stays feasible
      repeat {
        candidate <- self$select_best_candidate()
        if (is.null(candidate)) break
        self$solution <- append(self$solution, candidate)
      }
    }

    return(self$solution)
  }

  #' @description Removal phase: removes the last beta% of the solution
  self$removal_phase <- function() {
    sol_length <- length(self$solution)
    n_remove <- floor(sol_length * self$beta)

    if (sol_length - n_remove < 1) {
      n_remove <- sol_length - 1
    }

    if (n_remove > 0) {
      self$solution <- self$solution[1:(sol_length - n_remove)]
    }

    invisible(NULL)
  }

  #' @description Iterative phase: tries to improve the solution over a number of iterations
  #' @param iterations Number of iterations to perform
  self$iterative_phase <- function(iterations) {
    if (self$problem_type == "MIN") {
      for (i in seq_len(iterations)) {
        self$iteration <- self$iteration + 1

        # Remove head
        if (length(self$solution) > 0) {
          self$solution <- self$solution[-1]
        }

        candidate <- self$select_best_candidate()
        if (is.null(candidate)) break

        self$solution <- append(self$solution, candidate)
      }

    } else if (self$problem_type == "MAX") {
      for (i in seq_len(iterations)) {
        self$iteration <- self$iteration + 1

        if (length(self$solution) > 0) {
          self$solution <- self$solution[-1]
        }

        # Build feasible candidates
        feasible_candidates <- list()
        for (candidate in self$candidate_elements) {
          if (!(candidate %in% self$solution)) {
            temp_solution <- append(self$solution, candidate)
            if (self$test_feasibility(self, temp_solution)) {
              feasible_candidates <- append(feasible_candidates, list(candidate))
            }
          }
        }

        if (length(feasible_candidates) == 0) break

        scores <- sapply(feasible_candidates, function(c) self$greedy_function(self, self$solution, c))
        max_score <- max(scores)
        best_candidates <- feasible_candidates[scores == max_score]

        if (self$random_tie_break) {
          selected_index <- sample(seq_along(best_candidates), 1)
          selected <- best_candidates[[selected_index]]
        } else {
          selected <- best_candidates[[1]]
        }

        self$solution <- append(self$solution, selected)
      }
    }

    invisible(NULL)
  }

  #' @description Completion phase: ensures the solution is feasible
  self$completion_phase <- function() {
    if (self$problem_type == "MIN") {
      while (!self$test_feasibility(self, self$solution)) {
        candidate <- self$select_best_candidate()
        if (is.null(candidate)) break
        self$solution <- append(self$solution, candidate)
      }

    } else if (self$problem_type == "MAX") {
      repeat {
        feasible_candidates <- list()
        for (candidate in self$candidate_elements) {
          if (!(candidate %in% self$solution)) {
            temp_solution <- append(self$solution, candidate)
            if (self$test_feasibility(self, temp_solution)) {
              feasible_candidates <- append(feasible_candidates, list(candidate))
            }
          }
        }

        if (length(feasible_candidates) == 0) break

        scores <- sapply(feasible_candidates, function(c) self$greedy_function(self, self$solution, c))
        max_score <- max(scores)
        best_candidates <- feasible_candidates[scores == max_score]

        if (self$random_tie_break) {
          selected_index <- sample(seq_along(best_candidates), 1)
          selected <- best_candidates[[selected_index]]
          #selected <- sample(best_candidates, 1)[[1]]
        } else {
          selected <- best_candidates[[1]]
        }

        self$solution <- append(self$solution, selected)
      }
    }

    invisible(NULL)
  }

  #' @description Executes the greedy construction phase for minimization
  #' @return A feasible solution built greedily
  self$greedy_minimize <- function() {
    self$solution <- list()
    self$problem_type <- "MIN"
    greedy_solution <- self$construction_phase("MIN")
    self$greedy_solution <- greedy_solution
    return(greedy_solution)
  }

  #' @description Executes the greedy construction phase for maximization
  #' @return A feasible solution built greedily
  self$greedy_maximize <- function() {
    self$solution <- list()

    # Step 1: Minimization to build a feasible base
    self$problem_type <- "MIN"
    greedy_solution <- self$construction_phase("MIN")
    self$solution <- greedy_solution

    # Step 2: Maximization to extend it
    self$problem_type <- "MAX"
    greedy_solution <- self$construction_phase("MAX")

    self$greedy_solution <- greedy_solution
    return(greedy_solution)
  }

  #' @description Full Carousel Greedy algorithm for minimization
  #' @param alpha Optional custom alpha
  #' @param beta Optional custom beta
  #' @return The best feasible solution found (smallest cardinality)
  self$minimize <- function(alpha = NULL, beta = NULL) {
    # Save temporary parameters
    tmp_alpha <- self$alpha
    tmp_beta <- self$beta

    # Apply overrides if provided
    self$alpha <- if (!is.null(alpha)) alpha else self$alpha
    self$beta <- if (!is.null(beta)) beta else self$beta

    self$problem_type <- "MIN"

    # Step 1: greedy phase
    greedy_solution <- self$greedy_minimize()

    # Step 2: removal phase
    initial_length <- length(greedy_solution)
    self$removal_phase()

    # Step 3: iterative phase
    iterations <- self$alpha * initial_length
    self$iterative_phase(iterations)

    # Step 4: completion phase
    self$completion_phase()

    # Step 5: select the best solution
    self$cg_solution <- self$solution
    best_solution <- if (length(self$greedy_solution) < length(self$cg_solution)) {
      self$greedy_solution
    } else {
      self$cg_solution
    }

    # Restore original parameters
    self$alpha <- tmp_alpha
    self$beta <- tmp_beta

    return(best_solution)
  }

  #' @description Full Carousel Greedy algorithm for maximization
  #' @param alpha Optional custom alpha
  #' @param beta Optional custom beta
  #' @return The best feasible solution found (largest cardinality)
  self$maximize <- function(alpha = NULL, beta = NULL) {
    tmp_alpha <- self$alpha
    tmp_beta <- self$beta

    self$alpha <- if (!is.null(alpha)) alpha else self$alpha
    self$beta <- if (!is.null(beta)) beta else self$beta

    self$problem_type <- "MAX"

    # Step 1: greedy phase
    greedy_solution <- self$greedy_maximize()

    # Step 2: removal phase
    initial_length <- length(greedy_solution)
    self$removal_phase()

    # Step 3: iterative phase
    iterations <- self$alpha * initial_length
    self$iterative_phase(iterations)

    # Step 4: completion phase
    self$completion_phase()

    # Step 5: return the best solution
    self$cg_solution <- self$solution
    best_solution <- if (length(self$greedy_solution) > length(self$cg_solution)) {
      self$greedy_solution
    } else {
      self$cg_solution
    }

    # Restore original parameters
    self$alpha <- tmp_alpha
    self$beta <- tmp_beta

    return(best_solution)
  }

  return(self)
}


