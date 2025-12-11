from typing import List, Any, Callable, Optional, Dict
import logging
import random

logger = logging.getLogger(__name__)
class carousel_greedy:
    def __init__(self,
                 test_feasibility: Callable[['carousel_greedy', List[Any]], bool],
                 greedy_function: Callable[['carousel_greedy', List[Any], Any], float],
                 candidate_elements: List[Any] = None,
                 alpha: int=10,
                 beta: float=0.2,
                 data: Optional[Any] = None,
                 random_tie_break: bool = True,
                 seed: Optional[int] = 42):
        '''
        Initializes the Carousel Greedy algorithm.
        :param alpha: Integer, multiplier to determine the iterations of the iterative phase.
        :param beta: Percentage (between 0 and 1) of elements to remove from the greedy solution.
        :param test_feasibility: Function that verifies whether the current solution is feasible.
        :param greedy_function: Function that evaluates a candidate.
        :param data: Additional data/context needed by the user-defined functions (e.g., graph structure).
        :param candidate_elements: List of candidate elements for building the solution.
        :param random_tie_break: Whether to use random tie-breaking among equally scored candidates.
        :param seed: Optional seed for reproducible randomness.
        '''
        # Validate inputs
        if not isinstance(alpha, int) or alpha <= 0:
            raise ValueError("alpha must be a positive integer")
        if not (0 <= beta <= 1):
            raise ValueError("beta must be between 0 and 1")
        if candidate_elements is None:
            raise ValueError("candidate_elements must be provided")

        # Initialize internal parameters and algorithm settings
        self.alpha = alpha
        self.beta = beta
        self.test_feasibility = test_feasibility
        self.greedy_function = greedy_function
        self.data = data
        self.candidate_elements = candidate_elements
        self.solution: List[Any] = []  # Current working solution
        self.random_tie_break = random_tie_break
        self.seed = seed
        self.greedy_solution: List[Any] = []  # Solution from the greedy construction phase
        self.cg_solution: List[Any] = []  # Final solution after iterative improvement
        self.iteration=0
        self._rand=None

        # Set up random generator using seed if provided
        if self.seed is not None:
            self._rand = random.Random(self.seed)
        else:
            self._rand = random

    def _select_best_candidate(self) -> Any:
        '''
            Selects the best candidate element to add to the current solution,
            based on the greedy evaluation function.

            Returns:
                The selected candidate element, or None if no eligible candidates remain.
        '''
        # Build a set of elements already included in the current solution
        solution_set = set(self.solution)
        # Filter out candidates that are already part of the solution
        eligible_candidates = [c for c in self.candidate_elements if c not in solution_set]

        # If no eligible candidates remain, return None
        if not eligible_candidates:
            return None
        if self.random_tie_break:
            # Evaluate each candidate using the greedy function
            scores = {
                candidate: score
                for candidate in eligible_candidates
                if (score := self.greedy_function(self, self.solution, candidate)) is not None
            }
            # Select candidates with the highest score
            max_score = max(scores.values())
            best_candidates = [candidate for candidate, score in scores.items() if score == max_score]
            # Randomly choose among the best candidates
            return self._rand.choice(best_candidates)
        else:
            # Select the single best candidate deterministically
            best_candidate = None
            best_score = float('-inf')
            for candidate in eligible_candidates:
                score = self.greedy_function(self, self.solution, candidate)
                if score is not None and score > best_score:
                    best_score = score
                    best_candidate = candidate
            return best_candidate

    def _construction_phase(self):
        '''
        Phase 1: Constructs an initial solution using a greedy approach.
        - For minimization: adds candidates one by one until the solution becomes feasible.
        - For maximization: keeps adding candidates as long as the solution remains feasible.
        '''
        logger.info('Starting construction phase.')
        if self.problem_type == 'MIN':
            # In minimization, add elements until the solution becomes feasible
            while not self.test_feasibility(self, self.solution):
                candidate = self._select_best_candidate()
                if candidate is None:
                    logger.warning('No eligible candidate found in construction phase, breaking out.')
                    break
                self.solution.append(candidate)
        elif self.problem_type == 'MAX':
            # In maximization, keep adding feasible candidates as long as possible
            while True:
                candidate = self._select_best_candidate()
                if candidate is None:
                    logger.warning('No eligible candidate found in construction phase, breaking out.')
                    break
                self.solution.append(candidate)
        logger.info('Construction phase complete, initial greedy solution length: %s', len(self.solution))
        # Return a copy of the constructed solution to avoid external modification
        return self.solution.copy()

    def _removal_phase(self):
        '''
        Phase 2: Removal of a fraction (beta) of elements from the greedy solution.

        This phase removes the last β × |solution| elements from the current solution.
        If removing that many elements would leave the solution empty, it ensures at least one element remains.
        '''
        logger.info('Starting removal phase, attempting to remove beta percentage of elements.')
        # Determine how many elements to remove
        n_remove = int(len(self.solution) * self.beta)
        # Ensure the solution is not emptied entirely
        if len(self.solution) - n_remove < 1:
            logger.warning('Removal phase would remove all elements; adjusting to leave two element.')
            n_remove = len(self.solution) - 2

        # Remove the selected elements from the tail of the solution
        if n_remove > 0:
            self.solution = self.solution[:-n_remove]
        logger.info('Removal phase complete, solution length: %s', len(self.solution))


    def _iterative_phase(self, iterations: int):

        '''
            Phase 3: Iterative replacement of elements in the solution.

            For a given number of iterations:
            - An element is removed from the head of the solution.
            - A new candidate is selected and added using the greedy criterion.
            - For minimization: the candidate is always added.
            - For maximization: the candidate is added only if the solution remains feasible.
        '''
        logger.info('Starting iterative phase with %s iterations.', iterations)
        if self.problem_type == 'MIN':
            for _ in range(iterations):
                self.iteration += 1
                # Remove the first element (head) of the solution
                if self.solution:
                    self.solution.pop(0)

                if self.test_feasibility(self, self.solution):
                    continue
                # Select a new candidate based on greedy criterion
                candidate = self._select_best_candidate()
                if candidate is None:
                    logger.warning('No eligible candidate found during iterative phase, breaking out.')
                    break

                # Always add the new candidate
                self.solution.append(candidate)
        elif self.problem_type == 'MAX':
            for _ in range(iterations):
                self.iteration += 1
                # Remove the first element (head) of the solution
                if self.solution:
                    self.solution.pop(0)

                # Evaluate feasible candidates (those that keep the solution feasible when added)
                feasible_candidates = []
                solution_set = set(self.solution)
                for candidate in self.candidate_elements:
                    if candidate not in solution_set:
                        temp_solution = self.solution.copy()
                        temp_solution.append(candidate)
                        if self.test_feasibility(self, temp_solution):
                            feasible_candidates.append(candidate)

                # If no feasible candidates, stop
                if not feasible_candidates:
                    break

                # Select the best candidate among feasible ones
                if self.random_tie_break:
                    scores = {
                        candidate: self.greedy_function(self, self.solution, candidate)
                        for candidate in feasible_candidates
                    }
                    max_score = max(scores.values())
                    best_candidates = [candidate for candidate, score in scores.items() if score == max_score]
                    selected = self._rand.choice(best_candidates)
                else:
                    best_candidate = None
                    best_score = float('-inf')
                    for candidate in feasible_candidates:
                        score = self.greedy_function(self, self.solution, candidate)
                        if score > best_score:
                            best_score = score
                            best_candidate = candidate
                    selected = best_candidate

                # Add the selected candidate to the solution
                self.solution.append(selected)
        logger.info('Iterative phase complete, solution length: %s', len(self.solution))

    def _completion_phase(self):
        '''
        Phase 4: Completion.

        For minimization:
            Add candidates until the solution becomes feasible.
        For maximization:
            Add candidates as long as the resulting solution remains feasible.
        '''
        logger.info('Starting completion phase.')
        if self.problem_type == 'MIN':
            # Keep adding the best candidate until the solution is feasible
            while not self.test_feasibility(self, self.solution):
                candidate = self._select_best_candidate()
                if candidate is None:
                    logger.warning('No eligible candidate found in completion phase, breaking out.')
                    break
                self.solution.append(candidate)
        elif self.problem_type == 'MAX':
            # Try to add as many feasible candidates as possible
            while True:
                feasible_candidates = []
                solution_set = set(self.solution)

                # Identify feasible candidates not already in the solution
                for candidate in self.candidate_elements:
                    if candidate not in solution_set:
                        temp_solution = self.solution.copy()
                        temp_solution.append(candidate)
                        if self.test_feasibility(self, temp_solution):
                            feasible_candidates.append(candidate)

                # Stop if no feasible candidate can be added
                if not feasible_candidates:
                    logger.warning('No eligible candidate found in completion phase, breaking out.')
                    break

                # Select the best feasible candidate to add
                if self.random_tie_break:
                    scores = {
                        candidate: self.greedy_function(self, self.solution, candidate)
                        for candidate in feasible_candidates
                    }
                    max_score = max(scores.values())
                    best_candidates = [candidate for candidate, score in scores.items() if score == max_score]
                    selected = self._rand.choice(best_candidates)
                else:
                    best_candidate = None
                    best_score = float('-inf')
                    for candidate in feasible_candidates:
                        score = self.greedy_function(self, self.solution, candidate)
                        if score > best_score:
                            best_score = score
                            best_candidate = candidate
                    selected = best_candidate

                # Add the selected candidate to the solution
                self.solution.append(selected)
        logger.info('Completion phase complete, final solution length: %s', len(self.solution))

    def greedy_minimize(self) -> List[Any]:
        """
            Executes only the greedy construction phase of the algorithm for a minimization problem.

            This method sets the problem type to 'MIN' and runs the construction phase to obtain
            an initial feasible solution. It stores this solution in self.greedy_solution
            and returns it.

            Returns:
                A feasible solution obtained using a greedy strategy.
        """
        self.problem_type = "MIN"
        logger.info('Running greedy_minimize: obtaining greedy solution for minimization.')
        tmp_break = self.random_tie_break
        self.random_tie_break=False
        # Run the greedy construction phase
        greedy_solution = self._construction_phase()

        # Store and return the result
        self.greedy_solution = greedy_solution.copy()
        self.random_tie_break=tmp_break
        return greedy_solution

    def greedy_maximize(self) -> List[Any]:
        """
            Executes only the greedy construction phase of the algorithm for a maximization problem.
            The final greedy solution is stored in self.greedy_solution and returned.

            Returns:
                A feasible solution obtained through a greedy strategy for maximization.
        """

        logger.info('Running greedy_maximize: obtaining greedy solution for maximization.')

        # Step 1: Build a feasible starting point using a minimization approach
        self.problem_type = "MIN"
        greedy_solution = self._construction_phase()
        self.solution = greedy_solution.copy()

        # Step 2: Extend the solution using maximization strategy
        self.problem_type = "MAX"
        greedy_solution = self._construction_phase()

        # Store and return the final greedy solution
        self.greedy_solution = greedy_solution.copy()
        return greedy_solution

    def minimize(self, alpha: Optional[int] = None, beta: Optional[float] = None) -> List[Any]:
        """
            Executes the Carousel Greedy algorithm for a minimization problem.

            Workflow:
            1. Constructs an initial greedy solution.
            2. Removes a percentage (beta) of elements from it.
            3. Applies iterative replacement to improve the solution.
            4. Completes the solution if it becomes infeasible.
            5. Returns the better between the greedy and final solution.

            Parameters:
                alpha (Optional[int]): Overrides the default number of iterations (alpha * |solution|) if provided.
                beta (Optional[float]): Overrides the default fraction of elements to remove, if provided.

            Returns:
                List[Any]: The best feasible solution found (the onw with the smaller number of elements between greedy and final).
        """

        # Apply custom alpha and beta if provided, else use defaults
        effective_alpha = alpha if alpha is not None else self.alpha
        effective_beta = beta if beta is not None else self.beta
        tmp_alpha = self.alpha
        tmp_beta = self.beta
        self.alpha = effective_alpha
        self.beta = effective_beta
        self.problem_type = "MIN"

        logger.info('Optimizing (minimize) using Carousel Greedy.')

        # Step 1: Construct the greedy solution
        greedy_solution = self.greedy_minimize()
        self.greedy_solution=greedy_solution

        # Step 2: Remove a portion of the solution (removal phase)
        initial_length = len(self.greedy_solution)
        self._removal_phase()

        # Step 3: Perform iterative replacements (iterative phase)
        iterations = self.alpha * initial_length
        self._iterative_phase(iterations)
        self.random_tie_break=False
        # Step 4: Finalize the solution (completion phase)
        self._completion_phase()
        self.random_tie_break=True
        # Store final solution
        self.cg_solution = self.solution

        # Step 5: Return the best solution
        best_solution = self.greedy_solution if len(self.greedy_solution) < len(self.cg_solution) else self.cg_solution
        logger.info('Minimization complete, returning best solution.')

        # Restore original alpha and beta values
        self.alpha = tmp_alpha
        self.beta = tmp_beta
        return best_solution

    def maximize(self, alpha: Optional[int] = None, beta: Optional[float] = None) -> List[Any]:
        """
            Executes the Carousel Greedy algorithm for a maximization problem.

            Workflow:
            1. Constructs an initial greedy solution using greedy_maximize().
            2. Removes a percentage (beta) of elements from it.
            3. Applies iterative replacement to improve the solution.
            4. Completes the solution by adding more feasible elements.
            5. Returns the better between the greedy and final solution (the one with more elements).

            Parameters:
                alpha (Optional[int]): Overrides the default number of iterations (alpha * |solution|) if provided.
                beta (Optional[float]): Overrides the default fraction of elements to remove, if provided.

            Returns:
                List[Any]: The best feasible solution found (longest between greedy and final).
        """

        # Apply custom alpha and beta if provided
        effective_alpha = alpha if alpha is not None else self.alpha
        effective_beta = beta if beta is not None else self.beta

        # Save original values to restore later
        tmp_alpha = self.alpha
        tmp_beta = self.beta

        # Apply temporary values for this run
        self.alpha = effective_alpha
        self.beta = effective_beta
        self.problem_type="MAX"

        logger.info('Optimizing (maximize) using Carousel Greedy.')

        # Step 1: Construct the greedy solution
        greedy_solution = self.greedy_maximize()
        self.greedy_solution = greedy_solution.copy()

        # Step 2: Remove a portion of the solution (removal phase)
        initial_length = len(self.greedy_solution)
        self._removal_phase()

        # Step 3: Perform iterative replacements (iterative phase)
        iterations = self.alpha * initial_length
        self._iterative_phase(iterations)

        # Step 4: Finalize the solution (completion phase)
        self._completion_phase()

        # Store final solution
        self.cg_solution=self.solution

        # Step 5: Return the best solution (with more elements)
        best_solution = self.greedy_solution if len(self.greedy_solution) > len(self.cg_solution) else self.cg_solution
        logger.info('Maximization complete, returning best solution.')

        # Restore original alpha and beta values
        self.alpha = tmp_alpha
        self.beta = tmp_beta
        return best_solution