for dir in ["advanced_colgen", "gap"]
    dirpath = joinpath(@__DIR__, dir)
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end
end

run_e2e_extra_tests() = run_tests(e2e_extra_tests)