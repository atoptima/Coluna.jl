# import Coluna
include("../src/Coluna.jl")

using Base.Test

import Cbc
import MathOptInterface, MathOptInterface.Utilities

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna

include("test_utils.jl")
include("colunabasictests.jl")
include("colgenroot.jl")
# include("test_MOIWrapper.jl")




testdefaultbuilders()
testpuremaster()
testcolgenatroot()
# branch_and_bound_test_instance()
# branch_and_bound_bigger_instances()
# simple_MOI_calls_to_ColunaModelOptimizer()
# tests_with_CachingOptimizer()
