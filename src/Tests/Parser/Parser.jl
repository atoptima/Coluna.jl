module Parser
    using Coluna, DynamicSparseArrays

    const CL = Coluna
    const ClMP = Coluna.MathProg
    const ClB = Coluna.ColunaBase

    const _KW_HEADER = Val{:header}()
    const _KW_MASTER = Val{:master}()
    const _KW_SUBPROBLEM = Val{:subproblem}()
    const _KW_SEPARATION = Val{:separation}()
    const _KW_BOUNDS = Val{:bounds}()
    const _KW_CONSTRAINTS = Val{:constraints}()

    const _KW_SECTION = Dict(
        # _KW_MASTER
        "master" => _KW_MASTER,
        # _KW_SUBPROBLEM
        "dw_sp" => _KW_SUBPROBLEM,
        "sp" => _KW_SUBPROBLEM,
        # _KW_SEPARATION
        "benders_sp" => _KW_SEPARATION,
        # Integ
        "int" => ClMP.Integ,
        "integer" => ClMP.Integ,
        "integers" => ClMP.Integ,
        # Continuous
        "cont" => ClMP.Continuous,
        "continuous" => ClMP.Continuous,
        # Binary
        "bin" => ClMP.Binary,
        "binary" => ClMP.Binary,
        "binaries" => ClMP.Binary,
        # _KW_BOUNDS
        "bound" => _KW_BOUNDS,
        "bounds" => _KW_BOUNDS,
    )

    const _KW_SUBSECTION = Dict(
        # MaxSense
        "max" => CL.MaxSense,
        "maximize" => CL.MaxSense,
        "maximise" => CL.MaxSense,
        "maximum" => CL.MaxSense,
        # MinSense
        "min" => CL.MinSense,
        "minimize" => CL.MinSense,
        "minimise" => CL.MinSense,
        "minimum" => CL.MinSense,
        # _KW_CONSTRAINTS
        "subject to" => _KW_CONSTRAINTS,
        "such that" => _KW_CONSTRAINTS,
        "st" => _KW_CONSTRAINTS,
        "s.t." => _KW_CONSTRAINTS,
        # MasterPureVar
        "pure" => ClMP.MasterPureVar,
        "pures" => ClMP.MasterPureVar,
        # MasterRepPricingVar
        "representative" => ClMP.MasterRepPricingVar,
        "representatives" => ClMP.MasterRepPricingVar,
        # DwSpPricingVar
        "pricing" => ClMP.DwSpPricingVar,
        # MasterArtVar
        "artificial" => ClMP.MasterArtVar,
        "artificials" => ClMP.MasterArtVar,
        # MasterColumns
        "columns" => ClMP.MasterCol,
        # MasterRepPricingSetupVar
        "pricing_setup" => ClMP.MasterRepPricingSetupVar,
        # Benders first stage variable
        "first_stage" => ClMP.MasterPureVar,
        "second_stage_cost" => ClMP.MasterBendSecondStageCostVar,
        # Benders second stage variable
        "second_stage" => ClMP.BendSpSepVar,
        "second_stage_artificial" => ClMP.BendSpSecondStageArtVar
    )

    const _KW_CONSTR_DUTIES = Dict(
        "MasterConvexityConstr" => ClMP.MasterConvexityConstr,
        "BendTechConstr" => ClMP.BendSpTechnologicalConstr,
    )

    const coeff_re = "\\d+(\\.\\d+)?"

    struct UndefObjectiveParserError <: Exception end
    export UndefObjectiveParserError

    struct UndefVarParserError <: Exception
        msg::String
    end
    export UndefVarParserError

    mutable struct ExprCache
        vars::Dict{String, Float64}
        constant::Float64
    end

    mutable struct VarCache
        kind::ClMP.VarKind
        duty::ClMP.Duty
        lb::Float64
        ub::Float64
    end

    mutable struct ConstrCache
        lhs::ExprCache
        sense::ClMP.ConstrSense
        rhs::Float64
        duty::Union{Nothing,ClMP.Duty}
    end

    mutable struct ProblemCache
        sense::Type{<:ClB.AbstractSense}
        objective::ExprCache
        constraints::Vector{ConstrCache}
    end

    mutable struct ReadCache
        benders_sp_type::Bool
        dw_sp_type::Bool
        master::ProblemCache
        subproblems::Dict{Int64,ProblemCache}
        variables::Dict{String,VarCache}
    end

    function Base.showerror(io::IO, ::UndefObjectiveParserError)
        msg = "No objective function provided"
        println(io, msg)
    end

    function Base.showerror(io::IO, e::UndefVarParserError)
        println(io, e.msg)
        return
    end

    function ReadCache()
        return ReadCache(
            false, false,
            ProblemCache(
                CL.MinSense,
                ExprCache(
                    Dict{String, Float64}(), 0.0
                ),
                ConstrCache[]
            ),
            Dict{Int64,ProblemCache}(),
            Dict{String,VarCache}()
        )
    end

    function _strip_identation(l::AbstractString)
        m = match(r"^(\s+)(.+)", l)
        if !isnothing(m)
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
        constant = 0.0
        first_m = match(Regex("^([+-])?($coeff_re)?\\*?([a-zA-Z]+\\w*)?(.*)"), line) # first element of expr
        if !isnothing(first_m)
            sign = isnothing(first_m[1]) ? "+" : first_m[1] # has a sign
            coeff = isnothing(first_m[2]) ? "1" : first_m[2] # has a coefficient
            cost = parse(Float64, string(sign, coeff))
            vars[String(first_m[4])] = cost
            for m in eachmatch(Regex("([+-])($coeff_re)?\\*?([a-zA-Z]+\\w*)?"), first_m[5]) # rest of the elements
                coeff = isnothing(m[2]) ? "1" : m[2]
                cost = parse(Float64, string(m[1], coeff))
                if isnothing(m[4])
                    constant += cost
                else
                    vars[String(m[4])] = cost
                end
            end
        end
        return ExprCache(vars, constant)
    end

    function _read_constraint(l::AbstractString)
        line = _strip_line(l)
        m = match(Regex("(.+)(>=|<=|==)(-?$coeff_re)(\\{([a-zA-Z]+)\\})?"), line)
        if !isnothing(m)
            lhs = _read_expression(m[1])
            sense = if m[2] == ">="
                ClMP.Greater
            else
                if m[2] == "<="
                    ClMP.Less
                else
                    ClMP.Equal
                end
            end
            rhs = parse(Float64, m[3])
            duty = isnothing(m[6]) ? nothing : _KW_CONSTR_DUTIES[m[6]]
            return ConstrCache(lhs, sense, rhs, duty)
        end
        return nothing
    end

    function _read_bounds(l::AbstractString, r::Regex)
        line = _strip_line(l)
        vars = String[]
        bound1, bound2 = ("","")
        m = match(r, line)
        if !isnothing(m)
            vars = _get_vars_list(m[4]) # separate variables as "x_1, x_2" into a list [x_1, x_2]
            if !isnothing(m[1]) # has lower bound (nb <= var) or upper bound (nb >= var)
                bound1 = String(m[2])
            end
            if !isnothing(m[5]) # has upper bound (var <= nb) or lower bound (var >= nb)
                bound2 = String(m[6])
            end
        end
        return vars, bound1, bound2
    end

    function read_master!(sense::Type{<:ClB.AbstractSense}, cache::ReadCache, line::AbstractString)
        obj = _read_expression(line)
        cache.master.sense = sense
        cache.master.objective = obj
    end

    function read_master!(::Val{:constraints}, cache::ReadCache, line::AbstractString)
        constr = _read_constraint(line)
        if !isnothing(constr)
            push!(cache.master.constraints, constr)
        end
    end

    read_master!(::Any, cache::ReadCache, line::AbstractString) = nothing

    function read_subproblem!(sense::Type{<:ClB.AbstractSense}, cache::ReadCache, line::AbstractString, nb_sp::Int64)
        obj = _read_expression(line)
        if haskey(cache.subproblems, nb_sp)
            cache.subproblems[nb_sp].sense = sense
            cache.subproblems[nb_sp].obj = obj
        else
            cache.subproblems[nb_sp] = ProblemCache(sense, obj, [])
        end
    end

    function read_subproblem!(::Val{:constraints}, cache::ReadCache, line::AbstractString, nb_sp::Int64)
        constr = _read_constraint(line)
        if !isnothing(constr)
            if haskey(cache.subproblems, nb_sp)
                push!(cache.subproblems[nb_sp].constraints, constr)
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

    function read_variables!(kind::ClMP.VarKind, duty::ClMP.Duty, cache::ReadCache, line::AbstractString)
        vars = _get_vars_list(line)
        for v in vars
            cache.variables[v] = VarCache(kind, duty, -Inf, Inf)
        end
    end

    read_variables!(::Any, ::Any, ::ReadCache, ::AbstractString) = nothing

    function create_subproblems!(::Val{:subproblem}, env::Env{ClMP.VarId}, cache::ReadCache, ::Nothing)
        i = 1
        constraints = ClMP.Constraint[]
        subproblems = ClMP.Formulation{ClMP.DwSp}[]
        all_spvars = Dict{String, Tuple{ClMP.Variable, ClMP.Formulation{ClMP.DwSp}}}()
        for (_, sp) in cache.subproblems
            spform = nothing
            for (varid, cost) in sp.objective.vars
                if haskey(cache.variables, varid)
                    var = cache.variables[varid]
                    if var.duty <= ClMP.DwSpPricingVar || var.duty <= ClMP.MasterRepPricingVar || var.duty <= ClMP.MasterRepPricingSetupVar
                        if isnothing(spform)
                            spform = ClMP.create_formulation!(
                                env,
                                ClMP.DwSp(nothing, nothing, nothing, ClMP.Integ);
                                obj_sense = sp.sense
                            )
                        end
                        duty = ClMP.DwSpPricingVar
                        if var.duty <= ClMP.MasterRepPricingSetupVar
                            duty = ClMP.DwSpSetupVar
                        end
                        v = ClMP.setvar!(spform, varid, duty; lb = var.lb, ub = var.ub, kind = var.kind)
                        if var.duty <= ClMP.DwSpPricingVar
                            spform.duty_data.setup_var = ClMP.getid(v)
                        end
                        ClMP.setperencost!(spform, v, cost)
                        all_spvars[varid] = (v, spform)
                    end
                else
                    throw(UndefVarParserError("Variable $varid duty and/or kind not defined"))
                end
            end
            for constr in sp.constraints
                members = Dict(ClMP.getid(all_spvars[varid][1]) => coeff for (varid, coeff) in constr.lhs.vars)
                c = ClMP.setconstr!(spform, "sp_c$i", ClMP.DwSpPureConstr; rhs = constr.rhs, sense = constr.sense, members = members)
                push!(constraints, c)
                i += 1
            end
            push!(subproblems, spform)
        end
        return subproblems, all_spvars, constraints
    end

    function create_subproblems!(::Val{:separation}, env::Env{ClMP.VarId}, cache::ReadCache, master, mastervars)
        i = 1
        constraints = ClMP.Constraint[]
        subproblems = ClMP.Formulation{ClMP.BendersSp}[]
        all_spvars = Dict{String, Tuple{ClMP.Variable, ClMP.Formulation{ClMP.BendersSp}}}()
        for (_, sp) in cache.subproblems 
            spform = ClMP.create_formulation!(
                env,
                ClMP.BendersSp();
                obj_sense = sp.sense
            )
            for (varid, cost) in sp.objective.vars
                if haskey(cache.variables, varid)
                    var = cache.variables[varid]
                    if var.duty <= ClMP.BendSpSecondStageArtVar || var.duty <= ClMP.BendSpSepVar
                        explicit = true
                        duty = var.duty
                        v = ClMP.setvar!(spform, varid, duty; lb = var.lb, ub = var.ub, kind = var.kind, is_explicit = explicit)
                        ClMP.setperencost!(spform, v, cost)
                        all_spvars[varid] = (v, spform)
                    end
                    if var.duty <= ClMP.MasterPureVar || var.duty <= ClMP.MasterBendSecondStageCostVar
                        if var.duty <= ClMP.MasterPureVar
                            duty = ClMP.BendSpFirstStageRepVar
                            explicit = false
                        end
                        if var.duty <= ClMP.MasterBendSecondStageCostVar
                            duty = ClMP.BendSpCostRepVar
                            explicit = false
                        end
                        master_var = mastervars[varid]
                        v = ClMP.clonevar!(master, spform, master, master_var, duty; cost = ClMP.getcurcost(master, master_var), is_explicit = false)
                        all_spvars[varid] = (v, spform)
                        if var.duty <= ClMP.MasterBendSecondStageCostVar
                            spform.duty_data.second_stage_cost_var = ClMP.getid(v)
                        end
                    end
                else
                    throw(UndefVarParserError("Variable $varid duty and/or kind not defined"))
                end
            end
            for constr in sp.constraints
                duty = ClMP.BendSpPureConstr
                if !isnothing(constr.duty)
                    duty = constr.duty
                    @assert duty <= ClMP.BendSpTechnologicalConstr
                end
                members = Dict(ClMP.getid(all_spvars[varid][1]) => coeff for (varid, coeff) in constr.lhs.vars)
                c = ClMP.setconstr!(spform, "sp_c$i", duty; rhs = constr.rhs, sense = constr.sense, members = members)
                push!(constraints, c)
                i += 1
            end
            push!(subproblems, spform)
        end
        return subproblems, all_spvars, constraints
    end

    function add_dw_master_vars!(master::ClMP.Formulation, master_duty, all_spvars::Dict, cache::ReadCache)
        mastervars = Dict{String, ClMP.Variable}()
        for (varid, cost) in cache.master.objective.vars
            if haskey(cache.variables, varid)
                var = cache.variables[varid]
                if var.duty <= ClMP.AbstractOriginMasterVar || var.duty <= ClMP.AbstractAddedMasterVar
                    is_explicit = !(var.duty <= ClMP.AbstractImplicitMasterVar)
                    v = ClMP.setvar!(master, varid, var.duty; lb = var.lb, ub = var.ub, kind = var.kind, is_explicit = is_explicit)
                else
                    if haskey(all_spvars, varid)
                        var, sp = all_spvars[varid]
                        duty = ClMP.MasterRepPricingVar
                        explicit = false
                        if ClMP.getduty(ClMP.getid(var)) <= ClMP.DwSpSetupVar
                            duty = ClMP.MasterRepPricingSetupVar
                        elseif ClMP.getduty(ClMP.getid(var)) <= ClMP.BendSpFirstStageRepVar
                            duty = ClMP.MasterPureVar
                            explicit = true
                        end
                        v = ClMP.clonevar!(sp, master, sp, var, duty; cost = ClMP.getcurcost(sp, var), is_explicit = explicit)
                    else
                        throw(UndefVarParserError("Variable $varid not present in any subproblem"))
                    end
                end
                ClMP.setperencost!(master, v, cost)
                mastervars[varid] = v
            else
                throw(UndefVarParserError("Variable $varid duty and/or kind not defined"))
            end
        end
        return mastervars
    end

    function add_bend_master_vars!(master::ClMP.Formulation, master_duty, cache::ReadCache)
        mastervars = Dict{String, ClMP.Variable}()
        for (varid, cost) in cache.master.objective.vars
            if haskey(cache.variables, varid)
                var = cache.variables[varid]
                v = ClMP.setvar!(master, varid, var.duty; lb = var.lb, ub = var.ub, kind = var.kind, is_explicit = true)
                ClMP.setperencost!(master, v, cost)
                mastervars[varid] = v
            else
                throw(UndefVarParserError("Variable $varid duty and/or kind not defined"))
            end
        end
        return mastervars
    end

    function add_master_constraints!(subproblems, master::ClMP.Formulation, mastervars::Dict{String, ClMP.Variable}, constraints::Vector{ClMP.Constraint}, cache::ReadCache)
        #create master constraints
        i = 1
        for constr in cache.master.constraints
            members = Dict{ClMP.VarId, Float64}()
            constr_duty = ClMP.MasterPureConstr
            if !isnothing(constr.duty)
                constr_duty = constr.duty
            end
            for (varid, coeff) in constr.lhs.vars
                if haskey(cache.variables, varid)
                    var = cache.variables[varid]
                    if var.duty <= ClMP.DwSpPricingVar || var.duty <= ClMP.MasterRepPricingVar # check if should be a MasterMixedConstr
                        constr_duty = ClMP.MasterMixedConstr
                    end
                    if haskey(mastervars, varid)
                        push!(members, ClMP.getid(mastervars[varid]) => coeff)
                    else
                        throw(UndefVarParserError("Variable $varid not present in objective function"))
                    end
                else
                    throw(UndefVarParserError("Variable $varid duty and/or kind not defined"))
                end
            end
            c = ClMP.setconstr!(master, "c$i", constr_duty; rhs = constr.rhs, sense = constr.sense, members = members)
            if constr_duty <= ClMP.MasterConvexityConstr
                setup_var_id = collect(keys(filter(x -> ClMP.getduty(x[1]) <= ClMP.MasterRepPricingSetupVar, members)))[1]
                spform = collect(values(filter(sp -> haskey(sp, setup_var_id), subproblems)))[1] # dw pricing sps
                if constr.sense == ClMP.Less
                    spform.duty_data.upper_multiplicity_constr_id = ClMP.getid(c)
                elseif constr.sense == ClMP.Greater
                    spform.duty_data.lower_multiplicity_constr_id = ClMP.getid(c)
                else
                    throw(UndefConstraintParserError("Convexity constraint $c must be <= or >="))
                end
            end
            push!(constraints, c)
            i += 1
        end
    end

    function reformfromcache(cache::ReadCache)
        if isempty(cache.master.objective.vars)
            throw(UndefObjectiveParserError())
        end
        if isempty(cache.variables)
            throw(UndefVarParserError("No variable duty and kind defined"))
        end
        env = Env{ClMP.VarId}(CL.Params())

        dec = cache.benders_sp_type ? Val(:separation) : Val(:subproblem)
        master_duty = cache.benders_sp_type ? ClMP.BendersMaster() : ClMP.DwMaster()

        dw_sps = Dict{ClMP.FormId, ClMP.Formulation{ClMP.DwSp}}()
        benders_sps = Dict{ClMP.FormId, ClMP.Formulation{ClMP.BendersSp}}()

        origform = ClMP.create_formulation!(
            env,
            ClMP.Original();
            obj_sense = cache.master.sense,
        )

        # Create master first.
        master =  ClMP.create_formulation!(
            env,
            master_duty;
            obj_sense = cache.master.sense,
        )
        # ugly trick here.
        dw_sps = Dict{ClMP.FormId, ClMP.Formulation{ClMP.DwSp}}()
        benders_sps = Dict{ClMP.FormId, ClMP.Formulation{ClMP.BendersSp}}()
        reform = ClMP.Reformulation(env, origform, master, dw_sps, benders_sps)
        master.parent_formulation = reform
    
        # Populate master & create subproblems then.
        if cache.benders_sp_type
            mastervars = add_bend_master_vars!(master, master_duty, cache)
            ClMP.setobjconst!(master, cache.master.objective.constant)
            subproblems, all_spvars, constraints = create_subproblems!(dec, env, cache, master, mastervars)
            for sp in subproblems
                reform.benders_sep_subprs[ClMP.getuid(sp)] = sp
            end
            add_master_constraints!(subproblems, master, mastervars, constraints, cache)
        else
            subproblems, all_spvars, constraints = create_subproblems!(dec, env, cache, nothing)
            for sp in subproblems
                reform.dw_pricing_subprs[ClMP.getuid(sp)] = sp
            end
            mastervars = add_dw_master_vars!(master, master_duty, all_spvars, cache)
            ClMP.setobjconst!(master, cache.master.objective.constant)
            add_master_constraints!(subproblems, master, mastervars, constraints, cache)
        end

        for sp in subproblems
            sp.parent_formulation = master
            closefillmode!(ClMP.getcoefmatrix(sp))
        end
        closefillmode!(ClMP.getcoefmatrix(master))
        return env, master, subproblems, constraints, reform
    end

    function reformfromstring(s::String)
        lines = split(s, "\n", keepempty=false)
        cache = ReadCache()
        nb_subproblems = 0
        nb_separations = 0
        section = _KW_HEADER
        sub_section = _KW_HEADER

        for l in lines
            line = _strip_identation(l)
            lower_line = lowercase(line)
            if haskey(_KW_SECTION, lower_line)
                section = _KW_SECTION[lower_line]
                if section == _KW_SUBPROBLEM || section == _KW_SEPARATION
                    nb_subproblems += 1
                end
                if section == _KW_SUBPROBLEM
                    cache.dw_sp_type = true
                    @assert !cache.benders_sp_type
                end
                if section == _KW_SEPARATION
                    cache.benders_sp_type = true
                    @assert !cache.dw_sp_type
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
            if section == _KW_SUBPROBLEM || section == _KW_SEPARATION
                read_subproblem!(sub_section, cache, line, nb_subproblems)
                continue
            end
            if section == _KW_BOUNDS
                read_bounds!(cache, line)
                continue
            end
            read_variables!(section, sub_section, cache, line)
        end

        env, master, subproblems, constraints, reform = reformfromcache(cache)
        return env, master, subproblems, constraints, reform
    end
    export reformfromstring
end