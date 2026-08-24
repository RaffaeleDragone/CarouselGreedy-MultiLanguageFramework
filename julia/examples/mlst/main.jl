include(joinpath(@__DIR__, "..", "..", "src", "CarouselGreedy.jl"))
using .CarouselGreedy

const DEFAULT_ALPHA = 50
const DEFAULT_BETA = 0.10
const DEFAULT_SEED = 42

mutable struct DisjointSet
    parent::Vector{Int}
    rank::Vector{Int}
    components::Int
end

DisjointSet(size::Int) = DisjointSet(collect(1:size), zeros(Int, size), size)
Base.copy(state::DisjointSet) =
    DisjointSet(copy(state.parent), copy(state.rank), state.components)

function find_root!(state::DisjointSet, item::Int)
    root = item
    while state.parent[root] != root
        root = state.parent[root]
    end
    while state.parent[item] != item
        parent = state.parent[item]
        state.parent[item] = root
        item = parent
    end
    return root
end

function union!(state::DisjointSet, first::Int, second::Int)
    root_first = find_root!(state, first)
    root_second = find_root!(state, second)
    root_first == root_second && return false

    if state.rank[root_first] < state.rank[root_second]
        root_first, root_second = root_second, root_first
    end
    state.parent[root_second] = root_first
    if state.rank[root_first] == state.rank[root_second]
        state.rank[root_first] += 1
    end
    state.components -= 1
    return true
end

mutable struct ConnectivityCache
    last_solution::Vector{Int}
    initialized::Bool
    state::DisjointSet
end

struct MLSTInstance
    name::String
    node_count::Int
    edge_count::Int
    optimum::Int
    labels::Vector{Int}
    edges_by_label::Dict{Int, Vector{Tuple{Int, Int}}}
    cache::ConnectivityCache
end

function add_label!(state::DisjointSet, instance::MLSTInstance, label::Int)
    for (first, second) in instance.edges_by_label[label]
        union!(state, first, second)
    end
    return state
end

function update_state!(instance::MLSTInstance, solution::Vector{Int})
    cache = instance.cache
    if cache.initialized && cache.last_solution == solution
        return cache.state
    end

    can_append = cache.initialized &&
        length(solution) == length(cache.last_solution) + 1 &&
        @views(solution[1:end-1] == cache.last_solution)

    if can_append
        add_label!(cache.state, instance, solution[end])
    else
        cache.state = DisjointSet(instance.node_count)
        for label in solution
            add_label!(cache.state, instance, label)
        end
    end
    cache.last_solution = copy(solution)
    cache.initialized = true
    return cache.state
end

mlst_feasibility(solver::CarouselGreedySolver, solution::Vector{Int}) =
    update_state!(solver.data, solution).components == 1

function mlst_greedy(
    solver::CarouselGreedySolver,
    solution::Vector{Int},
    candidate::Int,
)
    current = update_state!(solver.data, solution)
    candidate_state = copy(current)
    add_label!(candidate_state, solver.data, candidate)
    return current.components - candidate_state.components
end

function read_mlst(path::String)
    lines = readlines(path)
    isempty(lines) && error("Empty MLST file: $path")
    header = parse.(Int, split(strip(lines[1])))
    length(header) == 3 || error("Invalid MLST header in $path")
    node_count, declared_edge_count = header[1], header[2]

    edges_by_label = Dict{Int, Vector{Tuple{Int, Int}}}()
    edge_count = 0
    for (line_number, line) in enumerate(@view lines[2:end])
        isempty(strip(line)) && continue
        fields = parse.(Int, split(strip(line)))
        length(fields) == 3 ||
            error("Invalid edge at $path:$(line_number + 1)")
        first, second, label = fields
        0 <= first < node_count || error("Invalid node $first in $path")
        0 <= second < node_count || error("Invalid node $second in $path")
        # Vertices are zero-based in the files and one-based in Julia arrays.
        push!(get!(edges_by_label, label, Tuple{Int, Int}[]), (first + 1, second + 1))
        edge_count += 1
    end
    edge_count == declared_edge_count ||
        error("$path declares $declared_edge_count edges but contains $edge_count")

    name = basename(path)
    name_fields = split(splitext(name)[1], '_')
    length(name_fields) >= 4 || error("Cannot extract optimum from $name")
    optimum = parse(Int, name_fields[4])
    labels = sort!(collect(keys(edges_by_label)))
    cache = ConnectivityCache(Int[], false, DisjointSet(node_count))
    instance = MLSTInstance(
        name,
        node_count,
        edge_count,
        optimum,
        labels,
        edges_by_label,
        cache,
    )
    is_connected(instance, labels) || error("The graph is not connected: $path")
    return instance
