using Test
using CarouselGreedy

@testset "Basic tests for CarouselGreedy" begin
    solver = CarouselGreedySolver(
        (s, sol) -> length(sol) >= 2, 
        (s, sol, c) -> rand()
    )
    solution = minimize(solver)
    @test isa(solution, Vector)
end