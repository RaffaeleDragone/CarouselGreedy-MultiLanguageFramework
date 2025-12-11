module RunMVC
include("../../src/CarouselGreedy.jl")
using .CarouselGreedy
using Dates

# === Lettura matrice di adiacenza ===
function read_adjacency_matrix(file_path::String)
    open(file_path, "r") do io
        line = readline(io)
        while !startswith(line, "p")
            line = readline(io)
        end
        _, _, n_str, _ = split(line)
        n = parse(Int, n_str)
        matrix = fill(0, n, n)
        for line in eachline(io)
            startswith(line, "e") || continue
            _, u_str, v_str = split(line)
            u, v = parse(Int, u_str) - 1, parse(Int, v_str) - 1
            matrix[u+1, v+1] = 1
            matrix[v+1, u+1] = 1
        end
        return matrix, n
    end
end

# === Funzione di ammissibilità ===
function my_feasibility_function(solver::CarouselGreedySolver, solution::Vector{Int})
    matrix = solver.data[:matrix]
    n = solver.data[:n_nodes]
    for i in 1:n
        for j in i+1:n
            if matrix[i,j] == 1 && !(i-1 in solution || j-1 in solution)
                return false
            end
        end
    end
    return true
end

# === Funzione greedy ===
function my_greedy_function(solver::CarouselGreedySolver, solution::Vector{Int}, candidate::Int)
    matrix = solver.data[:matrix]
    n = solver.data[:n_nodes]
    covered = Set(solution)
    degree = 0
    for j in 1:n
        if matrix[candidate+1, j] == 1 && !(j-1 in covered)
            degree += 1
        end
    end
    return degree
end

# === Main ===
function main()
    filepath = joinpath(@__DIR__, "data", "100_nodes.mis")
    matrix, n = read_adjacency_matrix(filepath)
    data = Dict(:matrix => matrix, :n_nodes => n)
    candidates = collect(0:n-1)

    solver = CarouselGreedySolver(
        my_feasibility_function,
        my_greedy_function;
        alpha=10,
        beta=0.01,
        data=data,
        candidate_elements=candidates,
        seed=1,
        random_tie_break=true
    )

    # Greedy
    start_greedy = time()
    sol_greedy = greedy_minimize(solver)
    greedy_time = time() - start_greedy

    # Carousel Greedy
    start_cg = time()
    sol_cg = minimize(solver)
    cg_time = time() - start_cg

    println("✔ $(basename(filepath))")
    println("Greedy → Time: $(round(greedy_time, digits=4))s, Size: $(length(sol_greedy))")
    println("CG → Time: $(round(cg_time, digits=4))s, Size: $(length(sol_cg))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end