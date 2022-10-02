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
    # we need to capture these here, rather than use the ones in the logger, so
    # that we get the line number of the @test, not the line number in this file
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
