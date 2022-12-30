import Test

struct LogsPass <: TestPass end
Base.show(io::IO, ::LogsPass) = print(io, "@test_logs passed")

struct LogsFail <: TestFail end
Base.show(io::IO, ::LogsFail) = print(io, "@test_logs failed")

struct LogsThrown <: TestError end
Base.show(io::IO, ::LogsThrown) = print(io, "@test_logs threw exception")




macro test_logs(exs...)
    _module, _file, _line = Base.CoreLogging.@_sourceinfo()
    length(exs) >= 1 || throw(ArgumentError("""`@test_logs` needs at least one arguments.
                               Usage: `@test_logs [msgs...] expr_to_run`"""))
    patterns = Any[]
    kwargs = Any[]
    for e in exs[1:end-1]
        if e isa Expr && e.head === :(=)
            push!(kwargs, esc(Expr(:kw, e.args...)))
        else
            push!(patterns, esc(e))
        end
    end
    expression = exs[end]
    quote
        local status, kw, value
            try
                didmatch,logs,value = Test.match_logs($(patterns...); $(kwargs...)) do
                    $(esc(expression))
                end
                if didmatch
                    status = LogsPass()
                    kw = (;)                    
                else
                    status = LogsFail()
                    kw = (;logs)
                end
                value
            catch ex
                value = nothing
                status = LogsThrown()
                bt = catch_backtrace()
                kw = (;
                    exception=(ex,bt),
                )
                rethrow(ex)
            finally
                Base.@logmsg loglevel(status) status _group=$(QuoteNode(test_group)) _file=$_file _line=$_line _module=$_module kw...
            end
            
        end
end
