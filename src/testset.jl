# @testset
struct TestSetThrows <: TestFail end
Base.show(io::IO, ::TestSetThrows) = print(io, "Uncaught exception in TestSet")


mutable struct TestSetLogger <: Logging.AbstractLogger
    parent_logger
    level::Logging.LogLevel
    passed::Int
    failed::Int
    errored::Int
    broken::Int
    skpped::Int
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
            logger.passed += get(kwargs, :passed, 0)
            logger.failed += get(kwargs, :failed, 0)
            logger.errored += get(kwargs, :errored, 0)
            logger.broken += get(kwargs, :broken, 0)
            logger.skpped += get(kwargs, :skpped, 0)
        elseif message isa TestPass
            log_to_parent = false
            logger.passed += 1
        elseif message isa TestFail
            logger.failed += 1
        elseif message isa TestError
            logger.errored += 1
        elseif message isa TestBroken
            logger.broken += 1
        elseif message isa TestSkip
            log_to_parent = false
            logger.skpped += 1
        end
        logger.level = max(logger.level, level)
    end
    if log_to_parent
        Logging.handle_message(logger.parent_logger, level, message, _module, group, id, filepath, line; kwargs...)
    end
end


testset_logger(logger::Logging.AbstractLogger, _module, _file, _line, _id) = TestSetLogger(logger)

function finish_testset(logger::TestSetLogger, _module, _file, _line, _id)
    (;level, passed, failed, errored, broken, skpped) = logger
    Logging.@logmsg level "TestSet" _module=_module _group=_group _id=_id _file=_file _line=_line passed failed errored broken skpped
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
