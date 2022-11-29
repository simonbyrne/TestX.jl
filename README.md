# TestX.jl

Exploring some ideas for better test output via Logging.jl

## Problems

This package tries to address the following issues with [Test.jl](https://docs.julialang.org/en/v1/stdlib/Test/).

- It can be difficult to find the location of a failing test
  - stack traces contain lots of extra stuff (e.g. lines from Test.jl)
  - testsets make the problem even harder

- No way to customize printed information, e.g.
  - when testing for `isapprox`, it would be helpful to know the norm of each argument, the absolute and relative errors
  - when testing for equality between arrays, it would be useful to know the indices and values of the differing elements

- No way to export data (e.g. to junit format, or integrations with GitHub or Buildkite)
  - TestReports.jl requires its own test runner


## Design principles

1. Each test produces a log message.
   - Logging.jl already captures line and file numbers, which makes it easier to locate failing     tests
   - We can attach arbitrary metadata to each log message
   - id field can be used to identify tests which run multiple times (e.g. to suppress duplicate messages for tests in a loop)
2. A testset is simply a special logger applied to locally to a specific block, which summarizes the results
   - at its simplest, it can just count the number of passes, fails, etc.
   - propagates failing tests to the global logger
3. test output can be controlled by use of custom log handlers
   - e.g. junit export, GitHub annotations, markdown summary, https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-a-warning-message
4. A drop-in replacement for Test.jl stdlib
5. Extensible to other use cases (e.g. JET.jl, Aqua.jl)

# Challenges/open questions

- Schema for test metadata?
  - should it be part of the log message object, or get passed as an extra keyword argument?
- How to return a non-zero exit code when a test fails?
  - throw an error in each test expression if the current logger is not the global logger?
- What is the interface for a custom logger?
- Can this be made as performant as Test.jl? How to minimize overhead? Logging has lots of `@nospecialize` for this reason.
