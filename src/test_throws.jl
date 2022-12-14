# @test_throws
struct ThrowsPass <: TestPass end
Base.show(io::IO, ::ThrowsPass) = print(io, "@test_throws passed")

struct ThrowsNoException <: TestFail end
Base.show(io::IO, ::ThrowsNoException) = print(io, "@test_throws no exception thrown")
struct ThrowsWrongException <: TestFail end
Base.show(io::IO, ::ThrowsWrongException) = print(io, "@test_throws wrong exception thrown")

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
                # wrong exception
                status = ThrowsWrongException()
                bt = catch_backtrace()
                Base.@logmsg loglevel(status) status _group=$(QuoteNode(_group)) _file=$_file _line=$_line _module=$_module expression expected exception=(ex,bt)
            end
        end
    end
end
