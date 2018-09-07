import Base.show, Base.print

mutable struct DataGap
  machines::UnitRange{Int}
  jobs::UnitRange{Int}
  weight::Matrix{Int}
  cost::Matrix{Int}
  capacity::Vector{Int}
end

function DataGap(nbmachines::Int, nbjobs::Int) 
    return DataGap(1:nbmachines, 1:nbjobs, Matrix{Int}(undef, nbmachines,nbjobs),
                   Matrix{Int}(undef, nbmachines, nbjobs), 
                   Vector{Int}(undef, nbmachines))
end

function read_dataGap(path_file::AbstractString)
  # STEP 1 : pushing data in a vector.
  data = Vector{Int}(undef, 0)
  open(path_file) do file
    for line in eachline(file)
       for peaceofdata in split(line)
         push!(data, parse(Int, peaceofdata))
       end
     end
  end

  datagap = DataGap(data[1], data[2])
  nbmachines = length(datagap.machines)
  nbjobs = length(datagap.jobs)

  offset = 2
  datagap.cost = reshape(data[offset+1 : offset+nbmachines*nbjobs], nbjobs, nbmachines)
  offset += nbmachines*nbjobs
  datagap.weight = reshape(data[offset+1 : offset+nbmachines*nbjobs], nbjobs, nbmachines)
  offset += nbmachines*nbjobs
  datagap.capacity = reshape(data[offset+1 : offset+nbmachines], nbmachines)

  datagap
end

function show(io::IO, d::DataGap)
  println(io, "Generalized Assignment dataset.")
  println(io, "nb machines = $(length(d.machines)) and nb jobs = $(length(d.jobs))")
  println(io, "Capacities of machines : ")
  for m in d.machines
    println(io, "\t machine $m, capacity = $(d.capacity[m])")
  end

  println(io, "Ressource consumption of jobs : ")
  for j in d.jobs
    println(io, "\t job $j")
    for m in d.machines
      print(io, "\t\t on machines $m : consumption = $(d.weight[j,m])")
      println(io, " and cost = $(d.cost[j,m])")
    end
  end
end
