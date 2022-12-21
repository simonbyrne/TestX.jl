# @test
struct AssertPass <: TestPass end
Base.show(io::IO, ::AssertPass) = print(io, "@test passed")

struct AssertFail <: TestFail end
Base.show(io::IO, ::AssertFail) = print(io, "@test failed")

struct AssertNonBool <: TestError end
Base.show(io::IO, ::AssertNonBool) = print(io, "@test non-Boolean result")

struct AssertThrown <: TestError end
Base.show(io::IO, ::AssertThrown) = print(io, "@test threw exception")




function shadow_expr!(expr)
    if expr isa Expr && expr.head == :call && expr.args[1] == :!
        not_expr = expr.args[2]
        if not_expr isa Expr && not_expr.head == :call
            info_expr = :(not_fail_info())
            for i in eachindex(not_expr.args)
                argsym = gensym("arg")
                not_expr.args[i] = Expr(:(=), argsym, not_expr.args[i])
                push!(info_expr.args, esc(argsym))
            end
            return info_expr
        else
            return nothing
        end
    else
        if expr isa Expr && expr.head == :call
            info_expr = :(fail_info())
            for i in eachindex(expr.args)
                argsym = gensym("arg")
                expr.args[i] = Expr(:(=), argsym, expr.args[i])
                push!(info_expr.args, esc(argsym))
            end
            return info_expr
        else
            return nothing
        end
    end
end

abstract type AbstractEvaluated

# https://github.com/ssfrr/DeepDiffs.jl
struct EvaluatedFunction <: AbstractEvaluated
    f
    args
    kwargs
end

struct EvaluatedNot <: AbstractEvaluated
    evalexpr
end


function evaluated(args...)
    Expr(:call,args...)
end
function not_fail_info(args...)
    Expr(:call,:!,Expr(:call,args...))
end

# idea: should return an Evaluate object which can be printed differently depending on

macro test(expr)
    # we need to capture these here, rather than use the ones in the logger, so
    # that we get the line number of the @test, not the line number in this file
    _module, _file, _line = Base.CoreLogging.@_sourceinfo()
    orig_expr = deepcopy(expr)
    info_expr = shadow_expr!(expr)
    quote
        local status
        expression = $(QuoteNode(orig_expr))
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
                    Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression evaluated=$info_expr
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
