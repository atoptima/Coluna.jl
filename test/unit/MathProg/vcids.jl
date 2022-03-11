@testset "MathProg - variable and constraint ids" begin
    @testset "_create_hash" begin
        uid = 1
        origin_form_uid = 2
        proc_uid = 3

        hash1 = Coluna.MathProg._create_hash(uid, origin_form_uid, proc_uid)
        hash2 = Coluna.MathProg._create_hash(Int8(uid), Int16(origin_form_uid), Int32(proc_uid))
        hash3 = Coluna.MathProg._create_hash(UInt16(uid), Int8(origin_form_uid), Int8(proc_uid))

        @test hash1 === hash2
        @test hash2 === hash3
    end
end