function solution_unit_tests()

    compute_original_cost_tests()

end

function compute_original_cost_tests()
    cost = 0.0
    vars = create_array_of_vars(5, CL.Variable)
    vals = [0.5*i for i in 1:length(vars)]
    kv = Dict{CL.Variable,Float64}()
    for i in 1:length(vars)
        kv[vars[i]] = vals[i]
    end
    sol = CL.PrimalSolution(cost, kv)
    @test CL.compute_original_cost(sol) == 7.5
end
