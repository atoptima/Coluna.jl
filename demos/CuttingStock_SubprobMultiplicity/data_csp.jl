import Base.show, Base.print

mutable struct Order
  index::Int
  width::Int
  demand::Int
end

mutable struct DataCsp
  name::AbstractString
  stocksheetswidth::Int
  nborders::Int
  orders::Vector{Order}
end


function read_dataCsp(path_file::AbstractString)

  datacs = DataCsp("", 0, 1, Array{Order}(undef, 0))
  lines = Array{Any}(undef, 0)
  open(path_file) do file
    for line in eachline(file)
      isdata = (match(r"^[!#]", line)) === nothing # Removing comments
      isdata = isdata && ((match(r"^$", line)) === nothing) # Removing empty lines
      if isdata
        push!(lines, line)
      end
    end
  end

  # Model name
  datacs.name = string(lines[1])
  # Adding the stocksheet (one stock)
  datacs.stocksheetswidth = parse(Int, lines[2])
  # Nb orders
  datacs.nborders = parse(Int, lines[3])
  # Create orders
  for i in 4:length(lines)
    order = split(lines[i])
    push!(datacs.orders, Order(i-4, parse(Int, order[1]), parse(Int, order[2])))
  end
  datacs
end
