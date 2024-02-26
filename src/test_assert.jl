using DeepDiffs

# @test
struct AssertPass <: TestPass end
Base.show(io::IO, ::AssertPass) = print(io, "@test passed")

struct AssertFail <: TestFail end
Base.show(io::IO, ::AssertFail) = print(io, "@test failed")

struct AssertNonBool <: TestError end
Base.show(io::IO, ::AssertNonBool) = print(io, "@test non-Boolean result")

struct AssertThrown <: TestError end
Base.show(io::IO, ::AssertThrown) = print(io, "@test threw exception")


"""
    evaluation_expr!(expr)

Rewrite `expr` so that we can extract the intermediate evaluated quantities,
returning an expression that evaluates to the intermediate "evaluation" object,
or `nothing` if the evaluation cannot be determined.
"""
function evaluation_expr!(expr)
    if expr isa Expr && expr.head == :call && expr.args[1] == :!
        not_expr = expr.args[2]
        if not_expr isa Expr && not_expr.head == :call
            eval_expr = :($(@__MODULE__).negated_evaluation())
            for i in eachindex(not_expr.args)
                argsym = gensym("arg")
                not_expr.args[i] = Expr(:(=), argsym, not_expr.args[i])
                push!(eval_expr.args, esc(argsym))
            end
            return eval_expr
        else
            return nothing
        end
    else
        if expr isa Expr && expr.head == :call
            eval_expr = :($(@__MODULE__).evaluation())
            for i in eachindex(expr.args)
                argsym = gensym("arg")
                expr.args[i] = Expr(:(=), argsym, expr.args[i])
                push!(eval_expr.args, esc(argsym))
            end
            return eval_expr
        else
            return nothing
        end
    end
end

abstract type AbstractAssertEvaluation end
abstract type AbstractNegatedAssertEvaluation  <: AbstractAssertEvaluation end

# FunctionEvaluation => this is the default fallback
# NegatedFunctionEvaluation

evaluation(f, args...; kwargs...) =
    FunctionEvaluation(f, args, kwargs)

# https://github.com/ssfrr/DeepDiffs.jl
struct FunctionEvaluation <: AbstractAssertEvaluation
    f
    args
    kwargs
end

evaluation(::typeof(==), left, right) =
    EqualityEvaluation(left, right)

struct EqualityEvaluation <: AbstractAssertEvaluation
    left
    right
end
function Base.show(io::IO, ev::EqualityEvaluation)
    show(io, deepdiff(ev.left, ev.right))
end
# idea: should return an Evaluate object which can be printed differently depending on

mutable struct AssertionTest
    __module__
    __source__
    expression
    status
    evaluation
    
end



"""
    @test expr


"""
macro test(expr)
    # we need to capture these here, rather than use the ones in the logger, so
    # that we get the line number of the @test, not the line number in this file
    orig_expr = deepcopy(expr)
    eval_expr = evaluation_expr!(expr)
    quote
        testset = current_test_handler()
        test = AssertionTest(
            $__module__,
            $__source__,
            expression=$(QuoteNode(orig_expr)),
        )
        test_start(testset, test)
        local status, kw
        expression = $(QuoteNode(orig_expr))
        try
            result = $(esc(expr))
            if result isa Bool
                if result
                    test.status = :pass
                else
                    # fail
                    test.status = :fail
                    evaluation=$eval_expr
                    kw = (;
                        evaluation,
                    )
                end
            else
                # non Bool
                status = AssertNonBool()
                evaluation=$eval_expr
                kw = (;
                    evaluation,
                    result,
                )
            end
        catch ex
            status = AssertThrown()
            bt = catch_backtrace()
            kw = (;
                exception=(ex,bt),
            )
        end
        test_finish(testset, test)
        #Base.@logmsg loglevel(status) status _group=$(QuoteNode(test_group)) _file=$_file _line=$_line _module=$_module expression kw...
        
    end
end
