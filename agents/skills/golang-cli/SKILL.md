---
name: golang-cli
description: "Golang CLI application development with spf13/cobra + viper. Use when building, modifying, or reviewing a Go CLI tool — command tree structure, RunE vs Run and the PersistentPreRunE hook chain, Args validators, persistent vs local flags, flag validation and completions, configuration layering with viper, version embedding via ldflags, exit codes, stdout/stderr discipline and I/O patterns, signal handling, shell completion, and testing commands with SetArgs/SetOut/SetErr. Also triggers when code imports github.com/spf13/cobra, github.com/spf13/viper, or urfave/cli. Not for general style (→ golang-style skill), architecture patterns/errors (→ golang-patterns skill), or test strategy (→ golang-testing skill)."
user-invocable: true
license: MIT
compatibility: Designed for Claude Code, Codex or similar harness, and for projects using Golang.
allowed-tools: Read Edit Write Glob Grep Bash(go:*) Bash(golangci-lint:*) Bash(git:*) Agent WebFetch AskUserQuestion
paths:
  - "**/*.go"
---

# Go CLI Best Practices (Cobra + Viper)

Use Cobra + Viper as the default stack for Go CLI applications. Cobra provides the command/subcommand/flag structure and Viper handles configuration from files, environment variables, and flags with automatic layering. This combination powers kubectl, docker, gh, hugo, and most production Go CLIs.

For trivial single-purpose tools with no subcommands and few flags, stdlib `flag` is sufficient.

## Quick Reference

| Concern | Package / Tool |
| --- | --- |
| Commands & flags | `github.com/spf13/cobra` |
| Configuration | `github.com/spf13/viper` |
| Flag parsing | `github.com/spf13/pflag` (via Cobra) |
| Colored output | `github.com/fatih/color` |
| Table output | `github.com/olekukonko/tablewriter` |
| Interactive prompts | `github.com/charmbracelet/bubbletea` |
| Version injection | `go build -ldflags` |
| Distribution | `goreleaser` |

## Project Structure

```
myapp/
├── cmd/
│   └── myapp/
│       ├── main.go              # package main, only calls Execute()
│       ├── root.go              # Root command + Viper init
│       ├── serve.go             # "serve" subcommand
│       ├── migrate.go           # "migrate" subcommand
│       └── version.go           # "version" subcommand
├── go.mod
└── go.sum
```

`main.go` should be minimal. See [assets/examples/main.go](assets/examples/main.go).

## Cobra vs viper

| Concern | cobra | viper |
| --- | --- | --- |
| Owns | Command tree, flags, arg validation, completions | Configuration value resolution |
| Without the other? | Yes — a CLI with flags only | Yes — a daemon reading YAML + env |
| Integration seam | Hands `pflag.Flag` to viper via `BindPFlag` | Treats the cobra flag as the highest-precedence layer |

Use cobra alone for flags+args with no config file/env. Use viper alone for a long-running service reading YAML + env with no subcommands. Use both when you need both — bind at `PersistentPreRunE` on the root.

## Root Command Setup

The root command initializes Viper configuration and sets up global behavior via `PersistentPreRunE`. See [assets/examples/root.go](assets/examples/root.go).

Key points:

- `SilenceUsage: true` MUST be set — prevents printing the full usage text on every error
- `SilenceErrors: true` MUST be set — lets you control error output format yourself
- `PersistentPreRunE` runs before every subcommand, so config is always initialized
- Logs go to stderr, output goes to stdout
- Register command groups (`AddGroup`) **before** the `AddCommand` calls that reference them — cobra does not retroactively assign groups

## The Run\* family & hook chain

Always use `*E` variants — the non-`E` forms cannot return errors:

```
PersistentPreRunE → PreRunE → RunE → PostRunE → PersistentPostRunE
```

- `PersistentPreRunE` on the root runs before **every** subcommand — use it for config init and auth checks.
- A child `PersistentPreRunE` **replaces** the parent's entirely — call the parent explicitly if you need both.
- `PostRunE` runs only if `RunE` succeeded.

For the full lifecycle and inheritance rules, see [commands-and-args.md](references/commands-and-args.md).

