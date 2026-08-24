# Minimum Label Spanning Tree example

This example applies the Julia implementation of Carousel Greedy to every
Group II small MLST instance found in `instances/group_II/small`.

Run from the Julia project directory:

```sh
julia --project=. examples/mlst/main.jl
```

The default experiment uses `alpha=50`, `beta=0.10`, and seed `1`. It writes:

- `mlst_group_II_small_results.csv`, with one row per instance;
- `mlst_group_II_small_averages.csv`, with one row per instance configuration.

Run with `--help` to see the optional path and parameter overrides.
