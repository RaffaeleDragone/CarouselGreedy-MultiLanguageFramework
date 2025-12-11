import networkx as nx
import logging
from py_carouselgreedy import carousel_greedy

# Configure the logger to display INFO-level messages
logging.basicConfig(level=logging.INFO)


def read_adjacency_matrix_from_file(file_path):
    """
    Reads a graph from a .mis file and returns a NetworkX graph.
    """
    graph = nx.Graph()
    with open(file_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("c"):
                continue
            parts = line.split()
            # 'p edge n m' → numero di nodi e archi
            if parts[0] == "p" and len(parts) >= 4:
                n = int(parts[2])
                continue
            # 'e u v' → arco
            if parts[0] == "e" and len(parts) >= 3:
                u, v = int(parts[1]), int(parts[2])
                graph.add_edge(u, v)
    n = graph.number_of_nodes()
    degrees = [d for _, d in graph.degree()]
    return graph, n, degrees

# Feasibility function for the Vertex Cover problem.
# A solution is feasible if every edge in the graph has at least one endpoint in the solution set.
def my_feasibility(cg_instance, solution):
    graph = cg_instance.data
    for (u, v) in graph.edges():
        if u not in solution and v not in solution:
            return False
    return True


# Greedy function for the Vertex Cover problem.
# This function evaluates a candidate node by counting how many currently uncovered edges it would cover if added to the solution.
def my_greedy(cg_instance, solution, candidate):
    graph = cg_instance.data
    uncovered = 0
    for (u, v) in graph.edges():
        if u not in solution and v not in solution:
            if candidate == u or candidate == v:
                uncovered += 1
    return uncovered


def main():
    # Read the graph from an edge list file instead of generating randomly
    file_path = "data/100_nodes.mis"
    G, n, degrees = read_adjacency_matrix_from_file(file_path)

    # The list of candidate elements consists of all nodes in the graph
    candidate_elements = list(G.nodes())

    # Create an instance of Carousel Greedy for the vertex cover problem.
    cg = carousel_greedy(
        test_feasibility=my_feasibility,
        greedy_function=my_greedy,
        data=G,
        candidate_elements=candidate_elements,
        seed=1
    )

    best_solution = cg.minimize(alpha=10, beta=0.1)
    cg_solution = cg.cg_solution
    greedy_solution = cg.greedy_solution
    print("Greedy solution Size : ", len(greedy_solution))
    print("CG solution Size : ", len(cg_solution))


if __name__ == '__main__':
    """
    Basic example of how to use the Carousel Greedy (CG) library on the Vertex Cover problem.

    This script reads a graph from a .mis file and applies the CG algorithm to find 
    a feasible vertex cover.

    Intended as a minimal working example to demonstrate usage of the CG library.
    
    For more advanced configurations, see the 'mvc_enhanced.py' example.
    """
    main()