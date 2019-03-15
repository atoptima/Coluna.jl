#Thanks to https://github.com/JuliaLang/julia/issues/18252
macro callsuper(ex)
    ex.head == :call || error("@invoke requires a call expression")
    args = ex.args[2:end]
    types = Symbol[]
    vals = Symbol[]
    blk = quote end
    for arg in args
           val = gensym()
           typ = gensym()
           push!(vals, val)
           push!(types, typ)
           if isa(arg,Expr) && arg.head == :(::) && length(arg.args) == 2
               push!(blk.args, :($typ = $(esc(arg.args[2]))))
               push!(blk.args, :($val = $(esc(arg.args[1]))::$typ))
           else
               push!(blk.args, :($val = $(esc(arg))))
               push!(blk.args, :($typ = typeof($val)))
           end
    end
    push!(blk.args, :(invoke($(esc(ex.args[1])), Tuple{$(types...)}, $(vals...))))
    return blk
end

function print_moi_constraints(optimizer::MOI.AbstractOptimizer)
    println("-------------- Printing MOI constraints")
    for (F,S) in MOI.get(optimizer, MOI.ListOfConstraints())
        println("Function type: ", F)
        for ci in MOI.get(optimizer, MOI.ListOfConstraintIndices{F,S}())
            println("Constraint ", ci.value)
        end
    end
    println("------------------------------------------")
end

elapsed_solve_time() = (time() - __initial_solve_time)
