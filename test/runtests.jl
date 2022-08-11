using Coluna, ReTest

include("ColunaTests.jl")

retest(Coluna, ColunaTests)

# Run a specific test:
#retest(ColunaTests, "Issue 550 - continuous variables in subproblem")