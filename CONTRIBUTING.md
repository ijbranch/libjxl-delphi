# Contributing

Issues and pull requests are welcome.

- **Issues:** describe what you did, what happened and what you expected, with the Delphi version, the platform
  (Win32 or Win64), the libjxl version (`JxlVersionToString( JxlDecoderVersion )`) and, where possible, a file that
  shows the problem.
- **Pull requests:** they are reviewed by the maintainer and, once accepted, integrated into the maintainer's source
  tree; they then appear here in the next release (with you credited in the commit), rather than being merged
  directly. Keep a pull request to one change.
- **Tests are required.** A change in behaviour comes with a DUnitX test in `Tests/` that fails without it; run the
  whole suite (Win64, and Win32 where it applies) before submitting. The build must have no hints or warnings.
- **Code style:** follow the existing units: two-space indentation, spaces inside parentheses
  (`if ( not Assigned( X ) ) then`), inline variables, lines of at most 162 characters, British English in comments and
  messages, and an XML documentation comment (`///`) on every declaration in an interface section. The `Jxl.Api.*`
  units mirror the C headers name for name; keep them that way.
- By submitting a contribution you agree that it is licensed under this project's licence (`LICENSE`).
