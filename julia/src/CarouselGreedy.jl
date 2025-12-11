module CarouselGreedy

export CarouselGreedySolver, minimize, maximize, greedy_minimize, greedy_maximize

using Random

mutable struct CarouselGreedySolver{T}
    test_feasibility::Function
    greedy_function::Function
    alpha::Int
    beta::Float64
    data::Any
    candidate_elements::Vector{T}
    solution::Vector{T}
    greedy_solution::Vector{T}
    cg_solution::Vector{T}
    random_tie_break::Bool
    rng::AbstractRNG
    problem_type::Symbol
    iteration::Int
end

function CarouselGreedySolver(test_feasibility, greedy_function;
                               alpha::Int=10,
                               beta::Float64=0.2,
                               data=nothing,
                               candidate_elements::Vector=[],
                               random_tie_break::Bool=true,
                               seed::Int=42)

    if alpha <= 0
        error("alpha must be positive")
    end
    if beta < 0 || beta > 1
        error("beta must be between 0 and 1")
    end

    rng = MersenneTwister(seed)

    return CarouselGreedySolver(test_feasibility, greedy_function,
                                alpha, beta, data,
                                candidate_elements,
                                Vector{eltype(candidate_elements)}(),
                                Vector{eltype(candidate_elements)}(),
                                Vector{eltype(candidate_elements)}(),
                                random_tie_break,
                                rng,
                                :UNDEFINED,
                                0)
end

function _select_best_candidate(solver::CarouselGreedySolver)
    candidates = setdiff(solver.candidate_elements, solver.solution)
    isempty(candidates) && return nothing

    scores = Dict(c => solver.greedy_function(solver, solver.solution, c) for c in candidates)
    max_score = maximum(values(scores))
    best_candidates = filter(c -> scores[c] == max_score, candidates)

    return solver.random_tie_break ? rand(solver.rng, best_candidates) : first(best_candidates)
end

function _construction_phase(solver::CarouselGreedySolver)
    if solver.problem_type == :MIN
        while !solver.test_feasibility(solver, solver.solution)
            candidate = _select_best_candidate(solver)
            candidate === nothing && break
            push!(solver.solution, candidate)
        end
    elseif solver.problem_type == :MAX
        while true
            candidate = _select_best_candidate(solver)
            candidate === nothing && break
            push!(solver.solution, candidate)
            if !solver.test_feasibility(solver, solver.solution)
                pop!(solver.solution)
                break
            end
        end
    end
    return copy(solver.solution)
end

function greedy_minimize(solver::CarouselGreedySolver)
    solver.problem_type = :MIN
    empty!(solver.solution)
    greedy = _construction_phase(solver)
    solver.greedy_solution = copy(greedy)
    return greedy
end

function greedy_maximize(solver::CarouselGreedySolver)
    solver.problem_type = :MIN
    empty!(solver.solution)
    solver.solution = _construction_phase(solver)
    solver.problem_type = :MAX
    greedy = _construction_phase(solver)
    solver.greedy_solution = copy(greedy)
    return greedy
end

function _removal_phase(solver::CarouselGreedySolver)
    n_remove = Int(floor(length(solver.solution) * solver.beta))
    if length(solver.solution) - n_remove < 1
        n_remove = max(0, length(solver.solution) - 2)
    end
    solver.solution = solver.solution[1:end-n_remove]
end

function _iterative_phase(solver::CarouselGreedySolver, iterations::Int)
    for _ in 1:iterations
        solver.iteration += 1
        !isempty(solver.solution) && popfirst!(solver.solution)
        if solver.test_feasibility(solver, solver.solution)
            continue
        end
        candidate = _select_best_candidate(solver)
        candidate === nothing && break
        if solver.problem_type == :MIN
            push!(solver.solution, candidate)
        elseif solver.problem_type == :MAX
            temp = copy(solver.solution)
            push!(temp, candidate)
            if solver.test_feasibility(solver, temp)
                push!(solver.solution, candidate)
            end
        end
    end
end

function _completion_phase(solver::CarouselGreedySolver)
    if solver.problem_type == :MIN
        while !solver.test_feasibility(solver, solver.solution)
            candidate = _select_best_candidate(solver)
            candidate === nothing && break
            push!(solver.solution, candidate)
        end
    elseif solver.problem_type == :MAX
        while true
            candidates = setdiff(solver.candidate_elements, solver.solution)
            feasible = [c for c in candidates if solver.test_feasibility(solver, push!(copy(solver.solution), c))]
            isempty(feasible) && break
            scores = Dict(c => solver.greedy_function(solver, solver.solution, c) for c in feasible)
            max_score = maximum(values(scores))
            best_candidates = filter(c -> scores[c] == max_score, feasible)
            selected = solver.random_tie_break ? rand(solver.rng, best_candidates) : first(best_candidates)
            push!(solver.solution, selected)
        end
    end
end

function minimize(solver::CarouselGreedySolver; alpha=nothing, beta=nothing)
    a = isnothing(alpha) ? solver.alpha : alpha
    b = isnothing(beta) ? solver.beta : beta
    tmp_alpha = solver.alpha
    tmp_beta = solver.beta
    solver.alpha, solver.beta = a, b
    solver.problem_type = :MIN

    greedy = greedy_minimize(solver)
    initial_len = length(greedy)
    _removal_phase(solver)
    _iterative_phase(solver, a * initial_len)
    _completion_phase(solver)

    solver.cg_solution = copy(solver.solution)
    solver.alpha = tmp_alpha
    solver.beta = tmp_beta
    return length(greedy) < length(solver.cg_solution) ? greedy : solver.cg_solution
end

function maximize(solver::CarouselGreedySolver; alpha=nothing, beta=nothing)
    a = isnothing(alpha) ? solver.alpha : alpha
    b = isnothing(beta) ? solver.beta : beta
    tmp_alpha = solver.alpha
    tmp_beta = solver.beta
    solver.alpha, solver.beta = a, b
    solver.problem_type = :MAX

    greedy = greedy_maximize(solver)
    initial_len = length(greedy)
    _removal_phase(solver)
    _iterative_phase(solver, a * initial_len)
    _completion_phase(solver)

    solver.cg_solution = copy(solver.solution)
    solver.alpha = tmp_alpha
    solver.beta = tmp_beta
    return length(greedy) > length(solver.cg_solution) ? greedy : solver.cg_solution
end

end # module
