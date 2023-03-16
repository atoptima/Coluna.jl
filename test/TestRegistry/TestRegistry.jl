module TestRegistry
    using Test

    struct Registry
        test_sets::Dict{String, Vector{Function}}
        registered_func_names::Set{String}
        Registry() = new(Dict{String, Vector{Function}}(), Set{String}())
    end

    function register!(tests::Registry, test_set_name::String, func)
        if !haskey(tests.test_sets, test_set_name)
            tests.test_sets[test_set_name] = Function[]
        end
        if !in(tests.registered_func_names, String(Symbol(func)))
            push!(tests.test_sets[test_set_name], func)
            push!(tests.registered_func_names, String(Symbol(func)))
        else
            error("Test \"$(String(Symbol(func)))\" already registered.")
        end
        return
    end

    function run_tests(tests::Registry)
        for (test_set_name, test_set) in tests.test_sets
            @testset "$test_set_name" begin
                for test in test_set
                    test_name = String(Symbol(test))
                    @testset "$test_name" begin
                        test()
                    end
                end
            end
        end
    end

    export Registry, register!, run_tests
end