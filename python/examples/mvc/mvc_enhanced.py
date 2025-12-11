"""
This script implements the Carousel Greedy heuristic for solving the Minimum Vertex Cover problem.
It reads graph instances from files, applies the heuristic, and writes the results to a CSV file.
"""

from py_carouselgreedy import carousel_greedy
import time
import networkx as nx


# Global Vars
global_matrix = None
global_degrees = None
global_solution = None

def initialize_globals(matrix, degrees):
    """
    Initialize global variables used in the heuristic.

    Parameters:
    - matrix: The adjacency matrix of the graph.
    - degrees: The list of degrees for each node in the graph.
    """
    global global_matrix, global_degrees, global_solution
    global_matrix = matrix
    global_degrees = degrees
    global_solution = []


def my_feasibility_function(cg_instance, solution):
    """
    Check if the current solution is feasible, i.e., if it forms a vertex cover.

    Parameters:
    - cg_instance: The Carousel Greedy instance containing graph data.
    - solution: The current solution set of nodes.

    Returns:
    - True if the solution is feasible (no uncovered edges), False otherwise.
    """
    global global_matrix, global_solution, global_degrees

    if (len(global_solution) == len(solution) and global_solution == solution):
       max_degree = max(global_degrees)
    else:
        # Find differences between current and previous solutions
        current_set = set(solution)
        previous_set = set(global_solution)

        removed = previous_set - current_set
        inserted = current_set - previous_set
        n = cg_instance.data["n_nodes"]
        if(len(removed) > 0):
            original_matrix = cg_instance.data["original_matrix"]
            removed_set = set()
            # Reinsert removed nodes into the graph
            for node in removed:
                for j in range(n):
                    if (original_matrix[node][j] == 1):
                        if(j not in current_set):
                            if ((str(node) + "_" + str(j)) not in removed_set):
                                global_matrix[node][j] = original_matrix[node][j]
                                global_matrix[j][node] = original_matrix[j][node]
                                global_degrees[j] += 1
                                global_degrees[node] += 1
                                removed_set.add(str(node) + "_" + str(j))
                                removed_set.add(str(j) + "_" + str(node))
        # Remove added nodes from the graph
        for node in inserted:
            global_degrees[node] = 0
            # Update degrees of neighbors and adjacency matrix
            for i in range(n):
                if global_matrix[node][i] == 1:
                    # Decrement degree of neighbor
                    global_degrees[i] -= 1
                    # Remove edges from the matrix
                    global_matrix[node][i] = 0
                    global_matrix[i][node] = 0
        global_solution = solution[:]
        max_degree = max(global_degrees)
    return max_degree == 0


def my_greedy_function(cg_instance, solution, candidate):
    """
    Evaluate the greedy function value for a candidate node.

    Parameters:
    - cg_instance: The Carousel Greedy instance containing graph data.
    - solution: The current solution set of nodes.
    - candidate: The candidate node to evaluate.

    Returns:
    - The degree of the candidate node in the current graph state.
    """
    global global_matrix, global_degrees, global_solution
    if (len(global_solution) == len(solution) and global_solution == solution):
        return global_degrees[candidate]
    else:
        # Find differences between current and previous solutions
        current_set = set(solution)
        previous_set = set(global_solution)

        removed = previous_set - current_set
        inserted = current_set - previous_set
        n = cg_instance.data["n_nodes"]
        # Reinsert removed nodes into the graph
        if(len(removed) > 0):
            removed_set = set()
            original_matrix = cg_instance.data["original_matrix"]
            for node in removed:
                for j in range(n):
                    if (original_matrix[node][j] == 1):
                        if(j not in current_set):
                            if ((str(node) + "_" + str(j)) not in removed_set):
                                global_matrix[node][j] = original_matrix[node][j]
                                global_matrix[j][node] = original_matrix[j][node]
                                global_degrees[j] += 1
                                global_degrees[node] += 1
                                removed_set.add(str(node) + "_" + str(j))
                                removed_set.add(str(j) + "_" + str(node))
        # Remove added nodes from the graph
        for node in inserted:
            global_degrees[node] = 0
            # Update degrees of neighbors and adjacency matrix
            for i in range(n):
                if global_matrix[node][i] == 1:
                    # Decrement degree of neighbor
                    global_degrees[i] -= 1
                    # Remove edges from the matrix
                    global_matrix[node][i] = 0
                    global_matrix[i][node] = 0
        global_solution = solution[:]
        return global_degrees[candidate]



def read_adjacency_matrix_from_file(file_path):
    """
    Read the adjacency matrix and node degrees from a graph file.

    Parameters:
    - file_path: Path to the graph file.

    Returns:
    - matrix: The adjacency matrix of the graph.
    - n: Number of nodes in the graph.
    - degrees: List of degrees for each node.
    """
    with open(file_path, 'r') as f:
        first_line = f.readline().strip().split()
        n = int(first_line[2])
        matrix = [[0 for _ in range(n)] for _ in range(n)]
        for line in f:
            if line.startswith('e'):
                _, u, v = line.strip().split()
                u, v = int(u) - 1, int(v) - 1
                matrix[u][v] = 1
                matrix[v][u] = 1

    # Calculate degrees of nodes
    degrees = [sum(row) for row in matrix]

    return matrix, n, degrees



def check_feasibility(cg_solution, file_path):
    """
    Check if the given solution is a valid vertex cover for the graph in the file.

    Parameters:
    - cg_solution: List of nodes in the solution.
    - file_path: Path to the graph file.

    Returns:
    - True if the solution covers all edges, False otherwise.
    """
    # Read the adjacency matrix
    matrix, n, degrees = read_adjacency_matrix_from_file(file_path)

    for el in cg_solution:
        for j in range(n):
            matrix[el][j] = 0
            matrix[j][el] = 0

    for i in range(n):
        for j in range(n):
            if(matrix[i][j] == 1):
                return False
    return True


def main():
    matrix, n, degrees = read_adjacency_matrix_from_file("data/100_nodes.mis")
    original_matrix = [row[:] for row in matrix]

    # Initialize global variables
    initialize_globals(matrix, degrees)

    candidate_elements = list(range(n))
    data = {"original_matrix": original_matrix, "n_nodes": n}

    # Create CarouselGreedy instance
    cg = carousel_greedy(
        test_feasibility=my_feasibility_function,
        greedy_function=my_greedy_function,
        candidate_elements=candidate_elements,
        data=data,
        seed=1
    )
    cg.random_tie_break = True

    # Time the CG solution
    start_time = time.time()
    best_solution = cg.minimize(alpha=10, beta=0.1)
    end_time = time.time() - start_time
    cg_solution = cg.cg_solution
    greedy_solution = cg.greedy_solution
    print("Greedy solution Size : ", len(greedy_solution))
    print("CG solution Size : ", len(cg_solution))
    print("Time : ", str(round(end_time,2)))


if __name__ == "__main__":
    """
    Advanced implementation of the Carousel Greedy (CG) library on the Minimum Vertex Cover problem.

    Unlike the basic version, this implementation maintains a dynamically updated graph state that reflects
    the current solution. This avoids the need to recompute or reinitialize the graph structure at each
    iteration, thereby improving computational efficiency and enabling seamless feasibility checks and
    greedy evaluations.

    The script demonstrates how to use this enhanced logic to compare the performance of the CG algorithm
    against a standard greedy solution.
    """
    main()
