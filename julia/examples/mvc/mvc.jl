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

function main()
    filepath = joinpath(@__DIR__, "data", "100_nodes.mis")
    matrix, n, degrees = read_adjacency_matrix(filepath)
    initialize_globals(matrix, degrees)
    data = Dict(:matrix => deepcopy(matrix), :original => deepcopy(matrix), :n_nodes => n)
    candidates = collect(0:n-1)

    solver = CarouselGreedySolver(
        my_feasibility_function,
        my_greedy_function,
        alpha=10,
        beta=0.1,
        data=data,
        candidate_elements=candidates,
        seed=2,
        random_tie_break=true
    )
    start_greedy = time()
    solution_greedy = greedy_minimize(solver)  # warm-up compilation run
    elapsed_greedy = time() - start_greedy
    start_cg = time()
    solution_cg = minimize(solver)
    elapsed_cg = time() - start_cg
    println("✔ $(basename(filepath)) → Greedy Time: $(round(elapsed_greedy, digits=4))s, Greedy Size: $(length(solution_greedy))")
    println("✔ $(basename(filepath)) → CG Time: $(round(elapsed_cg, digits=4))s, CG Size: $(length(solution_cg))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end