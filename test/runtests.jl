

using TestX

@testset begin

@test 1+1 == 2
@test 1+1 == 3
@test 1+1
@test div(1, 0) == 1

    @test_throws DivideError div(1,0)
    @test_throws "Divide" div(1,0)
    @test_throws BoundsError div(1,0)
    @test_throws DivideError div(1,2)
end
#=

using Test

@testset for i = 1:3
    @test isodd(i)
end

=#