### Subcommands

Add subcommands as separate files in `cmd/myapp/` registered in `init()`. See [assets/examples/serve.go](assets/examples/serve.go) for a complete subcommand example including command groups.

## Argument Validation

Cobra validates positional arguments before `RunE` runs. Never write `len(args)` checks inside `RunE` — that bypasses cobra's standard error messages. Compose with `MatchAll(v1, v2)`; custom validators take `func(cmd *cobra.Command, args []string) error`.

| Validator | Description |
| --- | --- |
| `cobra.NoArgs` | Fails if any args provided |
| `cobra.ExactArgs(n)` | Requires exactly n args |
| `cobra.MinimumNArgs(n)` | Requires at least n args |
| `cobra.MaximumNArgs(n)` | Allows at most n args |
| `cobra.RangeArgs(min, max)` | Requires between min and max |
| `cobra.ExactValidArgs(n)` | Exactly n args, must be in ValidArgs |

See [assets/examples/args.go](assets/examples/args.go) and [commands-and-args.md](references/commands-and-args.md).

## Flags

See [assets/examples/flags.go](assets/examples/flags.go) for all flag patterns; [flags.md](references/flags.md) for pflag types, custom values, and groups.

- **Persistent flags** (`.PersistentFlags()`) are inherited by all subcommands (e.g. `--config`)
- **Local flags** (`.Flags()`) apply only to the declaring command (e.g. `--port`)
- Use `MarkFlagRequired`, `MarkFlagsMutuallyExclusive`, `MarkFlagsOneRequired` for flag constraints
- Provide completion suggestions via `RegisterFlagCompletionFunc`

### Always Bind Flags to Viper

`viper.BindPFlag` for every configurable flag ensures `viper.GetInt("port")` returns the flag value, env var `MYAPP_PORT`, or config file value — whichever has highest precedence.

## Configuration with Viper

Viper resolves configuration values in this order (highest to lowest precedence): **CLI flags** → **environment variables** → **config file** → **defaults**.

```yaml
port: 8080
host: localhost
log-level: info
database:
  dsn: postgres://localhost:5432/myapp
```

With `SetEnvPrefix("MYAPP")`, these are all equivalent: `--port 9090`, `MYAPP_PORT=9090`, `port: 9090` in the config file. Ignore `viper.ConfigFileNotFoundError` — config should be optional. See [assets/examples/config.go](assets/examples/config.go).

## Version and Build Info

Version SHOULD be embedded at compile time via `ldflags`. See [assets/examples/version.go](assets/examples/version.go).

## Exit Codes

Exit codes MUST follow Unix conventions. Return errors from `RunE` and let `main()` decide the exit — never call `os.Exit` inside handlers (defers and cleanup never run).

| Code | Meaning | When to Use |
| --- | --- | --- |
| 0 | Success | Operation completed normally |
| 1 | General error | Runtime failure |
| 2 | Usage error | Invalid flags or arguments |
| 64-78 | BSD sysexits | Specific error categories |
| 126 | Cannot execute | Permission denied |
| 127 | Command not found | Missing dependency |
| 128+N | Signal N | Terminated by signal (e.g., 130 = SIGINT) |

See [assets/examples/exit_codes.go](assets/examples/exit_codes.go).

## I/O Patterns

See [assets/examples/output.go](assets/examples/output.go):

- **stdout vs stderr**: NEVER write diagnostics to stdout — stdout is for program output (pipeable), stderr for logs/errors
- **Always use `cmd.OutOrStdout()` / `cmd.ErrOrStderr()`** inside command handlers (not `os.Stdout`/`os.Stderr`) so tests can redirect output
- **Detecting pipe vs terminal**: check `os.ModeCharDevice` on stdout
- **Machine-readable output**: support `--output` for table/json/plain
- **Colors**: `fatih/color` auto-disables when output is not a terminal

## Signal Handling

Signal handling MUST use `signal.NotifyContext` to propagate cancellation through context. See [assets/examples/signal.go](assets/examples/signal.go) for graceful HTTP server shutdown.

## Shell Completions

