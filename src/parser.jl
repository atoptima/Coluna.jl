const _KW_HEADER = Val{:header}()
const _KW_MASTER = Val{:master}()
const _KW_SUBPROBLEM = Val{:subproblem}()
const _KW_BOUNDS = Val{:bounds}()
const _KW_CONSTRAINTS = Val{:constraints}()

const _KW_SECTION = Dict(
    # _KW_MASTER
    "master" => _KW_MASTER,
    # _KW_SUBPROBLEM
    "dw_sp" => _KW_SUBPROBLEM,
    "sp" => _KW_SUBPROBLEM,
    # Integ
    "int" => Integ,
    "integer" => Integ,
    "integers" => Integ,
    # Continuous
    "cont" => Continuous,
    "continuous" => Continuous,
    # Binary
    "bin" => Binary,
    "binary" => Binary,
    "binaries" => Binary,
    # _KW_BOUNDS
    "bound" => _KW_BOUNDS,
    "bounds" => _KW_BOUNDS,
)

const _KW_SUBSECTION = Dict(
    # MaxSense
    "max" => MaxSense,
    "maximize" => MaxSense,
    "maximise" => MaxSense,
    "maximum" => MaxSense,
    # MinSense
    "min" => MinSense,
    "minimize" => MinSense,
    "minimise" => MinSense,
    "minimum" => MinSense,
    # _KW_CONSTRAINTS
    "subject to" => _KW_CONSTRAINTS,
    "such that" => _KW_CONSTRAINTS,
    "st" => _KW_CONSTRAINTS,
    "s.t." => _KW_CONSTRAINTS,
    # MasterPureVar
    "pure" => MasterPureVar,
    "pures" => MasterPureVar,
    # MasterRepPricingVar
    "representative" => MasterRepPricingVar,
    "representatives" => MasterRepPricingVar,
    # DwSpPricingVar
    "pricing" => DwSpPricingVar,
)

const coeff_re = "\\d+(\\.\\d+)?"

mutable struct ExprCache
    vars::Dict{String, Float64}
end

mutable struct VarCache
    kind::VarKind
    duty::MathProg.Duty
    lb::Float64
    ub::Float64
end

mutable struct ConstrCache
    lhs::ExprCache
    sense::ConstrSense
    rhs::Float64
end

mutable struct SubproblemCache
    constraints::Vector{ConstrCache}
    varids::Vector{String}
end

mutable struct MasterCache
    sense::Type{<:AbstractSense}
    objective::ExprCache
    constraints::Vector{ConstrCache}
end

mutable struct ReadCache
    master::MasterCache
    subproblems::Dict{Int64,SubproblemCache}
    variables::Dict{String,VarCache}
end

function ReadCache()
    return ReadCache(
        MasterCache(
            MinSense,
            ExprCache(
                Dict{String, Float64}()
            ),
            ConstrCache[]
        ),
        Dict{Int64,SubproblemCache}(),
        Dict{String,VarCache}()
    )
end

function _strip_identation(l::AbstractString)
    m = match(r"^(\s+)(.+)", l)
    if m !== nothing
        return m[2]
    end
    return l
end

function _strip_line(l::AbstractString)
    new_line = ""
    for m in eachmatch(r"[^\s]+", l)
        new_line = string(new_line, m.match)
    end
    return new_line
end

function _get_vars_list(l::AbstractString)
    vars = String[]
    for m in eachmatch(r"(\w+)", l)
        push!(vars, String(m[1]))
    end
    return vars
end

