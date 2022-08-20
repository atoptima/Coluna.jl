using Coluna, ReTest

include("ColunaTests.jl")

#retest(Coluna, ColunaTests)

# Run a specific test:
retest(ColunaTests, "Decomposition with representatives and single subproblem")
retest(ColunaTests, "Decomposition with representatives and multiple subproblems")
