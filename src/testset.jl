# @testset
struct TestSetThrows <: TestFail end
Base.show(io::IO, ::TestSetThrows) = print(io, "Uncaught exception in TestSet")


mutable struct TestSetLogger <: Logging.AbstractLogger
    parent_logger
    level::Logging.LogLevel
    counts::Dict{Symbol,Int}
end

TestSetLogger(logger) = TestSetLogger(logger, Logging.Info, Dict{Symbol,Int}())

Logging.shouldlog(logger::TestSetLogger, level, _module, group, id) =
    group === test_group || Logging.shouldlog(logger.parent_logger, level, _module, group, id)


struct TestSetSummary <: TestStatus
    counts::Dict{Symbol, Int}
end

summary_state(::TestStatus) = :unknown
summary_state(::TestPass) = :pass
summary_state(::TestFail) = :fail
summary_state(::TestError) = :error
summary_state(::TestBroken) = :broken
summary_state(::TestSkip) = :skipped

parent_loglevel(status::TestStatus) = loglevel(status) == Logging.Info ? Logging.Debug : loglevel(status)

logtoparent(::TestStatus) = true
logtoparent(::TestPass) = false
logtoparent(::TestSkip) = false
logtoparent(::TestSetSummary) = false


function Logging.handle_message(logger::TestSetLogger, level::Logging.LogLevel, message, _module, _group, _id,
    _file, _line; kwargs...)

    if _group == test_group
        if message isa TestSetSummary
            mergewith!(+, logger.counts, message.counts)
        else
            st = summary_state(message)
            logger.counts[st] = get(logger.counts, st, 0) + 1
        end
        logger.level = max(logger.level, level)
        level = parent_loglevel(message)
        _group = test_group_seen
    end
    Logging.with_logger(logger.parent_logger) do 
        Base.@logmsg level message _module=_module _group=_group _id=_id _file=_file _line=_line kwargs...
    end
end


testset_logger(logger::Logging.AbstractLogger) = TestSetLogger(logger)

function finish_testset(logger::TestSetLogger)
    logger.level, TestSetSummary(logger.counts)
end

Logging.min_enabled_level(logger::TestSetLogger) = Logging.min_enabled_level(logger.parent_logger)

macro testset(expr)
    _module, _file, _line = Base.CoreLogging.@_sourceinfo()
    quote
        testsetlogger = testset_logger(Logging.global_logger())
        Logging.with_logger(testsetlogger) do
            try
                $(esc(expr))
            catch ex
                status = TestSetThrows()
                bt = catch_backtrace()
                Logging.@logmsg loglevel(status) status _file=$_file _line=$_line _module=$_module exception=(ex,bt)
            end
        end
        (_level, _msg) = finish_testset(testsetlogger) # https://github.com/JuliaLang/julia/issues/41451
        Logging.@logmsg _level _msg _group=$(QuoteNode(test_group)) _file=$_file _line=$_line _module=$_module
    end
end
