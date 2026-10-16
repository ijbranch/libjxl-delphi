# Third-party notices

This binding is a separate work. Its own licence is in `LICENSE` (BSD 3-Clause, Copyright (c) 2026 Ian Branch).

It contains no libjxl source code and no libjxl binaries: it calls libjxl's shared libraries (`jxl.dll`,
`jxl_threads.dll`, `jxl_cms.dll` and the Brotli DLLs they need), which you obtain separately (see README.md,
"Getting libjxl"). Those libraries are licensed by the JPEG XL Project:

| Component | Licence | Text |
|---|---|---|
| libjxl (the JPEG XL reference implementation) | BSD 3-Clause, Copyright (c) the JPEG XL Project Authors | `third-party/libjxl/LICENSE` |
| libjxl patent grant | Additional IP rights grant (patents) from Google | `third-party/libjxl/PATENTS` |

Both texts are copied unchanged from libjxl v0.12.0 (https://github.com/libjxl/libjxl/tree/v0.12.0). libjxl's
release archives also contain the licences of the libraries it is built with (Brotli, Highway, skcms and others) in
their `licenses` folder; ship those with the DLLs too.

The test suite reads libjxl's `testdata` and the JPEG XL conformance suite (https://github.com/libjxl/conformance)
from a local checkout; neither is included here.
