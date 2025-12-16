# CarouselGreedy-MultiLanguageFramework
This repository provides a unified multi-language framework implementing
the Carousel Greedy (CG) metaheuristic.

It includes complete implementations in:
- Python
- R
- MATLAB
- Julia

Each module contains examples, usage instructions, and tools for reproducible research.


# CarouselGreedy-MultiLanguageFramework

A unified **multi-language framework** implementing the **Carousel Greedy (CG)** metaheuristic, providing consistent and reproducible implementations in **Python, R, MATLAB, and Julia**.

This repository consolidates previously independent language-specific implementations into a single, coherent framework to support **research, benchmarking, and reproducible computational experiments**.

---

## 🌀 The Carousel Greedy Algorithm

The **Carousel Greedy (CG)** algorithm, originally introduced by **Cerrone et al. (2017)**, generalizes the classical greedy approach in order to overcome one of its main limitations: the *irreversibility of early decisions*.

While standard greedy algorithms are fast and simple, decisions taken during the initial construction phase are often short-sighted, leading to suboptimal solutions.  
On the other hand, advanced metaheuristics (e.g., local search or evolutionary algorithms) offer deeper exploration capabilities but typically at the cost of higher complexity and computational effort.

Carousel Greedy bridges this gap by extending the greedy construction phase through controlled **removal and replacement** of solution elements, allowing early poor decisions to be corrected while preserving simplicity and efficiency.

---

## 🔍 Key Idea

The algorithm introduces two control parameters:

- **α (alpha)** — controls the number of refinement iterations performed during the iterative phase.
- **β (beta)** — defines the fraction of elements removed from the initial greedy solution before refinement begins.

Using these parameters, CG interleaves construction, destruction, and refinement steps, resulting in four main phases:

1. **Construction Phase** – builds an initial solution using a greedy criterion.  
2. **Destruction Phase** – removes a fraction β of the most recently added elements.  
3. **Iterative Phase** – for α·|S| iterations, removes the oldest element and inserts a new one selected by the greedy criterion.  
4. **Completion Phase** – restores feasibility (if needed) using the base greedy procedure.

This mechanism allows CG to improve solution quality while maintaining low computational cost.

---

## 🧠 Applications

Since its introduction, Carousel Greedy has been successfully applied to a wide range of **combinatorial optimization and data-driven problems**, including:

- **Graph-based problems**: Minimum Label Spanning Tree, Vertex Cover, Community Detection  
- **Routing and logistics**: Vehicle Routing, Distribution Planning, Network Optimization  
- **Knapsack and resource allocation problems**  
- **Data-driven applications**: Feature Selection, Social Network Analysis  

Its flexibility makes CG suitable for problems where exact optimization is impractical and classical greedy methods are insufficient.

---

## 🧩 Framework Structure

This repository contains **four language-specific implementations**, each organized in its own folder:

| Language | Folder | Description |
|--------|--------|-------------|
| Python | `python/` | Modular and extensible implementation designed for high performance |
| R | `R/` | Native R implementation following standard package conventions |
| MATLAB | `matlab/` | MATLAB implementation suitable for academic and prototyping use |
| Julia | `julia/` | High-performance Julia implementation leveraging multiple dispatch |

Each folder includes its own README with **language-specific installation instructions, usage examples, and documentation**.

---

## 🔗 Quick Access to Implementations

- ▶ **Python implementation** → [`python/`](./python)
- ▶ **R implementation** → [`R/`](./R)
- ▶ **MATLAB implementation** → [`matlab/`](./matlab)
- ▶ **Julia implementation** → [`julia/`](./julia)

---

## 📄 Related Publications

- **Cerrone et al. (2017)**  
  *Carousel Greedy: A generalized greedy algorithm with applications in optimization*  
  *Computers & Operations Research*

- **Dragone et al. (2025)**  
  *Carousel Greedy: From Drone Routing to Social Network Analysis*  
  Proceedings of ODS 2025

- **Dragone et al. (submitted)**  
  *A Multi-Language Framework for the Carousel Greedy Algorithm*  
  Submitted to *SoftwareX*

---

## 🧑‍🔬 Citation

If you use this framework or one of its implementations in academic work, please cite the relevant paper:

```bibtex
@article{dragone2026multilanguage,
  title={A Multi-Language Framework for the Carousel Greedy Algorithm},
  author={Dragone, Raffaele and Cerrone, Carmine and Golden, Bruce L.},
  journal={SoftwareX},
  year={2026}
}
```

---

## 📬 Contact & Contributions

Contributions, issues, and pull requests are welcome.

For questions or collaborations:
- **Raffaele Dragone**  
  raffaele.dragone@edu.unige.it

---

## 📄 License

This project is distributed under the **BSD 3-Clause License**.  
See the [LICENSE](./LICENSE) file for details.