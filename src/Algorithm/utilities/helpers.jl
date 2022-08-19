############################################################################################
#
############################################################################################

is_cont_var(form, var_id) = getperenkind(form, var_id) == Continuous
is_int_val(val, tol) = abs(round(val) - val) < tol
dist_to_int(val) = min(val - floor(val), ceil(val) - val)


"""
    IncompleteInterfaceError <: Exception

Exception to be thrown when an interface function is called without default implementation.
"""
struct IncompleteInterfaceError <: Exception
    trait::String # Like the name of the interface
    func_signature::String
end

function Base.showerror(io::IO, e::IncompleteInterfaceError)
    msg = """
    Incomplete implementation of interface $(e.trait).
    $(e.func_signature) not implemented.
    """
    println(io, msg)
    return
end

macro mustimplement(interface_name, sig)
    str_interface_name = string(interface_name)
    fname = sig.args[1]
    args = reduce(sig.args[2:end]; init = Union{String,Expr}[]) do collection, arg
        if isa(arg, Symbol)
            push!(collection, "::", :(typeof($(esc(arg)))), ", ")
        end
        return collection
    end
    pop!(args)

    type_of_args_expr = Expr(:tuple, args...)
    return quote
        $(esc(sig)) = throw(
                IncompleteInterfaceError(
                    $str_interface_name,
                    string($fname, "(", $type_of_args_expr..., ")")
                )
            )
    end
end