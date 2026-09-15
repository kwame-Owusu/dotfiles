---
name: golang-patterns
description: "Architecting robust, secure, production-ready Go — design patterns, error handling, and security. Use when implementing or reviewing constructors and functional options, enums, error creation/wrapping/inspection, panic vs error decisions, resource management, graceful shutdown, timeouts and retries, streaming, dependency/library selection, or writing/reviewing code that touches crypto, file/network I/O, secrets, user input, or authentication. Not for idiomatic style and naming (→ golang-style skill), CLI structure (→ golang-cli skill), or test strategy (→ golang-testing skill)."
user-invocable: true
license: MIT
compatibility: Designed for Claude Code, Codex or similar harness, and for projects using Golang.
paths:
  - "**/*.go"
---

# Go Patterns, Errors & Security

Idiomatic patterns and reliability/security guidance for production-level Go code. Apply patterns only when they solve a real problem — not to demonstrate sophistication — and push back on premature abstraction.

## Best Practices Summary

1. Constructors SHOULD use **functional options** — they scale as APIs evolve (one function per option, no breaking changes)
2. Functional options MUST **return an error** if validation can fail — catch bad config at construction, not at runtime
3. **Avoid `init()`** — runs implicitly, cannot return errors, makes testing unpredictable. Use explicit constructors
4. Enums SHOULD **start at 1** (Unknown sentinel at 0) — Go's zero value silently passes as the first enum member
5. Error cases MUST be **handled first** with early return — keep happy path flat
6. **Panic is for bugs, not expected errors** — returned errors are handleable; panics crash the process
7. **`defer Close()` immediately after opening** — later code changes can silently skip cleanup
8. **`runtime.AddCleanup`** over `runtime.SetFinalizer` — finalizers are unpredictable
9. Every external call SHOULD **have a timeout** — a slow upstream hangs your goroutine indefinitely
10. **Limit everything** (pools, queue depths, buffers) — unbounded resources grow until they crash
11. Retry logic MUST **check context cancellation** between attempts
12. **Use `strings.Builder`** for concatenation in loops; **`[]byte` for mutation and I/O**, `string` for display and keys
13. Iterators (Go 1.23+) and streaming **prevent OOM on large data** — don't load millions of rows into memory
14. **`//go:embed`** for static assets — eliminates runtime file I/O errors
15. **Use `crypto/rand`** for keys/tokens — `math/rand` is predictable
16. Regexp MUST be **compiled once at package level** — compilation is O(n) and allocates
17. Compile-time interface checks: **`var _ Interface = (*Type)(nil)`**
18. **A little code > a big dependency** — each dep adds attack surface and maintenance burden
19. **Design for testability** — accept interfaces, inject dependencies

## Constructors: Functional Options vs Builder

### Functional Options (Preferred)

```go
type Server struct {
    addr         string
    readTimeout  time.Duration
    writeTimeout time.Duration
    maxConns     int
}

type Option func(*Server)

func WithReadTimeout(d time.Duration) Option {
    return func(s *Server) { s.readTimeout = d }
}
func WithMaxConns(n int) Option {
    return func(s *Server) { s.maxConns = n }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{
        addr:         addr,
        readTimeout:  5 * time.Second,
        writeTimeout: 10 * time.Second,
        maxConns:     100,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

srv := NewServer(":8080",
    WithReadTimeout(30*time.Second),
    WithMaxConns(500),
)
```

Use the builder pattern only if you need complex validation between configuration steps.

## Constructors & Initialization

### Avoid `init()` and Mutable Globals

`init()` runs implicitly, makes testing harder, and creates hidden dependencies: declaration order across files is fragile (filename alphabetical), it cannot return errors, and side effects run before `main()` and tests.

```go
// Bad — hidden global state
var db *sql.DB

func init() { /* sql.Open from env, log.Fatal on error */ }

// Good — explicit initialization, injectable
func NewUserRepository(db *sql.DB) *UserRepository {
    return &UserRepository{db: db}
}
```

### Enums: Start at 1

```go
type Status int

const (
    StatusUnknown Status = iota // 0 = invalid/unset
    StatusActive
    StatusInactive
    StatusSuspended
)
```

### Compile Regexp Once, Embed Assets, Check Interfaces

```go
var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@...$`)

//go:embed templates/*
var templateFS embed.FS

