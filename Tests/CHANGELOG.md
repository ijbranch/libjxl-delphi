# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> The change record of the `LibJxlTests` test suite (`delphi\Tests`).  Kept beside the suite since
> 2026-10-25 (Ian: "every test suite should have its own change log"); test-only entries recorded before that in
> the repository's `CHANGELOG.md` were moved here the same day.  Product changes, including those that change a
> product unit together with its tests, stay in the repository's `CHANGELOG.md`.

## [In-Service]

### Added

- (2026-11-12) `Test_FrameSettings_OptionsNewIn013_AcceptedFrom013RefusedBefore` and two enumerator value checks, for
  the two encoder options libjxl 0.13.0 added — `TestJxl.Api.pas`.  The suite is now 104 tests; it passes against
  libjxl 0.13.0 (the options are accepted) and 0.12.0 (they are refused), official DLLs and the single DLL, Win64 and
  Win32.  The product change is in the repository's change log.
- (2026-10-25) **This change log** — `CHANGELOG.md`.  The suite's own record, per the estate rule that every test
  suite has one; test-only history moved in from `..\..\CHANGELOG.md` ( 7 entries ).
- (2026-10-16) Delphi binding tests: new fixture `TTestJxlCancellation` (6 tests) and 5 colour-encoding tests in
  `TTestJxlInfo` — `delphi/Tests/TestJxl.Cancellation.pas`, `delphi/Tests/TestJxl.Info.pas`,
  `delphi/Tests/LibJxlTests.dpr`, `delphi/Tests/LibJxlTests.dproj`. Cancellation: before the call (every
  routine, no file written, a 16-megapixel encode raises within 20 ms, `Reset`), from another thread during an
  encode, a decode and a validation (each stopping in under half the uncancelled time), the runner's contract
  with libjxl driven directly (init and tasks not called when cancelled, remaining tasks skipped and failure
  returned when cancelled mid-batch), a raw encoder cancelled mid-way releasing every byte of its
  `TJxlMemoryBudget`, and a token never cancelled giving byte-identical output. Colour: `bike` (sRGB primaries,
  BT.709 transfer: not sRGB), eight encoded profiles against each part of the `IsSrgb` definition, the binding's
  own output, Rec. 2020 / sRGB / sGrey ICC profiles with exact sizes, and the conformance `grayscale` (grey
  ICC), `spot` (940-byte ProPhoto ICC) and `cmyk_layers` (CMYK ICC, colour space unknown). Mutation-proved.
  Suite 85 -> 96 tests, Win64 and Win32.
- (2026-10-16) Delphi binding tests: new fixture `TTestJxlLimits` (every limit, the JPEG pre-check with small synthetic
  headers built in the test) and tests for safe loading, the export tables (parsed from the sources), the
  version check, the memory budget, ICC round trip, grey handling, orientation, nil-bitmap ordering,
  encoder-setting checks, `TJxlImage` (Assign, files, streams at a position, alpha, corrupt data, empty save)
  and the container walk's edge cases; 61 to 85 tests, green on Win64 and Win32, 15 mutants killed —
  `delphi/Tests/TestJxl.Limits.pas`, `delphi/Tests/TestJxl.Api.pas`, `delphi/Tests/TestJxl.Graphic.pas`,
  `delphi/Tests/TestJxl.Info.pas`, `delphi/Tests/TestJxl.Conformance.pas`, `delphi/Tests/TestJxl.Common.pas`,
  `delphi/Tests/LibJxlTests.dpr`, `delphi/Tests/LibJxlTests.dproj`
- (2026-10-16) `JxlReadInfo` / `JxlValidate` tests assert instead of erroring — `delphi/Tests/TestJxl.Info.pas`.
  Calls on files that must be valid go through `ReadInfoOk` / `ValidateOk` (`Assert.WillNotRaise( ..., EJxlError
  )`, and for validation every announced frame decoded); expected rejections check the `EJxlError` message. The
  three mutants that previously turned the suite red only through exceptions (`JxlDecoderCloseInput` dropped,
  the large box size read as 32-bit, `JXL_DEC_FULL_IMAGE` not subscribed) are now KILLED, and the other nine
  mutants on this code were re-run and are still KILLED.
- (2026-10-16) WIC cross-check fixture for the Delphi binding — `delphi/Tests/TestJxl.Wic.pas`,
  `delphi/Tests/LibJxlTests.dpr`, `delphi/Tests/LibJxlTests.dproj`. Decodes the same files through the binding
  and through Windows' own JPEG XL codec (WIC, Microsoft's JPEG XL Image Extension) to 32-bit BGRA: `flower.png`
  and `flower_alpha.png` encoded losslessly by the binding decode byte-identical through WIC and equal the PNG's
  pixels; the lossy conformance `bike` agrees within max 1 / mean 0.32 per sample. WIC returns the image in its
  own colour encoding (bike: BT.709 transfer), so the binding is compared with `jcoImageProfile`; against its
  default sRGB output the difference is max 17 / mean 6.4, the transfer-curve conversion. Without a WIC JPEG XL
  decoder the tests are reported as ignored. 45 tests, green; 4 mutants (channel order, WIC target format,
  colour output, alpha bookkeeping in the comparison), all killed. **Why:** an independent decoder catches a
  colour, channel-order or layout fault that the binding's own round trips cancel out.

### Changed

- (2026-10-16) Test data location configurable — `delphi/Tests/TestJxl.Common.pas`,
  `delphi/Tests/TestJxl.Conformance.pas`, `delphi/Tests/TestJxl.Info.pas`, `delphi/Tests/TestJxl.Limits.pas`,
  `delphi/Tests/TestJxl.Wic.pas`. `LIBJXL_TESTDATA` (a libjxl checkout's `testdata`, replacing `JXL_TESTDATA`)
  and `JXL_CONFORMANCE` (now the `testcases` folder; its parent still accepted) override the walk-up search; a
  test whose data is absent is ignored with a message naming the variable instead of erroring. **Why:** a clone
  of the public repository has neither folder beside it.
- (2026-10-16) Delphi binding test runner: `FailsOnNoAsserts` and case-sensitive string assertions (`Assert.IgnoreCaseDefault
  := False`) — `delphi/Tests/LibJxlTests.dpr`

### Fixed

- (2026-10-16) Delphi binding tests: nine tests a real bug could pass are strengthened: the thread runners run a
  parallel job and check every value; the default CMS converts linear 128 to sRGB 188; library availability also
  covers the failing seams; lossy encoding proves the distance reaches the encoder; bitmap alpha is compared
  with the PNG reader; progressive decoding checks the final pixels; CMYK layers are compared with their
  reference; the float decode fails on NaN; invalid input pins `ApiName`, status and message —
  `delphi/Tests/TestJxl.Api.pas`, `delphi/Tests/TestJxl.Graphic.pas`, `delphi/Tests/TestJxl.Conformance.pas`,
  `delphi/Tests/TestJxl.Info.pas`
