dirs = [
    "custom_data"
]

for dir in dirs
    dirpath = joinpath(@__DIR__, dir)
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end
end

run_integration_tests() = run_tests(integration_tests)