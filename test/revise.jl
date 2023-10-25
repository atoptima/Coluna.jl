# return all julia files in a subdirectory (and its subdirectories) of the current directory
function _alljlfiles(basefolder::String)
    allfiles = [
        joinpath(folder, file) for
        (folder, _, files) in walkdir(joinpath(@__DIR__, basefolder)) for file in files
    ]
    return filter(f -> endswith(f, ".jl"), allfiles)
end

typical_test_dirs = [
    joinpath("unit", "ColunaBase"),
    joinpath("unit", "MathProg"),   
    joinpath("unit", "MustImplement"),
    joinpath("unit", "ColGen"),
    joinpath("unit", "Benders"),
    joinpath("unit", "Parser"),
    joinpath("unit", "TreeSearch"),
    joinpath("unit", "Presolve"),
    joinpath("integration", "custom_data"),
    joinpath("integration", "parser"),
    joinpath("integration", "pricing_callback"),
    joinpath("integration", "MOI"),
    joinpath("e2e", "gap"),
    joinpath("e2e_extra", "advanced_colgen"),
    joinpath("e2e_extra", "gap")
]
tracked_dirs = filter(isdir, typical_test_dirs)

all_test_files = Iterators.flatten( # get all julia files in the given subdirectories
    _alljlfiles(folder) for folder in tracked_dirs
)

revise_status_lockfile = ".222-revise-exit-code"

function listen_to_tests(funcs)
    recovering = false
    while true
        try
            entr(all_test_files, [MODULES...]; postpone = recovering) do
                run(`clear`) # clear terminal
                unit_tests = Registry()
                map(funcs) do f
                    f()
                end
            end
        catch e
            recovering = true
            if isa(e, InterruptException)
                if isfile(revise_status_lockfile)
                    rm(revise_status_lockfile)
                end
                return nothing
            elseif isa(e, Revise.ReviseEvalException)
                # needs to reload julia for revise to work again
                open(revise_status_lockfile, "w") do file
                    write(file, "222")
                end
                exit(222)
            elseif !isa(e, TestSetException) &&
                !isa(e, TaskFailedException) &&
                (
                    !isa(e, CompositeException) ||
                    !any(ie -> isa(ie, TaskFailedException), e.exceptions)
                )
                @warn "Caught Exception" exception = (e, catch_backtrace())
            end
        end
    end
end

# include and track all test files
for file in all_test_files
    includet(file)
end

include("unit/run.jl")
include("integration/run.jl")
include("e2e/run.jl")
include("e2e_extra/run.jl")

listen_to_tests([
    run_unit_tests,
    run_integration_tests,
    run_e2e_tests,
    run_e2e_extra_tests
])