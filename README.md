<p align="center">
  <img src="./resources/cg_logo.png" alt="Carousel Greedy Logo" width="350"/>
</p>

# CarouselGreedy-MultiLanguageFramework

A unified **multi-language framework** implementing the **Carousel Greedy (CG)** metaheuristic, providing consistent and reproducible implementations in **Python, R, MATLAB, and Julia**.

This repository consolidates previously independent language-specific implementations into a single, coherent framework designed to support **research, benchmarking, and reproducible computational experiments**.

---

## 🌀 The Carousel Greedy Algorithm

The **Carousel Greedy (CG)** algorithm, originally introduced by  
**Cerrone et al. (2017)**, generalizes the classical greedy approach to overcome one of its main limitations — the *irreversibility of early decisions*.

Traditional greedy algorithms are simple and fast, but decisions made during the initial construction phase are often short-sighted, leading to suboptimal solutions.  
Conversely, advanced metaheuristics such as local search or evolutionary algorithms allow deeper exploration of the solution space, but typically at the cost of increased complexity and computational effort.

Carousel Greedy bridges this gap by extending the greedy construction phase through controlled **removal and replacement** of solution elements, enabling the correction of early poor decisions while preserving efficiency and conceptual simplicity.

---

## 🔍 Key Idea

CG extends the intermediate phase of greedy construction, where partial knowledge of the solution already allows for more reliable decisions.  
To achieve this, two control parameters are introduced:

- **α (alpha)** — controls the number of refinement iterations performed during the iterative phase.  
- **β (beta)** — defines the fraction of elements removed from the initial greedy solution before refinement begins.

These parameters enable CG to interleave *construction*, *destruction*, and *refinement* steps, resulting in an algorithm with four main phases:

1. **Construction Phase** – builds an initial solution using a greedy criterion.  
2. **Destruction Phase** – removes a fraction β of the most recently added elements.  
3. **Iterative Phase** – for α·|S| iterations, removes the oldest element and inserts a new one selected by the greedy criterion.  
4. **Completion Phase** – restores feasibility (if needed) using the base greedy procedure.

<p align="center">
  <img src="./resources/cg_schema.png" alt="Carousel Greedy Algorithm Schema" width="650"/>
</p>
<sub><em>Figure: Schematic overview of the four phases of the Carousel Greedy algorithm.</em></sub>

---

## 🧠 Applications

Since its introduction, the Carousel Greedy algorithm has been successfully applied to a wide range of **combinatorial optimization problems** and **data-driven applications**, including:

- **Graph-based problems**: Minimum Label Spanning Tree, Vertex Cover, Community Detection  
- **Routing and logistics**: Vehicle Routing, Distribution Planning, Network Optimization  
- **Knapsack and resource allocation problems**  
- **Data-driven contexts**: Feature Selection, Social Network Analysis  

Its flexibility and low computational cost make CG a practical metaheuristic for problems where exact optimization methods are impractical and classical greedy approaches are insufficient.

---

## 📚 Scientific Literature

The Carousel Greedy algorithm has been investigated and applied in a broad range of scientific works.  
A non-exhaustive list of representative contributions is reported below:

| Reference | Title |
|---------|-------|
| Cerrone et al. (2017) | *Carousel Greedy: A generalized greedy algorithm with applications in optimization* |
| Carrabs et al. (2017) | *Column generation embedding CG for the maximum network lifetime problem* |
| Cerrone et al. (2018) | *An efficient and simple approach to solve a distribution problem* |
| Hadi et al. (2019) | *An efficient approach for sentiment analysis in a big data environment* |
| Cerrone et al. (2019) | *Heuristics for the strong generalized minimum label spanning tree problem* |
| Kong et al. (2019) | *A hybrid iterated CG algorithm for community detection in complex networks* |
| Cerulli et al. (2020) | *The knapsack problem with forfeits* |
| Hammond et al. (2020) | *Survey of UAV set-covering algorithms for terrain photogrammetry* |
| Carrabs et al. (2020) | *An adaptive heuristic approach to compute bounds for the CETSP* |
| Cerrone et al. (2021) | *Grocery distribution plans in urban networks with penalties* |
| Cerulli et al. (2022) | *Maximum network lifetime problem with time slots and coverage constraints* |
| Capobianco et al. (2022) | *A hybrid metaheuristic for the knapsack problem with forfeits* |
| Shan et al. (2021) | *An iterated CG algorithm for finding minimum positive influence dominating sets* |
| D’Ambrosio et al. (2023) | *The knapsack problem with forfeit sets* |
| Wang et al. (2023) | *Carousel Greedy algorithms for feature selection in linear regression* |
| Carrabs et al. (2025) | *Hybridizing Carousel Greedy and Kernel Search for the maximum flow problem with conflicts* |

---

## 🧩 Framework Structure

This repository provides **language-agnostic documentation** and acts as a **hub** for the following language-specific implementations:

| Language | Folder | Description |
|--------|--------|-------------|
| Python | `python/` | Modular implementation focused on flexibility and performance |
| R | `R/` | Native R implementation following standard package conventions |
| MATLAB | `matlab/` | MATLAB implementation suitable for academic and prototyping use |
| Julia | `julia/` | High-performance Julia implementation leveraging multiple dispatch |

Each folder contains its own README with **installation instructions, usage examples, and API documentation specific to the target language**.

---

## 🔗 Access to Language-Specific Implementations

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

If you use this framework or one of its implementations in academic work, please cite the following paper:

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