# Minimum Label Spanning Tree example

This example applies the MATLAB implementation of Carousel Greedy to every
Group II small MLST instance found in `instances/group_II/small`.

From the MATLAB project root, run:

```matlab
addpath('examples/mlst')
main
```

The default experiment uses `alpha=50`, `beta=0.10`, and seed `1`. It writes:

- `mlst_group_II_small_results.csv`, with one row per instance;
- `mlst_group_II_small_averages.csv`, with one row per instance configuration.

The main function also accepts optional instance directory, output paths,
alpha, beta, and seed arguments.
