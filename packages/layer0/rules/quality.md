# Quality Rules

1. **No `console.log` or `debugger` in committed code.** Remove all debug statements before checkpoint.
2. **No `any` types.** Use `unknown` + narrowing. TypeScript strict mode always.
3. **Test-first.** Write failing test before implementation. No exceptions for non-trivial logic.
4. **No dead code.** Remove unused imports, variables, functions. Don't comment out code — delete it.
5. **Small functions.** Single responsibility. If a function does two things, split it.
