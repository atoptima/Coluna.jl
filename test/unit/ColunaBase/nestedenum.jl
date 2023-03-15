ClB.@nestedenum begin
    VarConstrDuty
    A <= VarConstrDuty
        A1 <= A
        A2 <= A
        A3 <= A
    B <= VarConstrDuty
        B1 <= B
        B2 <= B
        B3 <= B
            B3A <= B3
            B3B <= B3
            B3C <= B3
    C <= VarConstrDuty
    D <= VarConstrDuty
        D1 <= D
            D1A <= D1
            D1B <= D1
        D2 <= D
    E <= VarConstrDuty
end

function nested_enum()
    @test <=(A1, A)
    @test A1 <= A

    @test !<=(A, B)
    @test !(A <= B)

    @test <=(B3A, B)
    @test B3A <= B
end
register!(unit_tests, "nestedenum", nested_enum)
