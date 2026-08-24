module RunMVC
include("../../src/CarouselGreedy.jl")
using .CarouselGreedy
using Dates
using Glob
using DataFrames

const FEAS_TIME = Ref(0.0)
const GREEDY_TIME = Ref(0.0)

# === GLOBAL STATE ===
const global_matrix = Ref{Matrix{Int}}()
const global_degrees = Ref{Vector{Int}}()
const global_solution = Ref{Vector{Int}}(Int[])

function initialize_globals(matrix::Matrix{Int}, degrees::Vector{Int})
    global_matrix[] = deepcopy(matrix)
    global_degrees[] = deepcopy(degrees)
    global_solution[] = Int[]
end

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
        degrees = [sum(matrix[i, :]) for i in 1:n]
        return matrix, n, degrees
    end
end

function my_feasibility_function(solver::CarouselGreedySolver, solution::Vector{Int})
    
    # Early exit if solution hasn't changed
    if length(global_solution[]) == length(solution) && all(global_solution[] .== solution)
        return maximum(global_degrees[]) == 0
    end
    matrix = solver.data[:matrix]
    original = solver.data[:original]
    degrees = global_degrees[]
    n = length(global_degrees[])
    is_in_prev = falses(n)
    is_in_curr = falses(n)

    for i in global_solution[]
        is_in_prev[i + 1] = true
    end
    for i in solution
        is_in_curr[i + 1] = true
    end

    removed = Int[]
    inserted = Int[]
    for i in 1:n
        if is_in_prev[i] && !is_in_curr[i]
            push!(removed, i - 1)
        elseif !is_in_prev[i] && is_in_curr[i]
            push!(inserted, i - 1)
        end
    end

    for node in removed
        for j in 1:n
            if original[node+1, j] == 1 && !is_in_curr[j]
                global_matrix[][node+1, j] = 1
                global_matrix[][j, node+1] = 1
                degrees[j] += 1
                degrees[node + 1] += 1
            end
        end
    end

    for node in inserted
        degrees[node + 1] = 0
        for j in 1:n
            if global_matrix[][node+1, j] == 1
                degrees[j] -= 1
                global_matrix[][node+1, j] = 0
                global_matrix[][j, node+1] = 0
            end
        end
    end
    global_solution[] = copy(solution)
    
    return maximum(degrees) == 0
end

function my_greedy_function(solver::CarouselGreedySolver, solution::Vector{Int}, candidate::Int)
    
    my_feasibility_function(solver,solution)
    
    return global_degrees[][candidate + 1]
end

function build_solver(matrix::Matrix{Int}, n::Int, degrees::Vector{Int}, feasibility_aware::Bool)
    initialize_globals(matrix, degrees)
    data = Dict(:matrix => deepcopy(matrix), :original => deepcopy(matrix), :n_nodes => n)
    candidates = collect(0:n-1)
    return CarouselGreedySolver(
        my_feasibility_function,
        my_greedy_function,
        alpha=10,
        beta=0.01,
        feasibility_aware=feasibility_aware,
        data=data,
        candidate_elements=candidates,
        seed=42,
        random_tie_break=true,
    )
end

function solve_instance(filepath::String, feasibility_aware::Bool)
    matrix, n, degrees = read_adjacency_matrix(filepath)
    solver = build_solver(matrix, n, degrees, feasibility_aware)
    start_cg = time()
    solution_cg = minimize(solver)
    elapsed_cg = time() - start_cg
    solution_greedy = solver.greedy_solution
    feasible = my_feasibility_function(solver, solution_cg)
    return (
        instance=basename(filepath),
        greedy_value=length(solution_greedy),
        cg_value=length(solver.cg_solution),
        best_value=length(solution_cg),
        elapsed_seconds=elapsed_cg,
        feasibility_aware=feasibility_aware,
        feasible=feasible,
    )
end

function run_batch(instances_dir::String, output_path::String, feasibility_aware::Bool)
    paths = sort(filter(path -> endswith(path, ".mis"), readdir(instances_dir; join=true)))
    isempty(paths) && error("No .mis instances found in $instances_dir")

    # Complete warm-up outside the measured campaign.
    solve_instance(first(paths), feasibility_aware)
    GC.gc()

    open(output_path, "w") do io
        println(io, "instance,greedy_value,cg_value,best_value,elapsed_seconds,feasibility_aware,feasible")
        for (index, filepath) in enumerate(paths)
            result = solve_instance(filepath, feasibility_aware)
            println(io, join((result.instance, result.greedy_value, result.cg_value,
                result.best_value, result.elapsed_seconds, result.feasibility_aware,
                result.feasible), ','))
            flush(io)
            println("[$index/$(length(paths))] $(result.instance): $(result.best_value)")
        end
    end
end

function main()
    feasibility_aware = isempty(ARGS) ? true : lowercase(ARGS[1]) == "true"
    isempty(ARGS) || lowercase(ARGS[1]) in ("true", "false") || error("Expected true or false")
    filepath = joinpath(@__DIR__, "data", "100_nodes.mis")
    matrix, n, degrees = read_adjacency_matrix(filepath)
    warmup_solver = build_solver(matrix, n, degrees, feasibility_aware)
    minimize(warmup_solver)
    GC.gc()
    result = solve_instance(filepath, feasibility_aware)
    println("✔ $(basename(filepath)) → Greedy Size: $(result.greedy_value)")
    println("✔ $(basename(filepath)) → CG Time: $(round(result.elapsed_seconds, digits=4))s, CG Size: $(result.best_value)")
    println("✔ Feasibility aware: $feasibility_aware")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end
