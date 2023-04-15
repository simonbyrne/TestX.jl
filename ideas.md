# TestX plan

https://github.com/JuliaLang/julia/issues/33065#issue-484850077

Tests should use logging infrastructure

- a "test" will add a log entry
  - will store file, lineno automatically
  - use a custom log handler which will collect test results, passing other results through

  - how to distinguish "test" log entries? either
    - use a keyword (`_testresult = :success, :failure, :error, :broken`)
    - probably better to use a custom result type as a message (similar to how ProgressLogging works)

  - could integrate with vscode
    - https://github.com/julia-vscode/julia-vscode/issues/2367
    - https://discourse.julialang.org/t/prerelease-of-new-testing-framework-and-test-run-ui-in-vs-code/86355
    - https://github.com/julia-vscode/TestItemRunner.jl

    -
    -
 - We should time tests / testsets
   - helpful for identifying which ones take longer

 - could hook into progress meters:
   - an option so that when you run tests, it saves the total number of tests in a metadata file. This can be used next time as a progress meter

- Success: expr
- Failure: expr, full result tree, brokenflag
- Error: stacktrace

- Failures will
- custom handling of functions:
  - equality ops (`==`, `===`, `<`)  should return both sides
  - `isa`


Modifiers:
- broken: evaluate
  - success => Failure/@error
  - failure/error => Broken/@warn
  - unexpected pass should give line number: https://github.com/JuliaLang/julia/issues/21392
  - `@test_broken` can't be composed with `@test_throws`
- skip
  - don't evaluate at all => Broken/@warn
- flaky?
  - success => Pass/@info
  - failure => Broken/@warn

Conditional (broken, skip keywords?)

Allow to be applied to a whole block?, e.g.
```
@broken begin

  @test xxx = yyy
  @test bbb = ccc

end
```
- how would it work with testsets, errors outside of tests, etc

Docstrings as labels/messages?
 - it doesn't appear to be possible to do this.




How to handle other tests:
 - @test_deprecated
 - @test_logs
 - @test_warn / @test_nowarn
 - `@test_warn`/`@test_nowarn` are broken with the non-default logger: https://github.com/JuliaLang/julia/issues/25612
 - @inferred: currently throws an exception instead of failure (https://github.com/JuliaLang/julia/issues/24829)
 - JET

Other ideas:
 - `@test_throws` => `@test @throws` https://github.com/JuliaLang/julia/issues/21098?
 - `@test_warn` => `@test @warns`
   - currently `@test_warn(expr)` returns the result of the expression, so that you can do `@test @test_warn(expr) == result`
 - AbstractTestSet interface: https://github.com/JuliaLang/julia/issues/21828
 - Use custom test log handler
 - https://buttondown.email/hillelwayne/archive/i-am-disappointed-by-dynamic-typing/#fnref:paramspec
   - generate snapshot test cases
     - See also https://github.com/ezyang/expecttest
   - insert breakpoints in failing tests
     - requires some notion of re-runnable tests / isolation?

- generate snapshots interactively at the REPL
  - https://jestjs.io/docs/snapshot-testing
  - `@testgen expr` => `:(@test expr == $(expr))`

- time stamps and progress
  - all tests should log time stamps
  - have optional start and progress events
    - need some way to link them: we don't make the id field globally unique, as we use that to suppress multiple failures
    - either have a different identifier (global increment?)
    - task identifier (objectid)