Cobra generates completions for bash, zsh, fish, and PowerShell automatically. Extend with:

- **`ValidArgs []string`** — static positional arg completion
- **`ValidArgsFunction`** — dynamic: `func(cmd, args, toComplete string) ([]string, ShellCompDirective)`; return `ShellCompDirectiveNoFileComp` to suppress file fallback
- **`RegisterFlagCompletionFunc(name, fn)`** — flag value completion

See [assets/examples/completion.go](assets/examples/completion.go) and [completions.md](references/completions.md) for the `ShellCompDirective` set, annotations, and testing.

Also generate man pages / markdown docs — see [generators.md](references/generators.md).

## Testing CLI Commands

Test commands by executing them programmatically with `cmd.SetArgs`, `cmd.SetOut`, and `cmd.SetErr`. **Never use `os.Stdout`/`os.Stderr` directly** so output is capturable:

```go
func TestServeCmd(t *testing.T) {
    buf := new(bytes.Buffer)
    rootCmd.SetOut(buf)
    rootCmd.SetArgs([]string{"serve", "--port", "9090"})
    require.NoError(t, rootCmd.Execute())
    assert.Contains(t, buf.String(), "listening on :9090")
}
```

Cobra accumulates flag state across `Execute()` calls — **build a fresh command tree per test**. See [assets/examples/cli_test.go](assets/examples/cli_test.go) and [testing.md](references/testing.md) for isolation patterns, golden files, and testing completions.

## Common Mistakes

| Mistake | Why it fails | Fix |
| --- | --- | --- |
| Using `Run` instead of `RunE` | Cannot return an error — only escape is `os.Exit`/panic, bypassing defers | Always `RunE` — return the error, let cobra handle exit |
| Writing `len(args)` checks in `RunE` | Bypasses cobra's standard error messages | Declare `Args: cobra.ExactArgs(1)` on the command |
| Writing to `os.Stdout` directly | Tests cannot capture output — os-level handles can't be redirected | `cmd.OutOrStdout()` / `cmd.ErrOrStderr()` |
| Calling `os.Exit()` inside `RunE` | Skips cobra error handling, defers, and cleanup | Return the error; let `main()` decide |
| Not binding flags to Viper | Flags aren't configurable via env/config | `viper.BindPFlag` per configurable flag |
| Missing `viper.SetEnvPrefix` | `PORT` collides with other tools | Prefix env vars (`MYAPP_PORT`) |
| Logging to stdout | Logs corrupt piped data streams | Logs go to stderr |
| Printing usage on every error | Full help text on errors is noise | `SilenceUsage: true` |
| Config file required | Users without config crash | Ignore `ConfigFileNotFoundError` — config optional |
| Child `PersistentPreRunE` silently drops parent's | Cobra does not chain — child replaces parent's hook | Call `parent.PersistentPreRunE(cmd, args)` from the child |
| Reusing a root command across tests | Cobra accumulates flag state between `Execute()` calls | Build a fresh command tree per test |
| Not using `PersistentPreRunE` | Config init must run before any subcommand | Use root's `PersistentPreRunE` |
| Hardcoded version string | Drifts from git tags | Inject via `ldflags` |
| Not supporting `--output` format | Scripts can't parse output | Add JSON/table/plain |

## Further Reading

- [commands-and-args.md](references/commands-and-args.md) — full PreRun\*/PostRun\* chain, every Args validator, inheritance rules
- [flags.md](references/flags.md) — pflag types, required/exclusive groups, custom value types, viper binding
- [completions.md](references/completions.md) — ShellCompDirective set, annotations, testing completions
- [generators.md](references/generators.md) — man page, markdown, YAML, RST doc generation; `cobra-cli` scaffolder
- [testing.md](references/testing.md) — isolation patterns, golden files, table-driven command tests

Official resources: <https://pkg.go.dev/github.com/spf13/cobra>, <https://github.com/spf13/cobra>, <https://cobra.dev>. When using Cobra or Viper, refer to the official docs for current API signatures. If you encounter a bug in spf13/cobra, file an issue at <https://github.com/spf13/cobra/issues>.