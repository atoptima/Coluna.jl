module TestRegistry
    using Test

    struct Registry
        test_sets::Dict{String, Vector{Tuple{Bool, Bool, Function}}}
        registered_func_names::Set{String}
        Registry() = new(Dict{String, Vector{Tuple{Bool, Bool, Function}}}(), Set{String}())
    end

    """
    Register a test function `func` in test set `test_set_name`.
    If you want to exclude the test, add kw arg `x = true`.
    If you want to focus on the test (run only this test), add kw arg `f = true`.
    """
    function register!(tests::Registry, test_set_name::String, func; x = false, f = false)
        if !haskey(tests.test_sets, test_set_name)
            tests.test_sets[test_set_name] = Function[]
        end
        if !in(tests.registered_func_names, String(Symbol(func)))
            push!(tests.test_sets[test_set_name], (x, f, func))
            push!(tests.registered_func_names, String(Symbol(func)))
        else
            error("Test \"$(String(Symbol(func)))\" already registered.")
        end
        return
    end

    function run_tests(tests::Registry)
        focus_mode = false
        for (_, test_set) in tests.test_sets
            for (x, f, _) in test_set
                if f
                    focus_mode = true
                    break
                end
            end
            focus_mode && break
        end

        for (test_set_name, test_set) in tests.test_sets
            @testset "$test_set_name" begin
                for (x, f, test) in test_set
                    test_name = String(Symbol(test))
                    @testset "$test_name" begin
                        run = (!focus_mode || f) && !x
                        run && test()
                    end
                end
            end
        end
    end

    export Registry, register!, run_tests
end