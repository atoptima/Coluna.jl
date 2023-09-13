struct MockCandidate <: Coluna.Branching.AbstractBranchingCandidate
    local_id::Int64
    lhs::Float64
end

Coluna.Branching.get_local_id(c::MockCandidate) = c.local_id
Coluna.Branching.get_lhs(c::MockCandidate) = c.lhs
Coluna.Branching.getdescription(::MockCandidate) = "MockCandidate"

function _mock_candidates(lhs::Vector{Float64})
    return map(enumerate(lhs)) do (i, lhs)
        MockCandidate(i, lhs)
    end
end

function test_first_found_criterion1()
    candidates = _mock_candidates([0.1, 0.2, 0.3, 0.4, 0.5])
    selected_candidates = Coluna.Branching.select_candidates!(
        candidates, Coluna.Algorithm.FirstFoundCriterion(), 3
    )

    @test length(selected_candidates) == 3
    @test selected_candidates[1].local_id == 1
    @test selected_candidates[2].local_id == 2
    @test selected_candidates[3].local_id == 3
end
register!(unit_tests, "branching", test_first_found_criterion1)

function test_most_fractional_criterion1()
    candidates = _mock_candidates([0.1, 0.2, 0.3, 0.4, 0.5])
    selected_candidates = Coluna.Branching.select_candidates!(
        candidates, Coluna.Algorithm.MostFractionalCriterion(), 3
    )

    @test length(selected_candidates) == 3
    @test selected_candidates[1].local_id == 5
    @test selected_candidates[2].local_id == 4
    @test selected_candidates[3].local_id == 3
end
register!(unit_tests, "branching", test_most_fractional_criterion1)

function test_least_fractional_criterion1()
    candidates = _mock_candidates([0.4, 0.3, 0.6, -0.4, -0.8])
    selected_candidates = Coluna.Branching.select_candidates!(
        candidates, Coluna.Algorithm.LeastFractionalCriterion(), 3
    )

    @test length(selected_candidates) == 2
    @test selected_candidates[1].local_id == 5
    @test selected_candidates[2].local_id == 3
end
register!(unit_tests, "branching", test_least_fractional_criterion1)
