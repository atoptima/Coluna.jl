for dir in ["MustImplement", "ColunaBase", "MathProg"]
    dirpath = joinpath(@__DIR__, dir)
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end
end

run_unit_tests() = run_tests(unit_tests)
