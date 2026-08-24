# Minimum Label Spanning Tree example

This example applies `py_carouselgreedy` to all 240 Group II small MLST
instances. A solution is an ordered list of labels and it is feasible when the
edges carrying those labels connect every node.

Run from the `python` project directory:

```bash
python examples/mlst/main.py
```

The default experiment uses `alpha=50`, `beta=0.10`, and seed `1`. Results are
written incrementally to `examples/mlst/mlst_group_II_small_results.csv`.
Paths and parameters can also be overridden from the command line; run with
`--help` for the available options.
