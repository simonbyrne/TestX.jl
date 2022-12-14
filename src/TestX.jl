module TestX

import Logging

export @test, @test_throws, @testset


const _group = :test

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
abstract type TestPass <: TestStatus end
loglevel(::TestPass) = Base.CoreLogging.Info

abstract type TestFail <: TestStatus end
loglevel(::TestFail) = Base.CoreLogging.Error

abstract type TestError <: TestStatus end
loglevel(::TestError) = Base.CoreLogging.Error

abstract type TestBroken <: TestStatus end
loglevel(::TestBroken) = Base.CoreLogging.Warn

abstract type TestSkip <: TestStatus end
loglevel(::TestSkip) = Base.CoreLogging.Info

include("test_assert.jl")
include("test_throws.jl")
include("testset.jl")


end # module TestX