function _read_expression(l::AbstractString)
    line = _strip_line(l)
    vars = Dict{String, Float64}()
    first_m = match(Regex("^([+-])?($coeff_re)?\\*?(\\w+)(.*)"), line) # first element of expr
    if first_m !== nothing
        sign = first_m[1] === nothing ? "+" : first_m[1] # has a sign
        coeff = first_m[2] === nothing ? "1" : first_m[2] # has a coefficient
        cost = parse(Float64, string(sign, coeff))
        vars[String(first_m[4])] = cost
        for m in eachmatch(Regex("([+-])($coeff_re)?\\*?(\\w+)"), first_m[5]) # rest of the elements
            coeff = m[2] === nothing ? "1" : m[2]
            cost = parse(Float64, string(m[1], coeff))
            vars[String(m[4])] = cost
        end
    end
    return ExprCache(vars)
end

function _read_constraint(l::AbstractString)
    line = _strip_line(l)
    m = match(Regex("(.+)(>=|<=|==)($coeff_re)"), line)
    if m !== nothing
        lhs = _read_expression(m[1])
        sense = if m[2] == ">="
            Greater
        else
            if m[2] == "<="
                Less
            else
                Equal
            end
        end
        rhs = parse(Float64, m[3])
        return ConstrCache(lhs, sense, rhs)
    end
    return nothing
end

function _read_bounds(l::AbstractString, r::Regex)
    line = _strip_line(l)
    vars = String[]
    bound1, bound2 = ("","")
    m = match(r, line)
    if m !== nothing
        vars = _get_vars_list(m[4]) # separate variables as "x_1, x_2" into a list [x_1, x_2]
        if m[1] !== nothing # has lower bound (nb <= var) or upper bound (nb >= var)
            bound1 = String(m[2])
        end
        if m[5] !== nothing # has upper bound (var <= nb) or lower bound (var >= nb)
            bound2 = String(m[6])
        end
    end
    return vars, bound1, bound2
end

function read_master!(sense::Type{<:AbstractSense}, cache::ReadCache, line::AbstractString)
    obj = _read_expression(line)
    cache.master.sense = sense
    cache.master.objective = obj
end

function read_master!(::Val{:constraints}, cache::ReadCache, line::AbstractString)
    constr = _read_constraint(line)
    if constr !== nothing
        push!(cache.master.constraints, constr)
    end
end

read_master!(::Any, cache::ReadCache, line::AbstractString) = nothing

function read_subproblem!(cache::ReadCache, line::AbstractString, nb_sp::Int64)
    constr = _read_constraint(line)
    if constr !== nothing
        varids = collect(keys(constr.lhs.vars))
        if haskey(cache.subproblems, nb_sp)
            push!(cache.subproblems[nb_sp].constraints, constr)
            push!(cache.subproblems[nb_sp].varids, varids...)
            unique!(cache.subproblems[nb_sp].varids)
        else
            cache.subproblems[nb_sp] = SubproblemCache([constr], varids)
        end
    end
end

function read_bounds!(cache::ReadCache, line::AbstractString)
    vars = String[]
    if occursin("<=", line)
        less_r = Regex("(($coeff_re)<=)?([\\w,]+)(<=($coeff_re))?")
        vars, lb, ub = _read_bounds(line, less_r)
    end
    if occursin(">=", line)
        greater_r = Regex("(($coeff_re)>=)?([\\w,]+)(>=($coeff_re))?")
        vars, ub, lb = _read_bounds(line, greater_r)
    end
    for v in vars
        if haskey(cache.variables, v)
            if lb != ""
                cache.variables[v].lb = parse(Float64, lb)
            end
            if ub != ""
                cache.variables[v].ub = parse(Float64, ub)
            end
        end
    end
end

function read_variables!(kind::VarKind, duty::MathProg.Duty, cache::ReadCache, line::AbstractString)
    vars = _get_vars_list(line)
    for v in vars
        cache.variables[v] = VarCache(kind, duty, -Inf, Inf)
    end
end

read_variables!(::Any, ::Any, ::ReadCache, ::AbstractString) = nothing

