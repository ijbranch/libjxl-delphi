# libjxl-delphi: a Delphi binding for libjxl (JPEG XL)

A Delphi (Object Pascal) binding for the C API of [libjxl](https://github.com/libjxl/libjxl), the JPEG XL reference
implementation, plus a VCL graphic class so that `TImage` and `TPicture` load and save JPEG XL. It calls libjxl's
shared libraries; nothing is reimplemented in Pascal.

**This is an unofficial binding.** It is not affiliated with, endorsed by or supported by the JPEG XL Project, Google
or the JPEG committee. "JPEG XL" and "libjxl" refer to their work; problems in libjxl itself belong to
[its issue tracker](https://github.com/libjxl/libjxl/issues).

- **Delphi 13 (RAD Studio 13 Florence) or later**, VCL, **Win32 and Win64**.
- **libjxl 0.12.0 or later.** This release is tested against the official libjxl **v0.12.0** Windows release
  (x64 and x86).
- Depends only on the Delphi RTL and VCL (the package requires `rtl`, `vcl` and `vclimg`). The tests use DUnitX, which
  ships with Delphi.
- Licence: BSD 3-Clause (`LICENSE`). libjxl is licensed separately; see [Licences](#licences).

## Layout

| Path | What it is |
|---|---|
| `Source/Jxl.Api.Types.pas` | `types.h`, `codestream_header.h`, `color_encoding.h`, `memory_manager.h`, `parallel_runner.h`, `cms_interface.h`, `stats.h`, the `gain_map.h` record; DLL names, `EJxlError`, `JxlCheckLibrary` |
| `Source/Jxl.Api.Decode.pas` | `decode.h` |
| `Source/Jxl.Api.Encode.pas` | `encode.h` |
| `Source/Jxl.Api.Threads.pas` | `thread_parallel_runner.h`, `resizable_parallel_runner.h` |
| `Source/Jxl.Api.Cms.pas` | `cms.h` (`JxlGetDefaultCms`) |
| `Source/Jxl.Graphic.pas` | `TJxlImage` (a `TBitmap` registered for `.jxl`) and one-call routines |
| `Packages/LibJxl.dpk` | Runtime-only package containing all six units |
| `Tests/LibJxlTests.dpr` | DUnitX console test runner |
| `Demos/JxlViewer/JxlViewer.dpr` | VCL demo: a JPEG XL viewer and converter |
| `LibJxl.groupproj` | Project group: the package, the tests and the demo |
| `CopyJxlDlls.ps1` | Post-build step of the tests and the demo: copies the libjxl DLLs next to the executable |
| `LICENSE`, `THIRD-PARTY-NOTICES.md`, `third-party/libjxl/` | This binding's licence; libjxl's licence and patent grant |

## Getting libjxl

The binding needs libjxl's DLLs, built for the same platform as your executable. Any of these works:

1. **The official libjxl release** (recommended): [libjxl v0.12.0](https://github.com/libjxl/libjxl/releases/tag/v0.12.0),
   assets `jxl-x64-windows.zip` (Win64) and `jxl-x86-windows.zip` (Win32). The DLLs the binding needs are in
   `x64-windows\bin` / `x86-windows\bin`: `jxl.dll`, `jxl_threads.dll`, `jxl_cms.dll`, `brotlicommon.dll`,
   `brotlidec.dll` and `brotlienc.dll` (the other DLLs there belong to libjxl's command-line tools). Their SHA-256,
   as they are in upstream's archives:

   | DLL | x64 (`jxl-x64-windows.zip`) | x86 (`jxl-x86-windows.zip`) |
   |---|---|---|
   | `jxl.dll` | `b0a7f7721836359b29841cca0f15969e85bd386344f9ee0775292089bd3bcfda` | `15fa1f1ae3cac68cebcbf60976ed146b9d5bc20b60f12706e73a48b5b5009d4d` |
   | `jxl_threads.dll` | `2aa59fe1ed74715b7160b29c3ca4c3dc398212a0450d4b292c7174fa65305928` | `876794fce92972d486cd18c4694ea53ebbc7475a0488c90e6226f3e038d3ea31` |
   | `jxl_cms.dll` | `cf4d1e872fe0730b0a39d34cc8414fbf9a4c85424708c1552de270330ec8ae51` | `99d50590b561fc1ae12ec5ea19c97fdfdd43a4c11df3b40ed9a8b0450c363c4d` |
   | `brotlicommon.dll` | `b6a024f4a3d82dc80b8faad898ca4637fe6fc8e4e65042b6036d53a0d933bcb1` | `1e6756921bb6e98cae6e327b4a80aa702f43fbe6c5da585df9b6d0cdd2273650` |
   | `brotlidec.dll` | `6155edcd8dbb15e020d7f157074a9e3d4cec93d46d949192d23edcd37d1783d7` | `b956b61b427682b376cadf150c2030a931c4a0d22c95c6f8d7f1a3f7473e4dbf` |
   | `brotlienc.dll` | `02db3121417982f3cc4871fb487e2356a4ac233c1b9eafeaaacfc0341f5ccaa2` | `ed7a7190c404acf340afe9c73f5dd9b2a696a227dba4bed018383bc0ec2daee8` |

   These DLLs link the Microsoft Visual C++ runtime dynamically: the target machine needs the
   [Visual C++ Redistributable](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist) (x64 or x86), or
   `vcruntime140.dll` and `msvcp140.dll` shipped beside them.
2. **This repository's releases** carry a convenience copy of exactly those six DLLs per architecture, byte-identical
   to upstream's (same SHA-256 as above), with libjxl's licence, patent grant and the third-party licences from the
   official archive. Prefer upstream's page when you can.
3. **vcpkg:** `vcpkg install libjxl:x64-windows` (or `x86-windows`); the DLLs are in `installed\<triplet>\bin`.
4. **Build libjxl from source** with CMake and MSVC or clang-cl, once per platform
   ([BUILDING.md](https://github.com/libjxl/libjxl/blob/main/BUILDING.md); `git submodule update --init --recursive`
   first):

   ```bat
   cmake -B build-x64 -A x64 -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_TOOLS=OFF
   cmake --build build-x64 --config Release
   ```

   The DLLs are in `build-x64\lib\Release` and `build-x64\third_party\brotli\Release`.

MinGW / MSYS2 builds name the DLLs `libjxl.dll`, `libjxl_threads.dll` and `libjxl_cms.dll`; the binding accepts those
names too. When a new libjxl release fixes a problem, use it: the binding accepts any version from 0.12.0 on.

## Deploying

Put the DLLs next to your executable (or next to the package or DLL the binding is linked into), with libjxl's
licences. The binding loads them only from the executable's folder or the folder of the module that contains the
binding, never from the current directory or `PATH`. Call `JxlCheckLibrary` (or test `JxlLibraryAvailable`) at
start-up to report a missing or wrong DLL clearly; the imports are delay-loaded, so the program still starts without
them.

## Safe loading

- Every function is `cdecl` and `delayed` (delay-loaded), so the program starts without the DLLs. **Call
  `JxlCheckLibrary` before the first direct call into a `Jxl.Api.*` unit** (the routines of `Jxl.Graphic` call it
  themselves): an import the delay loader cannot resolve ends a Win64 process with no exception to catch.
- `JxlCheckLibrary` loads `jxl.dll` only from the folder of the module that contains the binding or the executable's
  folder (`JxlLibraryDirectories`), with its dependencies searched in its own folder and System32; verifies with
  `GetProcAddress` that it exports every imported function; requires libjxl 0.12.0 or later (`JXL_MIN_VERSION`); then
  loads and verifies `jxl_threads.dll` and `jxl_cms.dll` the same way when `jxl.dll` does not export their functions
  itself. Each verified module is pinned, and a delay-load hook hands the delay loader exactly the module verified for
  each DLL name, so no import is ever resolved by a plain `LoadLibrary` search. `JxlLibraryLayout` reports how the
  functions are spread over DLLs, and `JxlCheckLibraryFolder` runs the same checks on any folder without binding to it
  (for diagnostics).
- It raises `EJxlError` naming the missing DLL, the missing functions or the version found; `JxlLibraryAvailable`
  returns the same verdict as a Boolean. Success is cached (thread-safe); a failure is not, so DLLs deployed later
  are found.

## The import units

The `Jxl.Api.*` units mirror the libjxl 0.12.0 C headers name for name, so a header change maps line for line:
functions keep their C names (`JxlDecoderCreate`), records keep their C names (`JxlBasicInfo`) with a Pascal alias
(`TJxlBasicInfo`) and pointer type (`PJxlBasicInfo`), and enumerations keep their C names and explicit C values. C
parameters named `type` or `label` become `type_` / `label_`.

- Each import unit lists its functions in an export table (`JXL_DECODE_EXPORTS`, `JXL_ENCODE_EXPORTS`,
  `JXL_THREADS_EXPORTS`, `JXL_CMS_EXPORTS`, `JXL_STATS_EXPORTS`) built with `NameOf` from the declarations; a test
  parses the sources and fails when a table and its unit's imports differ. `JxlFindMissingExports` and
  `JxlCheckVersion` are the two checks, exposed for testing.
- `TJxlMemoryBudget` (Pascal only) is a `JxlMemoryManager` that counts libjxl's allocations and refuses those over a
  limit, so a decoder or encoder fails cleanly instead of exhausting the process.
- Records use C natural alignment (`{$ALIGN 8}`) and enumerations are 4 bytes (`{$MINENUMSIZE 4}`). The tests assert
  the size of every record, and the offset of the fields that move between Win32 and Win64, against values measured
  from the C headers with MSVC.
- Structures passed by value in C (`JxlCmsInterface`, `JxlEncoderOutputProcessor`, `JxlChunkedFrameInputSource`)
  are passed by value in Pascal.
- `JXL_BOOL` is `Integer`; use `JXL_TRUE` / `JXL_FALSE`.

**API coverage.** All 115 functions exported by libjxl's DLLs are bound: 52 from `decode.h`, 49 from
`encode.h`, 4 from `stats.h`, 9 from the two thread-runner headers and 1 from `cms.h`. Not bound, deliberately:
`JxlGainMapGetBundleSize`, `JxlGainMapWriteBundle`, `JxlGainMapReadBundle` (`gain_map.h`) and `JxlICCProfileEncode`,
`JxlICCProfileDecode` (`compressed_icc.h`). The headers mark them `JXL_EXPORT`, but their code is built into the
internal `jxl_extras` library, not into the DLLs, so no libjxl DLL exports them. The C++ headers (`*_cxx.h`) have
no C ABI and are not bound. Encoder options added to libjxl after 0.12.0 are added here when a libjxl release includes
them.

## Using the VCL unit

```pascal
uses
  Jxl.Graphic;

// TJxlImage is registered with TPicture for .jxl:
Image1.Picture.LoadFromFile( 'photo.jxl' );

// One-call routines:
JxlDecodeFileToBitmap( 'photo.jxl', Bitmap );
JxlEncodeBitmapToFile( Bitmap, 'copy.jxl', TJxlEncodeOptions.Default );   // lossy, distance 1.0, effort 7

// Lossless JPEG recompression (typically about 20% smaller) and byte-exact reconstruction:
JxlTranscodeJpegFileToJxl( 'photo.jpg', 'photo.jxl' );
JxlReconstructJpegFile( 'photo.jxl', 'restored.jpg' );
```

- Decoding produces 8-bit sRGB by default (libjxl's colour management converts images stored in another profile);
  `JxlDecodePixels( Data, jcoImageProfile )` keeps the image's own profile and returns its ICC profile in
  `TJxlPixels.IccProfile`. The first frame of an animation is returned, in display orientation (the file's
  orientation is applied). A greyscale image is expanded to RGB with `jcoSrgb` (and then carries no ICC profile, since
  libjxl's would be grey) and stays 1 or 2 channels with `jcoImageProfile`. A CMYK image decoded with
  `jcoImageProfile` gives its colour channels without black and a CMYK profile, which cannot be encoded again; decode
  CMYK with `jcoSrgb`.
- Encoding stores `TJxlPixels.IccProfile` when it is set (its colour space must match the channel count) and declares
  sRGB otherwise, so pixels decoded with `jcoImageProfile` round-trip with their profile.
- A decoded image with alpha becomes a 32-bit bitmap with `AlphaFormat = afDefined`; an opaque one `afIgnored`.
- **Exact alpha.** A VCL bitmap holds alpha premultiplied, so saving a `TBitmap` or `TJxlImage` stores premultiplied
  samples and a lossless save is not sample-exact where pixels are partly transparent. For a sample-exact save,
  encode the original straight pixels: `JxlTryPngToPixels` (an 8-bit grey/RGB(A) `TPngImage`) or
  `JxlDecodePixels`, then `JxlEncodePixels` / `JxlEncodePixelsToFile`.
- `JxlReadInfo` (bytes, stream or file name) returns a `TJxlInfo` with the image's size, bit depths, alpha,
  colour encoding, orientation, frame count, animation timing and whether it holds JPEG reconstruction data, without
  decoding pixels. The colour encoding is the image's original one: `ColourSpace` (RGB, grey, XYB or unknown),
  `HasIccProfile` and `IccProfileSize` when the file describes its colour with an ICC profile, otherwise the
  structured profile in `ColourEncoding`; `IsSrgb` is `True` only for an encoded profile with sRGB primaries (RGB),
  D65 white point and the sRGB transfer function, any rendering intent, so decoding to 8-bit sRGB converts nothing.
  Every ICC profile, an sRGB one included, and sRGB primaries with another transfer curve (the conformance `bike`
  uses BT.709's), are not `IsSrgb`. Width, height and orientation are as stored; `DisplayWidth` / `DisplayHeight`
  give the size as displayed (swapped for orientations 5 to 8). For a container file it also checks every box's
  declared size against the data, so a truncated container raises `EJxlError`; a bare codestream cut inside its pixel
  data is not detected this way.
- `JxlValidate` (same overloads) checks a file completely: it decodes every frame, discarding the pixels
  through an image-out callback (no image buffer), and raises `EJxlError` on any fault. It costs about as much
  as a decode.
- Encoding: set `Lossless`, `Distance` (lossy quality; 1.0 is visually lossless, 0 or less means lossless, at most 25)
  and `Effort` (1-10) on `TJxlImage`, or pass a `TJxlEncodeOptions` record. A NaN or out-of-range distance or effort
  raises `EArgumentException` before libjxl is called.
- Every failure raises `EJxlError`. When a C function failed, `ApiName` and `Status` name it and the status it
  returned; when the binding found the fault itself (a resource limit, empty or malformed input, an exception escaping
  from libjxl), `IsBindingCheck` is `True` and `ApiName` names the Pascal routine. Floating-point exceptions (x87 and
  SSE) are masked during libjxl calls.
- Decoding and encoding run on libjxl's resizable thread pool, created per call: creating a 12-thread pool costs
  about 0.9 ms, under 3% of even a small decode, and caching one per thread would leak it and its threads for every
  thread that ever decoded, so it is not cached. `JxlDecodeToBitmap` and `TJxlImage` decode straight into the
  bitmap's memory (about 15% faster than through `TJxlPixels` on an 11-megapixel image).

## Cancellation

The long routines (decoding to pixels or a bitmap, encoding pixels or a bitmap, to memory or a file, JPEG
recompression and reconstruction, `JxlValidate`) take an optional `TJxlCancellation` as their last parameter, and
`TJxlImage.Cancellation` covers loading and saving. Call `Cancel` from any thread and the routine raises
`EJxlCancelled` (an `EJxlError` binding check whose message ends in "the operation was cancelled"; catch it first to
tell a cancellation from a failure). libjxl calls cannot be interrupted, but their heavy work runs through the
parallel runner, and the binding's runner (`JxlCancellableParallelRunner`, also usable with the raw API through a
`TJxlCancellableRunner`) skips the remaining tasks and fails the call once the token is cancelled; the binding also
checks the token between its own steps. The decoder or encoder, the thread pool and the buffers are released as on
any failure, and a routine that writes a file writes nothing. Lossy encoding stops within about 50 ms, decoding
well before half its run; libjxl's lossless encoding at effort 9 spends most of its time outside the runner and
stops only after about 60% of its run, and at effort 10 hardly before it ends. A token that is never cancelled
changes nothing: the output is byte-identical.

## Resource limits

Files from untrusted sources can ask for far more memory or time than an application expects. Every routine of
`Jxl.Graphic` validates its input against a `TJxlLimits` record, and refuses with an `EJxlError` binding check naming
the limit:

| Field | Checks | Win64 default | Win32 default |
|---|---|---|---|
| `MaxPixels` | width x height of an image or JPEG, from its header, before decoding | 256 Mi (16384 x 16384) | 32 Mi (8192 x 4096) |
| `MaxExtraChannels` | extra channels (alpha, black, spot colours, ...) | 16 | 16 |
| `MaxInputBytes` | input size, before a stream or file is read | 1 GiB | 256 MiB |
| `MaxOutputBytes` | growth of an encoded file or reconstructed JPEG | 1 GiB | 256 MiB |
| `MaxMemoryBytes` | libjxl's allocations, through a counting memory manager, per decoder or encoder; also a JPEG's DCT coefficient memory | 8 GiB | 1 GiB |
| `MaxJpegScans` | scans in a JPEG to be recompressed | 64 | 64 |

Measured through the memory manager, libjxl needs 8 to 34 bytes per pixel while decoding large images (plus about
10 MB), on top of the decoded pixels and the bitmap; the Win32 defaults keep a decode near the pixel limit within a
2 GiB address space, and an image there in a costly coding mode is refused by the memory limit rather than
exhausting the process. A JPEG is pre-checked before libjxl parses it: its marker structure must be sound and its
frame within the limits.

`JxlGetDefaultLimits` / `JxlSetDefaultLimits` read and replace the process-wide defaults (thread-safe); the routines
taking bytes have overloads with a `TJxlLimits` parameter, and `TJxlImage.Limits` holds an image's own (copied from
the defaults when it is created, so `TPicture` uses the defaults). Every field must be positive.

## Building and running the tests

1. Get libjxl's DLLs for the platform (above) and set **`LIBJXL_BIN`** to the folder holding them: the extracted
   release archive (its `x64-windows\bin` / `x86-windows\bin` is found), a vcpkg `installed\<triplet>` folder, a CMake
   build folder, or the folder holding `jxl.dll`. For both platforms at once, set `LIBJXL_BIN_WIN64` and
   `LIBJXL_BIN_WIN32` instead. Only DLLs built for the platform being built are taken.
2. Get the test data: a checkout of libjxl (`git clone https://github.com/libjxl/libjxl` and
   `git submodule update --init testdata`), with **`LIBJXL_TESTDATA`** set to its `testdata` folder. Optionally,
   clone [libjxl/conformance](https://github.com/libjxl/conformance) and set **`JXL_CONFORMANCE`** to its
   `testcases` folder. When this folder sits inside a libjxl checkout, both are also found by walking up from the test
   executable (`testdata\jxl`, `test-images\conformance\testcases`).
3. In Delphi 13, open `LibJxl.groupproj`, or build `Packages/LibJxl.dproj` (Win32 and Win64) and
   `Tests/LibJxlTests.dproj`. The test project's post-build step runs `CopyJxlDlls.ps1`, which copies the DLLs from
   `LIBJXL_BIN` next to the executable (with `-SourceDir` it can be run by hand), says which DLLs it copied and whether
   the Visual C++ runtime they need is installed, and reports, without failing the build, when it finds none.
4. Run `Tests/Win64/Release/LibJxlTests.exe` (or `Win32`). It writes `LibJxlTests-results.xml` (NUnit format) beside
   itself. Tests whose data is missing are reported as ignored, with a message naming the variable to set.

The suite (103 tests) covers record layouts and every enumerator value against the C headers, the library checks
(safe loading, export tables, version, both DLL layouts through `JxlCheckLibraryFolder`), the memory budget and every
resource limit, the JPEG pre-check, decoding against reference PNGs, lossless and lossy encoding, lossless JPEG
recompression with byte-exact reconstruction, `TPicture` integration, corrupt input, the colour encoding
`JxlReadInfo` reports, and cancellation (before the call, from another thread during an encode, a decode and a
validation, the runner's contract with libjxl, and that an encoder cancelled mid-way releases every byte of its
memory budget). A cross-check fixture decodes the same files through the binding and through Windows' own JPEG XL
codec (WIC, from Microsoft's JPEG XL Image Extension) and compares the pixels; without a WIC JPEG XL decoder those
tests are reported as ignored. An optional fixture runs a selection of libjxl's conformance cases (alpha, animation,
CMYK, JPEG reconstruction, progressive, greyscale, 32-bit float, a large VarDCT photo).

## The demo: JxlViewer

`Demos/JxlViewer` is a small VCL application that exercises the binding end to end. Build
`Demos/JxlViewer/JxlViewer.dproj` (its post-build step runs `CopyJxlDlls.ps1`, like the tests) and run
`Demos/JxlViewer/Win64/Release/JxlViewer.exe`, optionally with an image path as its argument.

- **Open** any image `TPicture` reads (JPEG XL through `TJxlImage`, plus PNG, JPEG, BMP, GIF, icons and EMF/WMF),
  shown upright, fitted to the window or at full size, over a chequerboard where it is transparent.
- **Image details:** displayed dimensions, file size and load time, and for JPEG XL the basic information read with
  `JxlReadInfo` without decoding the pixels.
- **Save as JXL** with the Lossless, Distance and Effort settings, reporting the size, the ratio, the bits per pixel,
  the encoding time and whether the route is exact or what it loses.
- **JPEG -> JXL** (lossless recompression) and **JXL -> JPEG** (reconstruction), reporting the sizes and whether the
  reconstructed file is byte-identical to the original JPEG when that is known.
- Every file it writes is checked with `JxlValidate`; **Validate** and **Validate file...** check files on demand.
- Long operations run on a worker thread and can be stopped with **Cancel** (or Esc); nothing is written for a
  cancelled save.
- At start-up it calls `JxlCheckLibrary`, explains missing DLLs (viewing other formats still works) and logs the
  active resource limits.

## Licences

The binding is Copyright (c) 2026 Ian Branch and licensed under the BSD 3-Clause licence in `LICENSE`; every source
file carries that header.

It is a separate work from libjxl and contains none of libjxl's code. The libjxl DLLs you obtain to use it are
licensed by the JPEG XL Project under the BSD 3-Clause licence, with an additional patent grant from Google; copies
of both, from libjxl v0.12.0, are in `third-party/libjxl/` (see `THIRD-PARTY-NOTICES.md`). Ship them, and the
licences in the `licenses` folder of libjxl's release archive, with the DLLs.

## Contributing and security

Issues and pull requests are welcome; see `CONTRIBUTING.md`. Please report security problems privately as described
in `SECURITY.md`.

## How this binding was developed

This binding was developed with substantial assistance from an AI coding assistant (Anthropic's Claude), under the
maintainer's direction and review. It is tested as described above.