var _ Interface = (*Type)(nil) // compile-time interface check
```

## Error Handling

Errors are events that must either be handled or propagated with context — silent failures and duplicate logs are equally unacceptable.

### Best Practices

1. **Returned errors MUST always be checked** — NEVER discard with `_`
2. **Errors MUST be wrapped with context** — `fmt.Errorf("parsing token: %w", err)`
3. **Error strings MUST be lowercase**, no trailing punctuation
4. **Use `%w` internally, `%v` at system boundaries** to control error-chain exposure
5. **MUST use `errors.Is`/`errors.As`** for sentinel/typed matching, NEVER direct comparison or bare type assertions. Go 1.26+: prefer `errors.AsType[T](err)`
6. **SHOULD use `errors.Join`** (Go 1.20+) to combine independent errors
7. **Errors MUST be either logged OR returned, NEVER both** (single handling rule — prevents duplicate logs in aggregators)
8. **Sentinel errors** for expected conditions; **custom error types** for carrying data
9. **NEVER `panic` for expected errors** — reserved for truly unrecoverable states
10. **SHOULD use `slog`** (Go 1.21+) for structured logging — not `fmt.Println`/`log.Printf`
11. **Never expose technical errors to users** — translate to user-friendly messages, log technical details server-side
12. **Keep log grouping low-cardinality** — stable message templates; attach IDs, paths, counts as structured attributes; avoid PII in messages

### Panic vs Return Error

- **Return error:** network failures, file not found, invalid input — anything a caller can handle
- **Panic:** nil pointer where impossible, violated invariant, `Must*` constructors at init time

### When to log-and-return (the anti-pattern)

The single handling rule: each error is handled exactly once — either logged where it happens (with context) or returned for the caller. Log-and-return produces duplicate log lines across the stack.

Full detail in [error-creation.md](./references/error-creation.md), [error-wrapping.md](./references/error-wrapping.md), [error-handling.md](./references/error-handling.md).

## Resource Management & Resilience

### `defer Close()` Immediately

```go
f, err := os.Open(path)
if err != nil {
    return err
}
defer f.Close() // right here, not 50 lines later
```

### Timeout Every External Call

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
resp, err := httpClient.Do(req.WithContext(ctx))
```

### Retry & Context Checks

Retry logic MUST check `ctx.Err()` between attempts and back off via `select` on `ctx.Done()`. Long loops MUST check `ctx.Err()` periodically. For graceful shutdown, resource pools, and `runtime.AddCleanup`, see [resource-management.md](./references/resource-management.md).

## Data Handling

| Type | Default for | Use when |
| --- | --- | --- |
| `string` | Everything | Immutable, safe, UTF-8 |
| `[]byte` | I/O | Writing to `io.Writer`, building strings, mutations |
| `[]rune` | Unicode ops | `len()` must mean characters, not bytes |

