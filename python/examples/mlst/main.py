"""Run Carousel Greedy on all Group II small MLST instances.

The Minimum Label Spanning Tree solution is represented by a list of labels.  A
solution is feasible when the subgraph induced by its labels is connected.
"""

from __future__ import annotations

import argparse
import csv
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

try:
    from py_carouselgreedy.py_carouselgreedy import carousel_greedy
except ModuleNotFoundError:
    # Permit direct execution from a source checkout without first installing it.
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from py_carouselgreedy.py_carouselgreedy import carousel_greedy


ALPHA = 50
BETA = 0.10
SEED = 42


class DisjointSet:
    """Small union-find implementation used by the MLST scoring functions."""

    def __init__(self, size: int) -> None:
        self.parent = list(range(size))
        self.rank = [0] * size
        self.components = size

    def copy(self) -> "DisjointSet":
        other = DisjointSet.__new__(DisjointSet)
        other.parent = self.parent.copy()
        other.rank = self.rank.copy()
        other.components = self.components
        return other

    def find(self, item: int) -> int:
        root = item
        while self.parent[root] != root:
            root = self.parent[root]
        while self.parent[item] != item:
            parent = self.parent[item]
            self.parent[item] = root
            item = parent
        return root

    def union(self, first: int, second: int) -> bool:
        root_first = self.find(first)
        root_second = self.find(second)
        if root_first == root_second:
            return False

        if self.rank[root_first] < self.rank[root_second]:
            root_first, root_second = root_second, root_first
        self.parent[root_second] = root_first
        if self.rank[root_first] == self.rank[root_second]:
            self.rank[root_first] += 1
        self.components -= 1
        return True


@dataclass
class MLSTInstance:
    name: str
    node_count: int
    edge_count: int
    optimum: int
    edges_by_label: Dict[int, List[Tuple[int, int]]]
    _cached_solution: Tuple[int, ...] | None = field(default=None, init=False)
    _cached_dsu: DisjointSet | None = field(default=None, init=False)

    @property
    def labels(self) -> List[int]:
        return sorted(self.edges_by_label)

    def _state(self, solution: Sequence[int]) -> DisjointSet:
        key = tuple(solution)
        if key != self._cached_solution:
            # Greedy construction and completion only append one label at a
            # time. Update the existing connectivity state incrementally in
            # that common case. A removal requires rebuilding because a
            # standard union-find does not support deletions.
            if (
                self._cached_solution is not None
                and self._cached_dsu is not None
                and len(key) == len(self._cached_solution) + 1
                and key[:-1] == self._cached_solution
            ):
                dsu = self._cached_dsu
                for first, second in self.edges_by_label[key[-1]]:
                    dsu.union(first, second)
            else:
                dsu = DisjointSet(self.node_count)
                for label in solution:
                    for first, second in self.edges_by_label[label]:
                        dsu.union(first, second)
            self._cached_solution = key
            self._cached_dsu = dsu
        # The cache always assigns both fields together.
        assert self._cached_dsu is not None
        return self._cached_dsu

    def is_connected(self, solution: Sequence[int]) -> bool:
        return self._state(solution).components == 1

    def marginal_component_reduction(
        self, solution: Sequence[int], candidate: int
    ) -> int:
        current = self._state(solution)
        # Candidate scoring only needs the number of successful merges. Copy
        # just the parent vector and perform the temporary unions inline:
        # no temporary DisjointSet object and no unused rank-vector copy.
        parent = current.parent.copy()
        merges = 0
        for first, second in self.edges_by_label[candidate]:
            root_first = first
            while parent[root_first] != root_first:
                root_first = parent[root_first]

            root_second = second
            while parent[root_second] != root_second:
                root_second = parent[root_second]

            if root_first != root_second:
                parent[root_second] = root_first
                merges += 1
        return merges


def read_mlst(path: Path) -> MLSTInstance:
    """Read a Group II ``.mlst`` instance."""

    with path.open("r", encoding="utf-8") as handle:
        header = handle.readline().split()
        if len(header) != 3:
            raise ValueError(f"Invalid MLST header in {path}: {header}")
        node_count, declared_edge_count, _ = map(int, header)

        edges_by_label: Dict[int, List[Tuple[int, int]]] = {}
        edge_count = 0
        for line_number, line in enumerate(handle, start=2):
            if not line.strip():
                continue
            fields = line.split()
            if len(fields) != 3:
                raise ValueError(
                    f"Invalid edge at {path}:{line_number}: {line.rstrip()}"
                )
            first, second, label = map(int, fields)
            if not (0 <= first < node_count and 0 <= second < node_count):
                raise ValueError(
                    f"Node outside [0, {node_count - 1}] at "
                    f"{path}:{line_number}"
                )
            edges_by_label.setdefault(label, []).append((first, second))
            edge_count += 1

    if edge_count != declared_edge_count:
        raise ValueError(
            f"{path} declares {declared_edge_count} edges but contains {edge_count}"
        )

    name_fields = path.stem.split("_")
    if len(name_fields) < 4:
        raise ValueError(f"Cannot extract optimum from instance name {path.name}")
    try:
        optimum = int(name_fields[3])
    except ValueError as error:
        raise ValueError(
            f"Invalid optimum in instance name {path.name}: {name_fields[3]}"
        ) from error

    instance = MLSTInstance(
        path.name, node_count, edge_count, optimum, edges_by_label
    )
    if not instance.is_connected(instance.labels):
        raise ValueError(f"The graph in {path} is not connected")
    return instance


