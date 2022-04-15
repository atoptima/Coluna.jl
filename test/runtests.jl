using Coluna, ReTest

include("ColunaTests.jl")

retest(Coluna, ColunaTests)

# Run a specific test:
#retest(ColunaTests, "toy instance with objective constant")