end

function is_connected(instance::MLSTInstance, solution::Vector{Int})
    state = DisjointSet(instance.node_count)
    for label in solution
        add_label!(state, instance, label)
    end
    return state.components == 1
end

function solve_instance(instance::MLSTInstance, alpha::Int, beta::Float64, seed::Int, feasibility_aware::Bool)
    solver = CarouselGreedySolver(
        mlst_feasibility,
        mlst_greedy;
        alpha=alpha,
        beta=beta,
        data=instance,
        candidate_elements=instance.labels,
        random_tie_break=true,
        feasibility_aware=feasibility_aware,
        seed=seed,
    )

    start = time_ns()
    best_solution = minimize(solver; alpha=alpha, beta=beta)
    elapsed = (time_ns() - start) / 1.0e9
    greedy_solution = solver.greedy_solution
    cg_solution = solver.cg_solution

    return (
        instance=instance.name,
        nodes=instance.node_count,
        edges=instance.edge_count,
        labels=length(instance.labels),
        optimum=instance.optimum,
        alpha=alpha,
        beta=beta,
        seed=seed,
        feasibility_aware=feasibility_aware,
        greedy_value=length(greedy_solution),
        cg_value=length(cg_solution),
        best_value=length(best_solution),
        improvement=length(greedy_solution) - length(best_solution),
        elapsed_seconds=elapsed,
        greedy_feasible=is_connected(instance, greedy_solution),
        cg_feasible=is_connected(instance, cg_solution),
        best_labels=join(best_solution, ' '),
    )
end

const DETAIL_HEADER = (
    "instance,nodes,edges,labels,optimum,alpha,beta,seed,feasibility_aware,greedy_value," *
    "cg_value,best_value,improvement,elapsed_seconds,greedy_feasible," *
    "cg_feasible,best_labels"
)

function write_detail_row(io::IO, row)
    println(
        io,
        join(
            (
                row.instance,
                row.nodes,
                row.edges,
                row.labels,
                row.optimum,
                row.alpha,
                row.beta,
                row.seed,
                row.feasibility_aware,
                row.greedy_value,
                row.cg_value,
                row.best_value,
                row.improvement,
                string(round(row.elapsed_seconds; digits=6)),
                row.greedy_feasible,
                row.cg_feasible,
                row.best_labels,
            ),
            ',',
        ),
    )
end

function write_averages(results, output_path::String)
    groups = Dict{NTuple{4, Int}, Vector{eltype(results)}}()
    for row in results
        key = (row.nodes, row.edges, row.labels, row.optimum)
        push!(get!(groups, key, eltype(results)[]), row)
    end

    open(output_path, "w") do io
        println(
            io,
            "nodes,edges,labels,optimum,avg_cg_objective,avg_time_seconds," *
            "num_optimal,avg_gap_percent,instances",
        )
        for key in sort!(collect(keys(groups)))
            rows = groups[key]
            optimum = key[4]
            average_objective = sum(row.cg_value for row in rows) / length(rows)
            average_time = sum(row.elapsed_seconds for row in rows) / length(rows)
            num_optimal = count(row.cg_value == optimum for row in rows)
            gap = 100 * (average_objective - optimum) / optimum
            println(
                io,
                join(
                    (
                        key[1],
                        key[2],
                        key[3],
                        optimum,
                        round_one_decimal(average_objective),
                        round(average_time; digits=6),
                        num_optimal,
                        round_one_decimal(gap),
                        length(rows),
                    ),
                    ',',
                ),
            )
        end
    end