def mlst_feasibility(solver: carousel_greedy, solution: List[int]) -> bool:
    return solver.data.is_connected(solution)


def mlst_greedy(
    solver: carousel_greedy, solution: List[int], candidate: int
) -> int:
    return solver.data.marginal_component_reduction(solution, candidate)


def solve(instance: MLSTInstance, alpha: int, beta: float, seed: int,
          feasibility_aware: bool) -> dict:
    solver = carousel_greedy(
        test_feasibility=mlst_feasibility,
        greedy_function=mlst_greedy,
        data=instance,
        candidate_elements=instance.labels,
        feasibility_aware=feasibility_aware,
        seed=seed,
    )

    start = time.perf_counter()
    best_solution = solver.minimize(alpha=alpha, beta=beta)
    elapsed = time.perf_counter() - start

    greedy_solution = solver.greedy_solution
    cg_solution = solver.cg_solution
    return {
        "instance": instance.name,
        "nodes": instance.node_count,
        "edges": instance.edge_count,
        "labels": len(instance.labels),
        "optimum": instance.optimum,
        "alpha": alpha,
        "beta": beta,
        "seed": seed,
        "feasibility_aware": feasibility_aware,
        "greedy_value": len(greedy_solution),
        "cg_value": len(cg_solution),
        "best_value": len(best_solution),
        "improvement": len(greedy_solution) - len(best_solution),
        "elapsed_seconds": f"{elapsed:.6f}",
        "greedy_feasible": instance.is_connected(greedy_solution),
        "cg_feasible": instance.is_connected(cg_solution),
        "best_labels": " ".join(map(str, best_solution)),
    }


def default_instances_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "instances" / "group_II" / "small"


def default_output_path() -> Path:
    return Path(__file__).resolve().parent / "mlst_group_II_small_results.csv"


def default_averages_output_path() -> Path:
    return Path(__file__).resolve().parent / "mlst_group_II_small_averages.csv"


def write_averages(results: Sequence[dict], output_path: Path) -> None:
    """Write one aggregate row for each MLST instance configuration."""

    groups: Dict[Tuple[int, int, int, int], List[dict]] = {}
    for result in results:
        key = (
            result["nodes"],
            result["edges"],
            result["labels"],
            result["optimum"],
        )
        groups.setdefault(key, []).append(result)

    fieldnames = [
        "nodes",
        "edges",
        "labels",
        "optimum",
        "avg_cg_objective",
        "avg_time_seconds",
        "num_optimal",
        "avg_gap_percent",
        "instances",
    ]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for key in sorted(groups):
            nodes, edges, labels, optimum = key
            group = groups[key]
            avg_objective = sum(row["cg_value"] for row in group) / len(group)
            avg_time = sum(float(row["elapsed_seconds"]) for row in group) / len(group)
            writer.writerow(
                {
                    "nodes": nodes,
                    "edges": edges,
                    "labels": labels,
                    "optimum": optimum,
                    "avg_cg_objective": f"{avg_objective:.1f}",
                    "avg_time_seconds": f"{avg_time:.6f}",
                    "num_optimal": sum(
                        row["cg_value"] == optimum for row in group
                    ),
                    "avg_gap_percent": f"{100.0 * (avg_objective - optimum) / optimum:.1f}",
                    "instances": len(group),
                }
            )


def instance_paths(instances_dir: Path) -> Iterable[Path]:
    paths = sorted(instances_dir.glob("*.mlst"))
    if not paths:
        raise FileNotFoundError(f"No .mlst instances found in {instances_dir}")
    return paths


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Carousel Greedy on the Group II small MLST instances."
    )
    parser.add_argument("--instances-dir", type=Path, default=default_instances_dir())
    parser.add_argument("--output", type=Path, default=default_output_path())
    parser.add_argument(
        "--averages-output", type=Path, default=default_averages_output_path()
    )
    parser.add_argument("--alpha", type=int, default=ALPHA)
    parser.add_argument("--beta", type=float, default=BETA)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument(
        "--feasibility-aware",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="skip replacement when removal leaves a feasible solution (default: true)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    paths = list(instance_paths(args.instances_dir))
    args.output.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "instance",
        "nodes",
        "edges",
        "labels",
        "optimum",
        "alpha",
        "beta",
        "seed",
        "feasibility_aware",
        "greedy_value",
        "cg_value",
        "best_value",
        "improvement",
        "elapsed_seconds",
        "greedy_feasible",
        "cg_feasible",
        "best_labels",
    ]

    results = []
    with args.output.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for index, path in enumerate(paths, start=1):
            result = solve(
                read_mlst(path), args.alpha, args.beta, args.seed,
                args.feasibility_aware,
            )
            results.append(result)
            writer.writerow(result)
            csv_file.flush()
            print(
                f"[{index:03d}/{len(paths):03d}] {path.name}: "
                f"greedy={result['greedy_value']} cg={result['cg_value']} "
                f"best={result['best_value']} time={result['elapsed_seconds']}s"
            )

    write_averages(results, args.averages_output)
    print(f"Results written to {args.output}")
    print(f"Averages written to {args.averages_output}")


if __name__ == "__main__":
    main()
