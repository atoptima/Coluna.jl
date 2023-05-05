"""
Exposes `@mustimplement` macro to help developers identifying API definitions.
"""
module MustImplement

using Random

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

"""
    @mustimplement "Interface name" f(a,b,c) = nothing

Converts into a fallback for function `f(a,b,c)` that throws a `IncompleteInterfaceError`.
"""
macro mustimplement(interface_name, sig)
    if !(sig.head == :(=) && sig.args[1].head == :call && sig.args[2].head == :block)
        err_msg = """
        Cannot generate fallback for function $(string(sig)).
        Got:
        - sig.head = $(sig.head) instead of :(=)
        - sig.args[1].head = $(sig.args[1].head) instead of :call
        - sig.args[2].head = $(sig.args[2].head) instead of :block
        """
        error(err_msg)
    end
    sig = sig.args[1] # we only consider the call.
    str_interface_name = string(interface_name)
    fname = string(sig.args[1])
    args = reduce(sig.args[2:end]; init = Union{String,Expr}[]) do collection, arg
        varname = if isa(arg, Symbol) # arg without type
            arg
        elseif isa(arg, Expr) && arg.head == :(::) # variable with its type
            if length(arg.args) == 1 # :(::Type) case
                varname = Symbol(randstring('a':'z', 24))
                vartype = arg.args[1]
                arg.args = [varname, vartype] # change signature of the method
                varname
            elseif length(arg.args) == 2 # :(var::Type) case
                arg.args[1]
            else
                nothing
            end
        else
            nothing
        end
        if !isnothing(varname)
            push!(collection, "::", :(typeof($(esc(varname)))), ", ")
        end
        return collection
    end
    if length(args) > 0
        pop!(args)
    end

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

export @mustimplement, IncompleteInterfaceError

end