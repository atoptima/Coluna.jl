

function nestedenum_unit()
    Coluna.@nestedenum VarConstrDuty Root,
        A <: Root,
            A1 <: A,
            A2 <: A,
            A3 <: A,
        B <: Root,
            B1 <: B,
            B2 <: B,
            B3 <: B,
                B3A <: B3,
                B3B <: B3,
                B3C <: B3,
        C <: Root,
        D <: Root,
            D1 <: D,
                D1A <: D1,
                D1B <: D1,
            D2 <: D,
        E <: Root

    @test true

    exit()
end
