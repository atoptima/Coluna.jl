import JSON3

mutable struct Runs
    instance::Union{String,Nothing}
    name::Union{String,Nothing}
    kpis::Union{Vector{Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}},Nothing}
end

Runs() = Runs(nothing, nothing, Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}[])
Runs(instance) = Runs(instance, nothing, Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}[])
Runs(instance, name) = Runs(instance, name, Tuple{Any,Float64,Int64,Float64,Base.GC_Diff}[])

mutable struct AlgorithmsKpis
    instance::String
    kpis::Dict{String,Dict{Symbol,Float64}}
end

InstancesKpis = Vector{AlgorithmsKpis}

function calculateKpis(runs::Vector{Runs}, kpis::Vector{Symbol})
    symbols = [:val, :time, :bytes, :gctime, :memallocs]
    kpivalues = Dict()
    for run in runs
        kpivalues[run.name] = Dict{Symbol, Float64}()
        for kpi in kpis
            kpivalues[run.name][kpi] =
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

global colunaruns = Runs[]
global solve_sps_runs = Runs[]