function reformfromcache(cache::ReadCache)
    env = Env{VarId}(Params())
    reform = Reformulation(env)

    #create subproblems
    subproblems = []
    all_spvars = Dict{String, Variable}()
    for (_, sp) in cache.subproblems
        spform = nothing
        for varid in sp.varids
            var = cache.variables[varid]
            if var.duty <= DwSpPricingVar || var.duty <= MasterRepPricingVar
                if spform === nothing
                    spform = create_formulation!(
                        env,
                        DwSp(nothing, nothing, nothing, var.kind);
                        obj_sense = cache.master.sense
                    )
                end
                v = setvar!(spform, varid, DwSpPricingVar; lb = var.lb, ub = var.ub, kind = var.kind)
                setperencost!(spform, v, cache.master.objective.vars[varid])
                all_spvars[varid] = v
            end
        end
        push!(subproblems, spform)
        add_dw_pricing_sp!(reform, spform)
    end

    master = create_formulation!(
        env,
        DwMaster();
        obj_sense = cache.master.sense,
        parent_formulation = reform
    )
    setmaster!(reform, master)
    mastervars = Dict{String, Variable}()

    #create master variables
    for (varid, cost) in cache.master.objective.vars
        var = cache.variables[varid]
        if var.duty <= MasterPureVar
            v = setvar!(master, varid, MasterPureVar; lb = var.lb, ub = var.ub, kind = var.kind)
        else
            v = setvar!(master, varid, MasterRepPricingVar; lb = var.lb, ub = var.ub, kind = var.kind, id = getid(all_spvars[varid]))
        end
        setperencost!(master, v, cost)
        mastervars[varid] = v
    end

    #create master constraints
    i = 1
    constraints = []
    for constr in cache.master.constraints
        members = Dict{VarId, Float64}()
        constr_duty = MasterPureConstr
        for (varid, coeff) in constr.lhs.vars
            var = cache.variables[varid]
            if var.duty <= DwSpPricingVar || var.duty <= MasterRepPricingVar # check if should be a MasterMixedConstr
                constr_duty = MasterMixedConstr
            end
            push!(members, getid(mastervars[varid]) => coeff)
        end
        c = setconstr!(master, "c$i", constr_duty; rhs = constr.rhs, sense = constr.sense, members = members)
        push!(constraints, c)
        i += 1
    end
    #create subproblems constraints in master
    for (_, sp) in cache.subproblems
        for constr in sp.constraints
            members = Dict(getid(mastervars[varid]) => coeff for (varid, coeff) in constr.lhs.vars)
            c = setconstr!(master, "c$i", MasterMixedConstr; rhs = constr.rhs, sense = constr.sense, members = members)
            push!(constraints, c)
            i += 1
        end
    end

    for sp in subproblems
        sp.parent_formulation = master
        closefillmode!(getcoefmatrix(sp))
    end
    closefillmode!(getcoefmatrix(master))

    return env, master, subproblems, constraints
end

function reformfromstring(s::String)
    lines = split(s, "\n", keepempty=false)
    cache = ReadCache()
    nb_subproblems = 0
    section = _KW_HEADER
    sub_section = _KW_HEADER

    for l in lines
        line = _strip_identation(l)
        lower_line = lowercase(line)
        if haskey(_KW_SECTION, lower_line)
            section = _KW_SECTION[lower_line]
            if section == _KW_SUBPROBLEM
                nb_subproblems += 1
            end
            continue
        end
        if haskey(_KW_SUBSECTION, lower_line)
            sub_section = _KW_SUBSECTION[lower_line]
            continue
        end
        if section == _KW_MASTER
            read_master!(sub_section, cache, line)
            continue
        end
        if section == _KW_SUBPROBLEM
            read_subproblem!(cache, line, nb_subproblems)
            continue
        end
        if section == _KW_BOUNDS
            read_bounds!(cache, line)
            continue
        end
        read_variables!(section, sub_section, cache, line)
    end

    env, master, subproblems, constraints = reformfromcache(cache)

    return env, master, subproblems, constraints
end
