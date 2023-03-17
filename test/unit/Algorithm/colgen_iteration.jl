@testset "Algorithm - colgen iteration" begin

    function get_reform_master_and_vars()
        form_string1 = """
            master
                min
                3x1 + 4x2 + 1000z
                s.t.
                x1 + x2 + z >= 4

            dw_sp
                min x1
                s.t.
                x1 >= 1

            dw_sp
                min x2
                s.t.
                x2 >= 1

            integer
                representatives
                    x1, x2

            continuous
                artificial
                    z
        """

        _, master, _, _, reform = reformfromstring(form_string1)
        vars_by_name = Dict{String, ClMP.Variable}(ClMP.getname(master, var) => var for (_, var) in ClMP.getvars(master))
        return reform, master, vars_by_name
    end

    @testset "" begin
        reform, _, _ = get_reform_master_and_vars()
    
        context = nothing
        phase = nothing
        ClA.run_colgen_iteration!(context, phase, reform)
    end
end