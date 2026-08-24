# Minimum Label Spanning Tree example

This example applies the R implementation of Carousel Greedy to every Group II
small MLST instance found in `instances/group_II/small`.

Run from the R project directory:

```sh
Rscript examples/mlst/main.R
```

The default experiment uses `alpha=50`, `beta=0.10`, and seed `1`. It writes:

- `mlst_group_II_small_results.csv`, with one row per instance;
- `mlst_group_II_small_averages.csv`, with one row per instance configuration.

Run `Rscript examples/mlst/main.R --help` to see the optional path and parameter
overrides.
