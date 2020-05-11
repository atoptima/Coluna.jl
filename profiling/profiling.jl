import JSON3

mutable struct Runs
    name::Union{String,Nothing}
    tags::Vector{String}
    kpis::Union{Vector{Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}},Nothing}
end

Runs() = Runs(nothing, nothing, Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}[])
Runs(name) = Runs(name, nothing, Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}[])
Runs(name, tags) = Runs(name, tags, Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}[])

mutable struct AlgorithmsKpis
    instance::String
    kpis::Dict{String,Dict{String,Dict{Symbol,Float64}}}
end

AlgorithmsKpis(instance) = AlgorithmsKpis(instance, Dict{String,Dict{String,Dict{Symbol,Float64}}}())

function calculateKpis(runs::Vector{Runs}, kpis::Vector{Symbol})
    symbols = [:val, :time, :bytes, :gctime, :memallocs]
    kpivalues = Dict{String,Dict{String,Dict{Symbol,Float64}}}()
    for run in runs
        if !(run.tags[1] in keys(kpivalues))
            kpivalues[run.tags[1]] = Dict{String,Dict{Symbol,Float64}}()
        end
        kpivalues[run.tags[1]][run.name] = Dict{Symbol, Float64}()
        for kpi in kpis
            kpivalues[run.tags[1]][run.name][kpi] =
                sum([r[findfirst(x -> x == kpi, symbols)] for r in run.kpis])
        end
    end
    return kpivalues
end

function save_profiling_file(filename::String, instance::AlgorithmsKpis)
    file = open(filename, "a")
    results = Dict(instance.instance => instance.kpis)
    write(file,JSON3.write(results))
    write(file,"\n")
    close(file)
end
