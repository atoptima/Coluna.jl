using Coluna, ReTest

include("ColunaTests.jl")

# Run a specific test:
# retest(ColunaTests, "Improve relaxation callback")

# retest(Coluna, ColunaTests)


include("unit/run.jl")
