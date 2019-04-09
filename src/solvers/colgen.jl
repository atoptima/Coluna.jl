struct ColumnGeneration <: AbstractSolver end

struct ColumnGenerationRecord <: AbstractSolverRecord
    nb_iterations::Int
end

function setup(::Type{ColumnGeneration}, f, n)
    println("\e[31m Setup ColumnGeneration \e[00m")
end

function run(::Type{ColumnGeneration}, f, n, p)
    db = 0
    nb_iter = 0
    for i in 1:rand(10:20)
        db += rand(0:0.01:100)
        mlp = rand(2000:0.01:2500)
        println("<it=$i> <DB=$db> <Mlp=$mlp>")
        nb_iter += 1
        sleep(0.3)
    end
    return ColumnGenerationRecord(nb_iter)
end

function record_output(::Type{ColumnGeneration}, f, n)
    println("\e[31m record column generation \e[00m")
end

function apply(S::Type{ColumnGeneration}, f, n, r, p)
    interface(getsolver(r), S, f, n)
    setsolver!(r, S)
    return run(S, f, n, p)
end
