for dir in ["gap", "TreeSearch"]
    dirpath = joinpath(@__DIR__, dir)
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end
end

run_e2e_tests() = run_tests(e2e_tests)
