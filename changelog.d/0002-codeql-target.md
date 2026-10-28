[Features]
- `security.mk` gains `make codeql`: CodeQL static analysis of Go code
  with the `go-code-scanning` suite code scanning uses, failing on any
  finding. The database is built without CodeQL's build tracer, so it
  also runs on Apple Silicon without Rosetta. Not in the default
  `SECURITY_SCANS`.
