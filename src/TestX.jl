module TestX

import Logging, ScopedValues


abstract type AbstractTestHandler end


struct DefaultTestHandler <: AbstractTestHandler
end
const TEST_HANDLER = ScopedValue{AbstractTestHandler}(DefaultTestHandler())

current_test_handler() = TEST_HANDLER[]



function test_start(::DefaultTestHandler, test)
    nothing
end
function test_start(::DefaultTestHandler, test)
    nothing
end




const TESTSET_KEY = :__TestX_TestSet__


function get_testset()
    get(task_local_storage(), TESTSET_KEY, nothing)
end








export @test, @test_throws, @test_logs, @testset


const test_group = :test
const test_group_seen = :test_seen

# should we use a different logger than the global one?
#  e.g. log to TestX.logger?

# default:
#  - forward to global_logger
#  - throw on first failure
#  - testset groups results

# what is a testset?
#  keep a stack?

# how to set custom loggers from the environment?
#  e.g. junit logger, buildkite logger, etc.

# TODO
# - other tests
#  - @test_deprecated
#  - @test_logs
#  - @test_warn / @test_nowarn
#  - @inferred
#  - JET

# - "shadowing" expressions to compute output

#   ex1 == ex2
# =>  (a = ex1) == (b == ex2)
# => on failure,
# failure(op, args...) => keyword

# failed_info(op, args...; kwargs...) = (;)
# failed_info(op, args...; kwargs...) = (;)


# a ≈ b should also give abserr = norm(a - b) and relerr = norm(a - b) / max(norma(a),norm(b))

# expr = x ≈ y
# evaluated = 0.0 ≈ 1.0
# norm()

# - trim useless info off stacktraces?
# - timing
struct TestSetPush
end
struct TestSetPop
end

#=
@debug TestSetPush() ...
try
    run tests
catch
    handle uncaught exceptions
finally
    @debug TestSetPop()
end
=#

# could use custom LogLevels, but these are kind of clunky
# https://github.com/JuliaLang/julia/issues/33418

abstract type TestStatus end
loglevel(::TestStatus) = Logging.Info

abstract type TestPass <: TestStatus end
loglevel(::TestPass) = Logging.Info

abstract type TestFail <: TestStatus end
loglevel(::TestFail) = Logging.Error

abstract type TestError <: TestStatus end
loglevel(::TestError) = Logging.Error

abstract type TestBroken <: TestStatus end
loglevel(::TestBroken) = Logging.Warn

abstract type TestSkip <: TestStatus end
loglevel(::TestSkip) = Logging.Info

include("test_assert.jl")
include("test_throws.jl")
include("test_logs.jl")
include("testset.jl")


end # module TestX