end

round_one_decimal(value::Real) = floor(value * 10 + 0.5) / 10

function parse_args(args::Vector{String})
    example_dir = @__DIR__
    project_dir = normpath(joinpath(example_dir, "..", ".."))
    options = Dict{String, Any}(
        "instances_dir" => joinpath(project_dir, "instances", "group_II", "small"),
        "output" => joinpath(example_dir, "mlst_group_II_small_results.csv"),
        "averages_output" => joinpath(example_dir, "mlst_group_II_small_averages.csv"),
        "alpha" => DEFAULT_ALPHA,
        "beta" => DEFAULT_BETA,
        "seed" => DEFAULT_SEED,
        "feasibility_aware" => true,
    )

    index = 1
    while index <= length(args)
        option = args[index]
        if option == "--help"
            println("Usage: julia --project=. examples/mlst/main.jl [options]")
            println("  --instances-dir PATH")
            println("  --output PATH")
            println("  --averages-output PATH")
            println("  --alpha INTEGER")
            println("  --beta NUMBER")
            println("  --seed INTEGER")
            println("  --feasibility-aware true|false")
            exit()
        end
        index < length(args) || error("Missing value for $option")
        value = args[index + 1]
        if option == "--instances-dir"
            options["instances_dir"] = value
        elseif option == "--output"
            options["output"] = value
        elseif option == "--averages-output"
            options["averages_output"] = value
        elseif option == "--alpha"
            options["alpha"] = parse(Int, value)
        elseif option == "--beta"
            options["beta"] = parse(Float64, value)
        elseif option == "--seed"
            options["seed"] = parse(Int, value)
        elseif option == "--feasibility-aware"
            lowercase(value) in ("true", "false") || error("feasibility-aware must be true or false")
            options["feasibility_aware"] = lowercase(value) == "true"
        else
            error("Unknown option: $option")
        end
        index += 2
    end
    options["alpha"] > 0 || error("alpha must be positive")
    0 <= options["beta"] <= 1 || error("beta must be between 0 and 1")
    return options
end

function main(args::Vector{String}=ARGS)
    options = parse_args(args)
    paths = sort!(filter(
        path -> endswith(path, ".mlst"),
        readdir(options["instances_dir"]; join=true),
    ))
    isempty(paths) && error("No .mlst instances found in $(options["instances_dir"])")
    mkpath(dirname(options["output"]))
    mkpath(dirname(options["averages_output"]))

    # Compile the complete MLST/CG execution path outside the measured campaign.
    # solve_instance creates its own solver, so the measured runs start afterward
    # with a fresh solver and a freshly seeded random-number generator.
    println("Warming up Julia on $(basename(first(paths)))...")
    solve_instance(
        read_mlst(first(paths)),
        options["alpha"],
        options["beta"],
        options["seed"],
        options["feasibility_aware"],
    )
    GC.gc()
    println("Warm-up complete; starting measured runs.")

    results = NamedTuple[]
    open(options["output"], "w") do io
        println(io, DETAIL_HEADER)
        for (index, path) in enumerate(paths)
            result = solve_instance(
                read_mlst(path),
                options["alpha"],
                options["beta"],
                options["seed"],
                options["feasibility_aware"],
            )
            push!(results, result)
            write_detail_row(io, result)
            flush(io)
            println(
                "[",
                lpad(index, 3, '0'),
                "/",
                lpad(length(paths), 3, '0'),
                "] ",
                basename(path),
                ": greedy=",
                result.greedy_value,
                " cg=",
                result.cg_value,
                " best=",
                result.best_value,
                " time=",
                round(result.elapsed_seconds; digits=6),
                "s",
            )
        end
    end

    write_averages(results, options["averages_output"])
    println("Results written to $(options["output"])")
    println("Averages written to $(options["averages_output"])")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
