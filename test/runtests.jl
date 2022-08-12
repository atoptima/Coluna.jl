using Coluna, ReTest

include("ColunaTests.jl")

retest(Coluna, ColunaTests)

# Run a specific test:
#retest(ColunaTests, "Issue 591 - get dual of generated cuts")