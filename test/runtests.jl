import Coluna
using Base.Test

import Cbc
import MathOptInterface, MathOptInterface.Utilities

const MOIU = MathOptInterface.Utilities
const MOI = MathOptInterface
const CL = Coluna

include("test_utils.jl")
include("colunabasictests.jl")
include("colgenroot.jl")
# include("test_MOIWrapper.jl")




testdefaultbuilders()
testpuremaster()
testcolgenatroot()
branch_and_bound_test_instance()
branch_and_bound_bigger_instances()
# simple_MOI_calls_to_ColunaModelOptimizer()
# tests_with_CachingOptimizer()
