for dir in ["MustImplement", "ColunaBase", "MathProg", "ColGen", "Benders", "Branching", "Algorithm"]
    dirpath = joinpath(@__DIR__, dir)
    for filename in readdir(dirpath)
        includet(joinpath(dirpath, filename))
    end
end

# for dir in readdir(".")
#     dirpath = joinpath(dir)
#     !isdir(dirpath) && continue
#     for filename in readdir(dirpath)
#         println("include(joinpath(\"",dirpath,"\", \"", filename,"\"))")
#     end
# end

run_unit_tests() = run_tests(unit_tests)
