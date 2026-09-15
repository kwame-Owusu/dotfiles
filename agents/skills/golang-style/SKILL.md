---
name: golang-style
description: "Idiomatic Go — code style, naming conventions, and modern Go idioms. Use when writing or reviewing Go code: line length and breaking, variable declarations, control flow clarity, function design, code organization, string handling, identifier naming (packages, files, constructors, structs, interfaces, enums, errors, booleans, receivers, options, test functions, acronyms), and modernizing to current Go patterns (any, min/max, range-over-int, slices/maps, cmp, slog, math/rand/v2). Not for error handing and architecture patterns (→ golang-patterns skill), CLI structure (→ golang-cli skill), or test strategy (→ golang-testing skill)."
user-invocable: true
license: MIT
compatibility: Designed for Claude Code, Codex or similar harness, and for projects using Golang.
paths:
  - "**/*.go"
---

# Go Style, Naming & Modern Idioms

Style rules that require human judgment — linters handle formatting, this skill handles clarity, naming, and staying current with Go idioms.

> "Clear is better than clever." — Go Proverbs

When ignoring a rule, add a comment to the code.

## Identifier Naming

Go favors short, readable names. Capitalization controls visibility — uppercase is exported, lowercase is unexported. All identifiers MUST use MixedCaps, NEVER underscores (exceptions: test-function subcases like `TestFoo_InvalidInput`, generated code, cgo interop).

### Quick Reference

| Element | Convention | Example |
| --- | --- | --- |
| Package | lowercase, single word, plural avoided | `json`, `http`, `tabwriter` |
| File | lowercase, underscores OK | `user_handler.go` |
| Exported name | UpperCamelCase | `ReadAll`, `HTTPClient` |
| Unexported | lowerCamelCase | `parseToken`, `userCount` |
| Interface | method name + `-er` | `Reader`, `Closer`, `Stringer` |
| Struct | MixedCaps noun | `Request`, `FileHeader` |
| Constant | MixedCaps (not ALL_CAPS) | `MaxRetries`, `defaultTimeout` |
| Receiver | 1-2 letter abbreviation | `func (s *Server)`, `func (b *Buffer)` |
| Error variable | `Err` prefix | `ErrNotFound`, `ErrTimeout` |
| Error type | `Error` suffix | `PathError`, `SyntaxError` |
| Constructor | `New` (single type) or `NewTypeName` (multi-type) | `ring.New`, `http.NewRequest` |
| Boolean field | `is`/`has`/`can` prefix on fields and methods | `isReady`, `IsConnected()` |
| Acronym | all caps or all lower | `URL`, `HTTPServer`, `xmlParser` |
| Context variant | `WithContext` suffix | `FetchWithContext`, `QueryContext` |
| In-place mutation | `In` suffix | `SortIn()`, `ReverseIn()` |
| Panicking variant | `Must` prefix | `MustParse()`, `MustLoadConfig()` |
| Option func | `With` + field name | `WithPort()`, `WithLogger()` |
| Enum (iota) | type name prefix, zero-value = unknown | `StatusUnknown` at 0, `StatusReady` |
| Error string | lowercase (incl. acronyms), no punctuation | `"image: unknown format"` |
| Import alias | short, only on collision | `mrand "math/rand"` |
| Format func | `f` suffix | `Errorf`, `Wrapf`, `Logf` |
| Test function | `Test` + function name | `TestParseToken` |

### Avoid Stuttering

Go call sites always include the package name, so repeating it wastes reader attention — `http.HTTPClient` forces parsing "HTTP" twice. A name MUST NOT repeat information already present in the package name, type name, or surrounding context.

```go
// Good
http.Client       // not http.HTTPClient
json.Decoder      // not json.JSONDecoder
user.New()        // not user.NewUser()

// In package dbpool:
type Pool struct{}       // not DBPool
type Status struct{}     // not PoolStatus — callers write dbpool.Status
type Option func(*Pool)  // not PoolOption
```

### Frequently Missed Conventions

