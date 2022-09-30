# TestX.jl

Exploring some ideas for better test output via logging.

## Problems

This package tries to address the following issues:

- Difficult to find location of failing test in stacktraces
  - stack traces contain a bunch of extra stuff
- No way to customize printed information
- No way to export data
  - TestReports.jl requires its own test runner

- Other options


## Ideas


Design principles:

1. Each test produces a log message.
  - Log already capture line and file numbers, which makes it easier to locate failing tests
  - We can attach arbitrary metadata to each log message
  - id field can be used to identify tests which run multiple times (e.g. to suppress duplicate messages for tests in a loop)
2. A testset is a logger applied to locally to a specific block, which returns extra information
  - at its simplest, it can just count the number
  - can propagate failing tests to the global logger
3. test output can be controlled by use of custom log handlers
  - e.g. junit export, GitHub annotations, markdown summary
4. Ideally a drop-in replacement for Test.jl stdlib

Challenges/open questions:
- Schema for test metadata? e.g.
  - should it be part of the log message, or get passed as an extra keyword argument?
- How to make sure that each test gets the line number of the `@test`, and not the `@logmsg`
- For `Pkg.test()` to fail, we need to return a non-zero exit code:
  - throw an error in each test expression if not in a testset
  - add an `atexit(() -> exit(1))`  hook if not running interactively?
- How should a CI system specify a custom log handler?
- Performance: how to minimize overhead?