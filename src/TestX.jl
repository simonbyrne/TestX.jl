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

# @test
struct AssertPass <: TestPass end
Base.show(io::IO, ::AssertPass) = print(io, "Test assertion passed")

struct AssertFail <: TestFail end
Base.show(io::IO, ::AssertFail) = print(io, "Test assertion failed")

struct AssertNonBool <: TestError end
Base.show(io::IO, ::AssertNonBool) = print(io, "Test assertion non-Boolean result")
struct AssertThrown <: TestError end
Base.show(io::IO, ::AssertThrown) = print(io, "Test assertion threw exception")

macro test(expr)
    _module, _file, _line = Base.CoreLogging.@_sourceinfo()
    quote
        local status
        expression=$(QuoteNode(expr))
        try
            result = $(esc(expr))
            if result isa Bool
                if result
                    # success
                    status = AssertPass()
                    Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression
                else
                    # fail
                    status = AssertFail()
                    Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression
                end
            else
                # non Bool
                status = AssertNonBool()
                Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression result
            end
        catch ex
            status = AssertThrown()
            bt = catch_backtrace()
            level = loglevel(status)
            Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression exception=(ex,bt)
        end
    end
end


# @test_throws
struct ThrowsPass <: TestPass end
Base.show(io::IO, ::ThrowsPass) = print(io, "Test throws passed")

struct ThrowsNoException <: TestFail end
Base.show(io::IO, ::ThrowsNoException) = print(io, "No exception thrown")
struct ThrowsWrongException <: TestFail end
Base.show(io::IO, ::ThrowsWrongException) = print(io, "Wrong exception thrown")

match_exception(::Type{T}, ex::Exception) where {T} = ex isa T
match_exception(expected::T, ex::T) where {T<:Exception} = expected == ex
match_exception(expected::Union{AbstractString, Regex}, ex) = contains(sprint(showerror, ex), expected)


macro test_throws(expected, expr)
    _module, _file, _line = Base.CoreLogging.@_sourceinfo()
    quote
        expression=$(QuoteNode(expr))
        expected=$expected
        try
            result = $(esc(expr))
            # no exception thrown
            status = ThrowsNoException()
            Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group))  _file=$_file _line=$_line _module=$_module expression expected result
        catch ex
            if match_exception($expected, ex)
                # correct exception
                status = ThrowsPass()
                Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression expected exception=ex
            else
                # correct exception
                status = ThrowsWrongException()
                bt = catch_backtrace()
                Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression expected exception=(ex,bt)
            end
        end
    end
end

struct TestSetThrows <: TestFail end
Base.show(io::IO, ::TestSetThrows) = print(io, "Uncaught exception in TestSet")


mutable struct TestSetLogger <: Logging.AbstractLogger
    parent_logger
    level::Logging.LogLevel
    passes::Int
    fails::Int
    errors::Int
    broken::Int
    skips::Int
end

TestSetLogger(logger) = TestSetLogger(logger, Logging.Info, 0,0,0,0,0)

Logging.shouldlog(logger::TestSetLogger, level, _module, group, id) =
    group === :test || Logging.shouldlog(logger.parent_logger, level, _module, group, id)


struct TestSetSummary <: TestStatus
end


function Logging.handle_message(logger::TestSetLogger, level::Logging.LogLevel, message, _module, group, id,
    filepath, line; kwargs...)

    log_to_parent = true
    if group == _group
        if message isa TestSetSummary
            log_to_parent = false
            logger.passes += get(kwargs, :passes, 0)
            logger.fails += get(kwargs, :fails, 0)
            logger.errors += get(kwargs, :errors, 0)
            logger.broken += get(kwargs, :broken, 0)
            logger.skips += get(kwargs, :skips, 0)
        elseif message isa TestPass
            log_to_parent = false
            logger.passes += 1
        elseif message isa TestFail
            logger.fails += 1
        elseif message isa TestError
            logger.errors += 1
        elseif message isa TestBroken
            logger.broken += 1
        elseif message isa TestSkip
            log_to_parent = false
            logger.skips += 1
        end
        logger.level = max(logger.level, level)
    end
    if log_to_parent
        Logging.handle_message(logger.parent_logger, level, message, _module, group, id, filepath, line; kwargs...)
    end
end


testset_logger(logger::Logging.AbstractLogger, _module, _file, _line, _id) = TestSetLogger(logger)

function finish_testset(logger::TestSetLogger, _module, _file, _line, _id)
    (;level, passes, fails, errors, broken, skips) = logger
    Logging.@logmsg level "TestSet" _module=_module _group=_group _id=_id _file=_file _line=_line passes fails errors broken skips
end

Logging.min_enabled_level(logger::TestSetLogger) = Logging.min_enabled_level(logger.parent_logger)

macro testset(expr)
    _module, _file, _line = Base.CoreLogging.@_sourceinfo()
    _id = Symbol(_module, :_, :12)
    quote
        _module = $(_module)
        _file = $(_file)
        _line = $(_line)
        _id = $(QuoteNode(_id))
        testsetlogger = testset_logger(Logging.global_logger(), _module, _file, _line, _id)
        Logging.with_logger(testsetlogger) do
            try
                $(esc(expr))
            catch ex
                status = TestSetThrows()
                bt = catch_backtrace()
                level = loglevel(status)
                Logging.@logmsg loglevel(status) status _file=$_file _line=$_line _module=$_module expression exception=(ex,bt)
            end
        end
        finish_testset(testsetlogger, _module, _file, _line, _id)
    end
end


end # module TestX
