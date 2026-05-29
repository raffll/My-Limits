# No Test Execution Tasks

Do NOT generate spec tasks that require running tests, linters, build tools, or any external tooling. This project has no test runner, no Lua interpreter available in the development environment, and no CI pipeline.

Property-based tests and unit tests may be written as reference documentation (standalone .lua files in a `tests/` folder), but:

- Do NOT create tasks that say "run tests" or "ensure tests pass"
- Do NOT create checkpoint tasks that depend on test execution
- Do NOT create tasks that require installing or invoking external tools
- Property test tasks should be marked optional or omitted entirely from the task list

The only verification available is manual in-game testing by the user.
