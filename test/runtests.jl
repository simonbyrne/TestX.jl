

using TestX, Logging

if haskey(ENV, "GITHUB_ACTIONS")
    if v"1.8pre" < VERSION < v"1.9.0-beta3"

        # the current julia-runtest action parses the stdout stream and looks for "Test Failed"
        # https://github.com/julia-actions/julia-runtest/blob/ba451bf755774f8120f020dc5bb4a7e7bb7fc231/test_logger.jl#L91
        # this is much simpler: we just use a different logger
        push!(LOAD_PATH, "@tests-logger-env")
        using GitHubActions, Logging
        global_logger(GitHubActionsLogger())
    end
end

@show Logging.global_logger()

@test_logs (Logging.Info, TestX.AssertPass()) @test(true)
@test_logs (Logging.Info, TestX.AssertPass()) @test(1==1)
@test_logs (Logging.Error, TestX.AssertFail()) @test(false)
@test_logs (Logging.Error, TestX.AssertFail()) @test(1==2)
@test_logs (Logging.Error, TestX.AssertFail()) @test("aa"*"c"=="abc")
@test_logs (Logging.Error, TestX.AssertNonBool()) @test("aa"*"c"==missing)
@test_logs (Logging.Error, TestX.AssertThrown()) @test(div(1, 0) == 1)

@test_logs (Logging.Info, TestX.ThrowsPass()) @test_throws(DivideError,div(1,0))
@test_logs (Logging.Info, TestX.ThrowsPass()) @test_throws("Divide",div(1,0))
@test_logs (Logging.Error, TestX.ThrowsWrongException()) @test_throws BoundsError div(1,0)
@test_logs (Logging.Error, TestX.ThrowsNoException()) @test_throws DivideError div(1,2)


@testset begin
@testset begin

    @test 1+1 == 2
    @test 1+1 == 3
    @test "aa"*"c" == "abc"
    @test "aa"*"c" == missing
    @test 1+1
    @test div(1, 0) == 1

    @test_throws DivideError div(1,0)
    @test_throws "Divide" div(1,0)
    @test_throws BoundsError div(1,0)
    @test_throws DivideError div(1,2)

end
end

try
    try
        println("try")
        error("oh no")
    catch ex
        println("catch")
        rethrow(ex)
    finally
        println("finally")
    end
catch ex
    println("catch2")
end