- **Constructor naming:** single primary type → `New()` not `NewTypeName()` (`apiclient.New()`), avoiding stutter. `NewTypeName()` only for packages with multiple constructible types (`http.NewRequest`).
- **Boolean fields:** unexported booleans MUST prefix `is`/`has`/`can` — `isConnected`, `hasPermission`. Export the getter keeping the prefix: `IsConnected() bool`.
- **Error strings fully lowercase, including acronyms:** `"invalid message id"`, not `"invalid message ID"`. Sentinel errors include the package name: `errors.New("apiclient: not found")`.
- **Enum zero values:** always place an explicit `Unknown`/`Invalid` sentinel at iota 0. A zero `Status` silently equal to `StatusReady` behaves as if a status was chosen when it wasn't.
- **Subtest names:** fully lowercase descriptive phrases: `"valid id"`, `"empty input"`.
- **Get-prefix omitted:** `user.Name()` reads naturally; `Get` adds noise. `Is`/`Has`/`Can` predicates keep their prefix: `IsHealthy() bool`.

### Common Naming Mistakes

| Mistake | Fix |
| --- | --- |
| `ALL_CAPS` constants | Go reserves casing for visibility — use `MaxRetries` |
| `GetName()` getter | Go omits `Get` — `user.Name()` |
| `Url`, `Http`, `Json` acronyms | Mixed-case acronyms create ambiguity — all caps or all lower |
| `this`/`self` receiver | Use 1-2 letter abbreviation (`s` for `Server`) |
| `util`, `helper` packages | Specific names that describe the abstraction |
| `http.HTTPClient` stuttering | `http.Client` — package is present at call site |
| `user.NewUser()` constructor | `user.New()` for single primary type |
| `connected bool` field | `isConnected` reads as a true/false question |
| `"invalid message ID"` error | Error strings lowercase incl. acronyms |
| `StatusReady` at iota 0 | Sentinel at 0 — `StatusUnknown` catches uninitialized values |
| `userSlice` type-in-name | Types encode implementation detail — `users` describes content |
| `snake_case` identifiers | MixedCaps is load-bearing (Go's export mechanism + tooling) |
| Long names for short scopes | Name length matches scope — `i` is fine for a 3-line loop |
| `FetchCtx()` context variant | `FetchWithContext()` — `WithContext` is the standard suffix |
| `parse()` panicking on error | `MustParse()` warns callers it panics |
| Mixing `With*`/`Set*`/`Use*` | `With*` is the Go convention for functional options |
| Plural package names | Singular (`net/url`, not `net/urls`) |
| `user`/`account`/`person` synonyms | Pick one concept name and keep it |

## Line Length & Breaking

No rigid line limit, but lines beyond ~120 characters MUST be broken. Break at **semantic boundaries**, not arbitrary column counts. Function calls with 4+ arguments MUST use one argument per line — even when the prompt asks for single-line code:

```go
mux.HandleFunc("/api/users", func(w http.ResponseWriter, r *http.Request) {
    handleUsers(
        w,
        r,
        serviceName,
        cfg,
        logger,
        authMiddleware,
    )
})
```

When a function signature is too long, the real fix is often **fewer parameters** (use an options struct) rather than better wrapping.

## Variable Declarations

SHOULD use `:=` for non-zero values, `var` for zero-value initialization. `var` means "this starts at zero."

```go
var count int              // zero value, set later
name := "default"          // non-zero, := is appropriate
var buf bytes.Buffer       // zero value is ready to use
```

### Slice & Map Initialization

Slices and maps MUST be initialized explicitly, never nil. Nil maps panic on write; nil slices serialize to `null` in JSON (vs `[]`), surprising API consumers.

```go
users := []User{}                       // always initialized
m := map[string]int{}                   // always initialized
users := make([]User, 0, len(ids))      // preallocate when capacity is known
m := make(map[string]int, len(items))   // preallocate when size is known
```

Do not preallocate speculatively — `make([]T, 0, 1000)` wastes memory when the common case is 10 items.

### Composite Literals

Composite literals MUST use field names — positional fields break when the type adds or reorders fields:

```go
srv := &http.Server{
    Addr:         ":8080",
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
}
```

## Control Flow

### Reduce Nesting

Errors and edge cases MUST be handled first (early return). Keep the happy path at minimal indentation:

```go
func process(data []byte) (*Result, error) {
    if len(data) == 0 {
        return nil, errors.New("empty data")
    }
    parsed, err := parse(data)
    if err != nil {
        return nil, fmt.Errorf("parsing: %w", err)
    }
    return transform(parsed), nil
}
```

### Eliminate Unnecessary `else`

When the `if` body ends with `return`/`break`/`continue`, the `else` MUST be dropped. Use default-then-override for simple assignments:

```go
level := slog.LevelInfo
switch {
case debug:
    level = slog.LevelDebug
case verbose:
    level = slog.LevelWarn
}
```

### Complex Conditions & Init Scope

When an `if` condition has 3+ operands, MUST extract into named booleans. Keep expensive checks inline for short-circuit benefit. [Details](./references/details.md)

```go
isAdmin := user.Role == RoleAdmin
isOwner := resource.OwnerID == user.ID
isPublicVerified := resource.IsPublic && user.IsVerified
if isAdmin || isOwner || isPublicVerified || permissions.Contains(PermOverride) {
    allow()
}
```

Scope variables to `if` blocks when only needed for the check:

```go
if err := validate(input); err != nil {
    return err
}
```

### Switch Over If-Else Chains

When comparing the same variable multiple times, prefer `switch`:

```go
switch status {
case StatusActive:
    activate()
case StatusInactive:
    deactivate()
default:
    panic(fmt.Sprintf("unexpected status: %d", status))
}
```

## Function Design

- Functions SHOULD be **short and focused** — one function, one job.
- Functions SHOULD have **≤4 parameters**. Beyond that, use an options struct.
- **Parameter order:** `context.Context` first, then inputs, then output destinations.
- Naked returns only in very short (1-3 line) functions where return values are obvious.

```go
func FetchUser(ctx context.Context, id string) (*User, error)
func SendEmail(ctx context.Context, msg EmailMessage) error  // grouped into struct
```

### Prefer `range` for Iteration

SHOULD use `range` over index-based loops. Use `range n` (Go 1.22+) for simple counting.

```go
for _, user := range users {
    process(user)
}
```

## Value vs Pointer Arguments

Pass small types (`string`, `int`, `bool`, `time.Time`) by value. Use pointers when mutating, for large structs (~128+ bytes), or when nil is meaningful. [Details](./references/details.md)

## Code Organization Within Files

- **Group related declarations:** type, constructor, methods together.
- **Order:** package doc, imports, constants, types, constructors, methods, helpers.
- **One primary type per file** when it has significant methods.
- **Blank imports** register side effects — restrict to `main` and test packages so side effects are visible at the application root.
- **Dot imports** pollute the namespace — never use in library code.
- **Unexport aggressively** — you can always export later; unexporting is a breaking change.

## String Handling

Use `strconv` for simple conversions (faster), `fmt.Sprintf` for complex formatting. Use `%q` in error messages to make string boundaries visible. Use `strings.Builder` in loops, `+` for simple concatenation. Use `strings.Cut`/`CutLast` over `Index`+slicing.

## Type Conversions

Prefer explicit, narrow conversions. Use generics over `any` when a concrete type will do:

```go
func Contains[T comparable](slice []T, target T) bool  // not []any
```

## Philosophy

- **"A little copying is better than a little dependency"**
- **Use `slices` and `maps` standard packages**; for filter/group-by/chunk, reach for a small helper instead of a codebase-wide dependency
- **"Reflection is never clear"** — avoid `reflect` unless necessary
- **Don't abstract prematurely** — extract when the pattern is stable
- **Minimize public surface** — every exported name is a commitment

## Staying Current (Modern Go Idioms)

When the codebase targets a recent Go version, prefer the modern form. Full per-version details in [versions.md](./references/versions.md); CI/tooling guidance in [tooling.md](./references/tooling.md).

### Migrated / deprecated packages

| Deprecated | Replacement | Since |
| --- | --- | --- |
| `math/rand` | `math/rand/v2` | Go 1.22 |
| `crypto/elliptic` (most functions) | `crypto/ecdh` | Go 1.21 |
| `reflect.PtrTo` | `reflect.PointerTo` | Go 1.22 |
| `runtime.SetFinalizer` | `runtime.AddCleanup` | Go 1.24 |
| `golang.org/x/crypto/sha3`, `hkdf`, `pbkdf2` | stdlib `crypto/sha3`, `crypto/hkdf`, `crypto/pbkdf2` | Go 1.24 |
| `testing/synctest.Run` | `testing/synctest.Test` | Go 1.25 |
| `net/http/httputil.ReverseProxy.Director` | `.Rewrite` | Go 1.26 |
| `crypto/tls.Config.Rand` | `testing/cryptotest.SetGlobalRandom()` | Go 1.27 |
| `github.com/google/uuid` (simple cases) | `uuid` (stdlib) | Go 1.27 |

### Idiom upgrade checklist (by priority)

**High priority (safety/correctness):**
1. Remove loop variable shadow copies _(Go 1.22+)_
2. Replace `math/rand` with `math/rand/v2` _(Go 1.22+)_ — removes `rand.Seed`
3. Use `os.Root` for user-supplied file paths _(Go 1.24+)_ — prevents path traversal
4. Use `errors.Is`/`errors.As` instead of direct comparison _(Go 1.13+)_
5. Migrate deprecated crypto packages _(Go 1.24+)_
6. Before bumping `go 1.27`, resolve removed `GODEBUG` keys (a stale value now fails the build)

**Medium priority (readability):**
7. `any` instead of `interface{}` _(Go 1.18+)_
8. `min`/`max` builtins _(Go 1.21+)_
9. `range` over int _(Go 1.22+)_
10. `slices` and `maps` packages _(Go 1.21+)_
11. `cmp.Or` for defaults _(Go 1.22+)_
12. `sync.OnceValue`/`sync.OnceFunc` _(Go 1.21+)_
13. `sync.WaitGroup.Go` _(Go 1.25+)_
14. `t.Context()` in tests, `b.Loop()` in benchmarks _(Go 1.24+)_
15. `encoding/json/v2` (default since Go 1.27) — review stricter duplicate-key/UTF-8 handling first

**Lower priority (gradual):**
16. `slog` from third-party loggers _(Go 1.21+)_
17. Iterators where they simplify code _(Go 1.23+)_
18. `strings.SplitSeq` and iterator variants _(Go 1.24+)_
19. Enable PGO for production builds _(Go 1.21+)_
20. `go fix ./...` after a toolchain upgrade _(Go 1.27+)_

### Modernization workflow

1. Check the project's `go.mod`/`go.work` for the target Go version.
2. **Only suggest improvements relevant to the code the developer is actively working on.** Do not refactor unrelated files mid-task — record other opportunities as a note and let the developer schedule them.
3. Run `golangci-lint` (the `modernize` linter, available since golangci-lint v2.6.0) and `go test ./...` to verify. Go 1.27+ runs the `stdversion` vet check by default — bump the `go` directive or revert the suggestion, don't ignore the hit.
4. For a standalone full-scan modernization, run `go fix ./...` first, then verify each suggested change with `go build`/`go test`; a sweeping multi-file rewrite belongs in an isolated worktree.
5. Before suggesting a dependency update, run `go mod tidy` and the test suite to verify compatibility.

## Enforce with Linters

Many rules are enforced automatically: `gofmt`, `gofumpt`, `goimports`, `gocritic`, `revive`, `predeclared`, `misspell`, `errname`, `wsl_v5`. These cover formatting plus a large share of naming and style — this skill covers the judgment the linters can't.

## Parallelizing Style Reviews

When reviewing style/naming across a large codebase, use up to 5 parallel sub-agents, each targeting an independent concern (naming, control flow, function design, variable declarations, string handling, modernization). Merge findings, then stage any fix sweep as small, reviewable changes.

## Detailed References

| File | Scope |
| --- | --- |
| [details.md](./references/details.md) | Complex conditions, value vs pointer details |
| [identifiers.md](./references/identifiers.md) | Variables, booleans, receivers, acronyms |
| [packages-files.md](./references/packages-files.md) | Package/file naming, import aliasing |
| [functions-methods.md](./references/functions-methods.md) | Getters, constructors, named returns, options |
| [types-errors.md](./references/types-errors.md) | Interfaces, structs, constants, enums, errors |
| [testing.md](./references/testing.md) | Test function and subtest naming |
| [versions.md](./references/versions.md) | Full Go 1.21–1.27 modernization changelog |
| [tooling.md](./references/tooling.md) | golangci-lint v2, govulncheck, PGO, CI pipeline |