Avoid repeated conversions — each allocates. Use iterators (Go 1.23+) and streaming for large datasets so memory stays constant (e.g. 1M DB rows to HTTP — stream, don't buffer). [Data handling patterns](./references/data-handling.md)

## Architecture

Ask the developer which architecture they prefer: clean, hexagonal, DDD, or flat layout. Don't impose complex architecture on a small project.

Core principles regardless of choice:
- **Keep domain pure** — no framework dependencies in the domain layer
- **Fail fast** — validate at boundaries, trust internal code
- **Make illegal states unrepresentable** — use types to enforce invariants

Guides: [architecture-patterns.md](./references/architecture-patterns.md), [clean-architecture.md](./references/clean-architecture.md), [hexagonal-architecture.md](./references/hexagonal-architecture.md), [ddd.md](./references/ddd.md).

## Security

Security follows **defense in depth**: protect at multiple layers, validate all inputs, use secure defaults, leverage the standard library's security-aware design.

### Security Thinking Model

Before writing or reviewing security-sensitive code, ask three questions:
1. **What are the trust boundaries?** — Where does untrusted data enter? (HTTP requests, file uploads, env vars, DB rows)
2. **What can an attacker control?** — Which inputs flow into sensitive operations? (SQL, shell commands, HTML output, file paths, crypto)
3. **What is the blast radius?** — If this defense fails, what's the worst outcome? (data leak, RCE, privilege escalation, DoS)

### Quick Reference

| Severity | Vulnerability | Defense | Standard Library Solution |
| --- | --- | --- | --- |
| Critical | SQL Injection | Parameterized queries separate data from code | `database/sql` with `?` placeholders |
| Critical | Command Injection | Pass args separately, never via shell concatenation | `exec.Command` with separate args |
| High | XSS | Auto-escaping renders user data as text | `html/template` |
| High | Path Traversal | Scope untrusted file access to an allowed root | Go 1.24+: `os.Root`. Pre-1.24: `filepath.IsLocal` + `filepath.Rel` |
| High | Crypto Issues | Vetted algorithms; never roll your own | `crypto/aes` GCM, `crypto/rand` |
| High | Race Conditions | Protect shared state | `sync.Mutex`, channels, avoid shared state |
| Medium | Timing Attacks | Constant-time comparison | `crypto/subtle.ConstantTimeCompare` |
| Medium | HTTP Security | TLS + security headers | `net/http` + TLSConfig, headers middleware |
| Medium | Rate Limiting | Prevent brute-force / resource exhaustion | `golang.org/x/time/rate`, server timeouts |

### Common Mistakes & Anti-Patterns

| Severity | Mistake | Fix |
| --- | --- | --- |
| High | `math/rand` for tokens | Predictable — use `crypto/rand` |
| Critical | SQL string concatenation | Parameterized queries |
| Critical | `exec.Command("bash -c")` | Separate args — avoids shell metacharacter parsing |
| Critical | Hardcoded secrets | Env vars or secret managers — source ends up in version history |
| Medium | Comparing secrets with `==` | `crypto/subtle.ConstantTimeCompare` |
| Medium | Returning detailed errors | Generic to users, detailed server-side |
| High | MD5/SHA1 for passwords | Argon2id or bcrypt (memory-hard, slow) |
| High | AES without GCM | ECB/CBC unauthenticated — GCM encrypts+authenticates |
| Medium | Binding to `0.0.0.0` | Bind to a specific interface |
| Critical | Ignoring crypto errors | Always check errors — fail closed, never open |
| High | Trusting client headers (`X-Forwarded-For`, `X-Is-Admin`) | Server-side identity verification |
| High | Client-side authorization | Server-side permission checks on every handler |

### Research Before Reporting

Before flagging a security issue, trace the full data flow: follow the variable to its origin, check for upstream validation, examine the trust boundary, and read surrounding code (middleware may already defend). Upstream protection **adjusts severity, not findings** — defense in depth means each layer protects itself. Document downgrades with an inline `// security: ...` comment so future audits don't re-flag them.

### Tooling & Verification

```bash
go tool gosec ./...        # SAST
go tool govulncheck ./...  # dependency vulnerabilities
go test -race ./...        # race detector
go test -fuzz=Fuzz         # fuzzing
```

Security-relevant linters: `bodyclose`, `sqlclosecheck`, `nilerr`, `errcheck`, `govet`, `staticcheck`.

Domain guides (cryptography, injection, filesystem, network, cookies, secrets, logging, memory safety, third-party, threat modeling with STRIDE/DREAD, security architecture) — see the Detailed References table below.

## Library Selection

When recommending libraries:
1. **Assess requirements first** — use case, performance, constraints
2. **Check the standard library first** — often sufficient (and always prefer it when it covers the case)
3. **Prioritize maturity** — check maintenance status, license, and community adoption (`imported-by` count on pkg.go.dev) before recommending
4. **Consider complexity** — simpler is better in Go; more deps = more attack surface
5. **Avoid abandoned libraries and wrapper libs** that add nothing over stdlib

Anti-patterns: over-engineering simple problems, wrapping stdlib without value, large dependency footprints for simple needs. The best library is often no library at all.

Catalogs: [libraries.md](./references/libraries.md) (vetted third-party by category), [stdlib.md](./references/stdlib.md) (new & experimental), [tools.md](./references/tools.md) (dev tooling). See also <https://github.com/avelino/awesome-go>.

## Code Philosophy

- **Avoid repetitive code** — but don't abstract prematurely
- **Minimize dependencies** — a little code > a big dependency
- **Design for testability** — accept interfaces, inject dependencies, keep functions pure

## Detailed References

| Category | Files |
| --- | --- |
| Patterns & architecture | [architecture-patterns.md](./references/architecture-patterns.md), [clean-architecture.md](./references/clean-architecture.md), [hexagonal-architecture.md](./references/hexagonal-architecture.md), [ddd.md](./references/ddd.md), [data-handling.md](./references/data-handling.md), [resource-management.md](./references/resource-management.md) |
| Error handling | [error-creation.md](./references/error-creation.md), [error-wrapping.md](./references/error-wrapping.md), [error-handling.md](./references/error-handling.md) |
| Security | [cryptography.md](./references/cryptography.md), [injection.md](./references/injection.md), [filesystem.md](./references/filesystem.md), [network.md](./references/network.md), [cookies.md](./references/cookies.md), [secrets.md](./references/secrets.md), [logging.md](./references/logging.md), [memory-safety.md](./references/memory-safety.md), [third-party.md](./references/third-party.md), [threat-modeling.md](./references/threat-modeling.md), [checklist.md](./references/checklist.md), [architecture.md](./references/architecture.md) |
| Libraries | [libraries.md](./references/libraries.md), [stdlib.md](./references/stdlib.md), [tools.md](./references/tools.md) |