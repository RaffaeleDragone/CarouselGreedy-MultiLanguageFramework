"""This script implements a basic version of the Carousel Greedy algorithm for solving the Minimum Vertex Cover problem."""

import os
import time
import csv

import random

import networkx as nx


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

def greedy_algorithm(matrix, n, degrees):
    """
    Executes the greedy algorithm to find a vertex cover.

    Parameters:
    - matrix (list of list of int): The adjacency matrix.
    - n (int): Number of nodes.
    - degrees (list of int): Degree of each node.

    Returns:
    - solution (list of int): List of nodes in the vertex cover.
    """
    # Create a copy of the matrix and degrees to avoid modifying the originals

    # List to store the solution
    solution = []

    while max(degrees) > 0:
        # Find the node with maximum degree
        max_degree = max(degrees)
        min_degree = min(degrees)
        if min_degree < 0:
            print("********* MIN DEGREE < 0 ")

        solution_set = set(solution)
        candidates = []
        for i in range(n):
            if (i not in solution_set) and degrees[i] == max_degree:
                candidates.append(i)

        # Choose a candidate randomly
        max_degree_node = random.choice(candidates)

        # Add the node to the solution
        solution.append(max_degree_node)

        # Set the degree of the selected node to 0
        degrees[max_degree_node] = 0

        # Update the degrees of neighbors and the matrix
        for i in range(n):
            if matrix[max_degree_node][i] == 1:
                # Decrement the degree of the neighbor
                degrees[i] -= 1
                # Update the matrix by removing edges
                matrix[max_degree_node][i] = 0
                matrix[i][max_degree_node] = 0

    return solution

def carousel_greedy(init_matrix, matrix, n, greedy_solution, alpha, beta):
    """
    Executes the Carousel Greedy algorithm to improve a solution.

    Parameters:
    - init_matrix (list of list of int): The initial adjacency matrix.
    - matrix (list of list of int): The current adjacency matrix.
    - n (int): Number of nodes.
    - greedy_solution (list of int): Initial solution from greedy algorithm.
    - alpha (int): Parameter controlling iterations.
    - beta (float): Fraction of elements to remove.

    Returns:
    - solution (list of int): Improved solution.
    """
    # Calculate how many elements to remove (beta%)
    elements_to_remove = int(len(greedy_solution) * beta)
    # Remove the last beta% elements
    removed_nodes = greedy_solution[-elements_to_remove:]
    removed_nodes.reverse()
    solution = greedy_solution[:-elements_to_remove]

    # Restore the matrix for the removed nodes
    for node in removed_nodes:
        for i in range(n):
            if i not in solution:
                if init_matrix[node][i] == 1:
                    matrix[node][i] = init_matrix[node][i]
                    matrix[i][node] = init_matrix[i][node]

    # Initialize the data structures
    current_degrees = [sum(row) for row in matrix]

    n_iter = len(greedy_solution) * alpha

    for _ in range(n_iter):
        # Remove the oldest element inserted in solution
        if len(solution) > 0:
            node_to_remove = solution.pop(0)
            solution_set = set(solution)
            for j in range(n):
                if init_matrix[node_to_remove][j] == 1:
                    if j not in solution_set:
                        matrix[node_to_remove][j] = init_matrix[node_to_remove][j]
                        matrix[j][node_to_remove] = init_matrix[j][node_to_remove]
                        current_degrees[j] += 1
                        current_degrees[node_to_remove] += 1

        max_degree = max(current_degrees)
        candidates = []
        for i in range(n):
            if current_degrees[i] == max_degree and i not in solution:
                candidates.append(i)

        # Choose a candidate randomly
        max_degree_node = random.choice(candidates)

        # Add the node to the solution
        solution.append(max_degree_node)

        # Set the degree of the selected node to 0
        current_degrees[max_degree_node] = 0

        # Update the degrees of neighbors and the matrix
        for i in range(n):
            if matrix[max_degree_node][i] == 1:
                # Decrement the degree of the neighbor
                current_degrees[i] -= 1
                # Update the matrix by removing edges
                matrix[max_degree_node][i] = 0
                matrix[i][max_degree_node] = 0

    while max(current_degrees) > 0:
        print("************** Complete Phase")
        max_degree = max(current_degrees)
        candidates = []
        for i in range(n):
            if (i not in solution) and current_degrees[i] == max_degree:
                candidates.append(i)

        # Choose a candidate randomly
        max_degree_node = random.choice(candidates)

        # Add the node to the solution
        solution.append(max_degree_node)

        # Set the degree of the selected node to 0
        current_degrees[max_degree_node] = 0

        # Update the degrees of neighbors and the matrix
        for i in range(n):
            if matrix[max_degree_node][i] == 1:
                # Decrement the degree of the neighbor
                current_degrees[i] -= 1
                # Update the matrix by removing edges
                matrix[max_degree_node][i] = 0
                matrix[i][max_degree_node] = 0
    return solution


def check_feasibility(cg_solution, matrix,n):
    """
    Checks if the given solution is a feasible vertex cover.

    Parameters:
    - cg_solution (list of int): The proposed solution.
    - file_path (str): Path to the input file.

    Returns:
    - bool: True if solution is feasible, False otherwise.
    """
    # Read the adjacency matrix
    for el in cg_solution:
        for j in range(n):
            matrix[el][j] = 0
            matrix[j][el] = 0

    for i in range(n):
        for j in range(n):
            if matrix[i][j] == 1:
                return False
    return True

def main():
    # Set the file path for the input graph instance
    file_path = 'data/100_nodes.mis'  # Change this to your actual file path

    # Read the graph from the file
    matrix, n, degrees = read_adjacency_matrix_from_file(file_path)
    init_matrix = [row[:] for row in matrix]

    random.seed(1)  # 1 is the seed to set

    greedy_solution = greedy_algorithm(matrix, n, degrees)

    cg_solution = carousel_greedy(init_matrix, matrix, n, greedy_solution, alpha=10, beta=0.1)

    print("Greedy solution Size : ", len(greedy_solution))
    print("CG solution Size : ", len(cg_solution))

if __name__ == "__main__":
    """
    Manual implementation of the Carousel Greedy (CG) algorithm for the Minimum Vertex Cover problem.

    This version builds the CG logic directly within the script without relying on an external library.
    It maintains an updated graph representation that reflects the current solution at each iteration,
    avoiding full reinitialization of the graph. This allows efficient feasibility checks and solution updates,
    improving performance compared to the basic version.
    """
    main()
