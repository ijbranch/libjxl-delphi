# Copyright (c) 2026 Ian Branch. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

<#
.SYNOPSIS
  Builds libjxl as one self-contained jxl.dll for Windows, from an unmodified libjxl release.

.DESCRIPTION
  Clones libjxl at a release tag (only the Brotli, Highway and skcms submodules the library needs), builds
  jxl, jxl_cms and jxl_threads as static libraries with the C runtime linked in (/MT), and links them into one
  jxl.dll through jxl_dll.cmake, which is injected into libjxl's CMake project from outside (no libjxl file is
  edited). The DLL imports only KERNEL32.dll, exports every function of libjxl's shared jxl.dll, jxl_cms.dll and
  jxl_threads.dll, and needs no Visual C++ redistributable. The binding detects this layout at run time.

  The result is checked before anything is packaged: machine type, the hardening flags (Dynamic base, NX, Control
  Flow Guard; on x64 also high-entropy ASLR and CET), imports (KERNEL32.dll only) and exports (exactly the list
  generated from libjxl's public headers). Then it writes, under <WorkDir>\dist:
    libjxl-<version>-single-dll-<x64|x86>.zip          jxl.dll, the licences, BUILD-INFO.txt, SHA256SUMS.txt
    libjxl-<version>-single-dll-<x64|x86>-pdb.zip      jxl.pdb, for symbolising crash dumps

  Needs git, and Visual Studio 2022 or 2026 (or its Build Tools) with the "Desktop development with C++" workload
  and both clang components: "C++ Clang Compiler for Windows" and "MSBuild support for LLVM (clang-cl) toolset".
  The CMake bundled with Visual Studio is used. Runs in Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER Arch
  Win64 (x64, the default) or Win32 (x86).

.PARAMETER Ref
  The libjxl tag to build. Default: v0.12.0.

.PARAMETER Source
  The libjxl repository to clone. Default: https://github.com/libjxl/libjxl.git.

.PARAMETER WorkDir
  Where the source, the build folders and dist\ go. Default: libjxl-single-dll in the current folder (not under
  %TEMP%, where MSBuild warns about build folders). A source clone already there is reused only when it is clean and
  at -Ref.

.EXAMPLE
  .\Build-JxlDll.ps1
  .\Build-JxlDll.ps1 -Arch Win32 -WorkDir C:\Build\jxl
#>
param(
  [ValidateSet( 'Win64', 'Win32' )] [string] $Arch = 'Win64',
  [string] $Ref = 'v0.12.0',
  [string] $Source = 'https://github.com/libjxl/libjxl.git',
  [string] $WorkDir = ( Join-Path ( Get-Location ).Path 'libjxl-single-dll' )
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$Submodules = @( 'third_party/brotli', 'third_party/highway', 'third_party/skcms' )
$CMakeArch = $( if ( $Arch -eq 'Win64' ) { 'x64' } else { 'Win32' } )
$ZipArch = $( if ( $Arch -eq 'Win64' ) { 'x64' } else { 'x86' } )
$SourceDir = Join-Path $WorkDir 'libjxl'
$BuildDir = Join-Path $WorkDir "build-$Arch"
$DistDir = Join-Path $WorkDir 'dist'

function Fail( [string] $Message ) {
  Write-Host "ERROR: $Message"
  exit 1
}

# Runs a native program; its output goes to $Log when given, and a non-zero exit code stops the script.
function Invoke-Native( [string] $Program, [string[]] $Arguments, [string] $Log = '' ) {
  # Native programs write progress to stderr; under 'Stop' Windows PowerShell would turn that into an error.
  $ErrorActionPreference = 'Continue'
  if ( $Log -ne '' ) {
    & $Program @Arguments > $Log 2>&1
  } else {
    & $Program @Arguments 2>&1 | ForEach-Object { Write-Host "  $_" }
  }
  if ( $LASTEXITCODE -ne 0 ) {
    $detail = $( if ( $Log -ne '' ) { ", see '$Log'" } else { '' } )
    Fail "$( Split-Path $Program -Leaf ) $( $Arguments[0] ) failed (exit code $LASTEXITCODE)$detail"
  }
}

# .NET rather than Get-FileHash: Windows PowerShell started from PowerShell 7 inherits a PSModulePath under which
# Get-FileHash does not always load.
function Get-Sha256( [string] $File ) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::OpenRead( $File )
  try {
    return ( [BitConverter]::ToString( $sha.ComputeHash( $stream ) ) -replace '-', '' ).ToLowerInvariant()
  } finally {
    $stream.Dispose()
    $sha.Dispose()
  }
}

function Find-VisualStudio {
  $vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if ( -not ( Test-Path -LiteralPath $vsWhere ) ) { Fail 'Visual Studio (vswhere.exe) not found' }
  $found = & $vsWhere -latest -products * -version '[17.0,19.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -requires Microsoft.VisualStudio.Component.VC.Llvm.Clang -requires Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset `
    -format json | ConvertFrom-Json
  if ( -not $found ) {
    Fail 'no Visual Studio 2022 or 2026 with the C++ workload and both clang components (see Get-Help .\Build-JxlDll.ps1)'
  }
  $vs = @( $found )[0]
  $major = [int]( $vs.installationVersion.Split( '.' )[0] )
  $generator = switch ( $major ) { 17 { 'Visual Studio 17 2022' } 18 { 'Visual Studio 18 2026' } }
  $cmake = Join-Path $vs.installationPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
  if ( -not ( Test-Path -LiteralPath $cmake ) ) { Fail "CMake not found in '$( $vs.installationPath )' (install the C++ CMake tools)" }
  $versionFile = Join-Path $vs.installationPath 'VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt'
  $toolsVersion = ( Get-Content -LiteralPath $versionFile | Select-Object -First 1 ).Trim()
  $dumpBin = Join-Path $vs.installationPath "VC\Tools\MSVC\$toolsVersion\bin\Hostx64\x64\dumpbin.exe"
  if ( -not ( Test-Path -LiteralPath $dumpBin ) ) { Fail "'$dumpBin' not found" }
  return [pscustomobject]@{
    Name      = "$( $vs.displayName ) $( $vs.installationVersion )"
    Generator = $generator
    CMake     = $cmake
    DumpBin   = $dumpBin
  }
}

# A fresh shallow clone at $Ref, or the one already in $SourceDir when it is clean and at $Ref.
function Get-Source {
  if ( Test-Path -LiteralPath $SourceDir ) {
    $head = ( & git -C $SourceDir rev-parse HEAD ).Trim()
    $wanted = ( & git -C $SourceDir rev-parse --verify --quiet "$Ref^{commit}" )
    $changes = ( & git -C $SourceDir status --porcelain --untracked-files=no )
    if ( ( -not $wanted ) -or ( $head -ne $wanted.Trim() ) -or $changes ) {
      Fail "'$SourceDir' is not a clean checkout of $Ref; delete it or choose another -WorkDir"
    }
    Write-Host "=== reusing the $Ref source in '$SourceDir'"
  } else {
    Write-Host "=== cloning $Source at $Ref"
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    Invoke-Native 'git' @( '-c', 'advice.detachedHead=false', 'clone', '--quiet', '--depth', '1', '--branch', $Ref, '--config', 'core.autocrlf=false',
      $Source, $SourceDir )
  }
  Write-Host "=== submodules: $( $Submodules -join ', ' )"
  Invoke-Native 'git' ( @( '-C', $SourceDir, 'submodule', 'update', '--init', '--depth', '1', '--' ) + $Submodules )
}

# Checks the linked DLL itself: what applications load is what counts.
function Test-Dll( [string] $DumpBin, [string] $Dll, [string] $ExportList ) {
  $expectedMachine = $( if ( $Arch -eq 'Win64' ) { '8664 machine (x64)' } else { '14C machine (x86)' } )
  $headers = & $DumpBin /nologo /headers $Dll
  if ( -not ( $headers -match [regex]::Escape( $expectedMachine ) ) ) { Fail "'$Dll' is not '$expectedMachine'" }
  $hardening = @( 'Dynamic base', 'NX compatible', 'Control Flow Guard' )
  if ( $Arch -eq 'Win64' ) { $hardening += @( 'High Entropy Virtual Addresses', 'CET compatible' ) }
  foreach ( $flag in $hardening ) {
    if ( -not ( $headers -match "^\s+$( [regex]::Escape( $flag ) )\s*$" ) ) { Fail "'$Dll' is not marked '$flag'" }
  }

  $imports = @( & $DumpBin /nologo /dependents $Dll | Where-Object { $_ -match '^\s+\S+\.dll\s*$' } |
    ForEach-Object { $_.Trim() } )
  if ( ( $imports.Count -ne 1 ) -or ( $imports[0] -ne 'KERNEL32.dll' ) ) {
    Fail "'$Dll' imports $( $imports -join ', ' ); only KERNEL32.dll is expected"
  }

  # "ordinal hint RVA name", plus " = <symbol>" when dumpbin finds the PDB.
  $actual = @( & $DumpBin /nologo /exports $Dll |
    Where-Object { $_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]{8}\s+(\S+)(\s+=\s+\S+)?\s*$' } |
    ForEach-Object { $Matches[1] } | Sort-Object )
  $expected = @( Get-Content -LiteralPath $ExportList | Where-Object { $_ -match '\S' } | Sort-Object )
  $difference = @( Compare-Object -ReferenceObject $expected -DifferenceObject $actual -CaseSensitive )
  if ( $difference.Count -gt 0 ) {
    $difference | ForEach-Object {
      Write-Host "  $( if ( $_.SideIndicator -eq '=>' ) { 'unexpected export' } else { 'missing export' } ): $( $_.InputObject )"
    }
    Fail "the exports of '$Dll' differ from the public headers"
  }
  Write-Host "=== verified: $expectedMachine; $( $hardening -join ', ' ); imports KERNEL32.dll only; $( $actual.Count ) exports"
  return $actual.Count
}

function New-Zip( [string] $Folder, [string] $Zip ) {
  if ( Test-Path -LiteralPath $Zip ) { Remove-Item -LiteralPath $Zip -Force }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::CreateFromDirectory( $Folder, $Zip, [IO.Compression.CompressionLevel]::Optimal, $true )
}

$vs = Find-VisualStudio
Write-Host "=== $( $vs.Name ); generator '$( $vs.Generator )', ClangCL, $CMakeArch"
Get-Source
$commit = ( & git -C $SourceDir rev-parse HEAD ).Trim()
$label = "$Ref, $( $commit.Substring( 0, 12 ) ), single-DLL build"

# A fresh build folder each time: a cache from another source or toolset would be silently reused.
if ( Test-Path -LiteralPath $BuildDir ) { Remove-Item -LiteralPath $BuildDir -Recurse -Force }
$configureLog = "$BuildDir-configure.log"
$buildLog = "$BuildDir-build.log"
Write-Host "=== configure (log: '$configureLog')"
Invoke-Native $vs.CMake @( '-S', $SourceDir, '-B', $BuildDir, '-G', $vs.Generator, '-A', $CMakeArch, '-T', 'ClangCL',
  "-DCMAKE_PROJECT_LIBJXL_INCLUDE=$( Join-Path $PSScriptRoot 'jxl_dll.cmake' )", "-DJXL_DLL_SOURCE_LABEL=$label",
  '-DJPEGXL_STATIC=ON', '-DBUILD_TESTING=OFF', '-DJPEGXL_ENABLE_TOOLS=OFF', '-DJPEGXL_ENABLE_EXAMPLES=OFF',
  '-DJPEGXL_ENABLE_BENCHMARK=OFF', '-DJPEGXL_ENABLE_DEVTOOLS=OFF', '-DJPEGXL_ENABLE_FUZZERS=OFF',
  '-DJPEGXL_ENABLE_JNI=OFF', '-DJPEGXL_ENABLE_SJPEG=OFF', '-DJPEGXL_ENABLE_OPENEXR=OFF', '-DJPEGXL_ENABLE_PLUGINS=OFF',
  '-DJPEGXL_ENABLE_TCMALLOC=OFF', '-DJPEGXL_ENABLE_VIEWERS=OFF', '-DJPEGXL_ENABLE_MANPAGES=OFF',
  '-DJPEGXL_ENABLE_DOXYGEN=OFF', '-DJPEGXL_ENABLE_SKCMS=ON' ) $configureLog
Write-Host "=== build (log: '$buildLog')"
Invoke-Native $vs.CMake @( '--build', $BuildDir, '--config', 'Release', '--parallel', '--target', 'jxl_dll' ) $buildLog
$warnings = @( Get-Content -LiteralPath $buildLog | Where-Object { $_ -match ': warning\s*:' } |
  ForEach-Object { $_ -replace '^\s*\d+>', '' } | Sort-Object -Unique )
Write-Host "=== $( $warnings.Count ) distinct compiler warning(s) in libjxl's code (listed in the build log)"

$dll = Join-Path $BuildDir 'Release\jxl.dll'
$exportCount = Test-Dll $vs.DumpBin $dll ( Join-Path $BuildDir 'jxl-exports.txt' )

# Package.
$version = ( Get-Item -LiteralPath $dll ).VersionInfo.ProductVersion -replace ' .*$', ''
$name = "libjxl-$version-single-dll-$ZipArch"
$stage = Join-Path $DistDir $name
$pdbStage = Join-Path $DistDir "$name-pdb"
foreach ( $folder in $stage, $pdbStage ) {
  if ( Test-Path -LiteralPath $folder ) { Remove-Item -LiteralPath $folder -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
}
Copy-Item -LiteralPath $dll -Destination $stage
Copy-Item -LiteralPath ( Join-Path $BuildDir 'Release\jxl.pdb' ) -Destination $pdbStage
$licences = [ordered]@{
  'LICENSE'                     = 'LICENSE.libjxl.txt'
  'PATENTS'                     = 'PATENTS.libjxl.txt'
  'third_party\brotli\LICENSE'  = 'LICENSE.brotli.txt'
  'third_party\highway\LICENSE' = 'LICENSE.highway.txt'
  'third_party\skcms\LICENSE'   = 'LICENSE.skcms.txt'
}
foreach ( $entry in $licences.GetEnumerator() ) {
  Copy-Item -LiteralPath ( Join-Path $SourceDir $entry.Key ) -Destination ( Join-Path $stage $entry.Value )
}

$dllHash = Get-Sha256 $dll
$compiler = ( Select-String -LiteralPath $configureLog -Pattern 'The CXX compiler identification is (.+)$' |
  Select-Object -First 1 ).Matches.Groups[1].Value
$info = @(
  "libjxl $version as one self-contained jxl.dll ($ZipArch)",
  '',
  "Source:      $Source",
  "Tag:         $Ref",
  "Commit:      $commit",
  "Submodules:  $( ( & git -C $SourceDir submodule status -- $Submodules | ForEach-Object { $_.Trim() } ) -join '; ' )",
  "Toolchain:   $( $vs.Name ), ClangCL ($compiler), $( $vs.Generator ), $CMakeArch",
  'Options:     JPEGXL_STATIC=ON (static libraries, static C runtime /MT), Release, Control Flow Guard,',
  '             CET-compatible on x64; jxl, jxl_cms and jxl_threads linked into one DLL by jxl_dll.cmake',
  "Imports:     KERNEL32.dll only",
  "Exports:     $exportCount (every function of libjxl's shared jxl.dll, jxl_cms.dll and jxl_threads.dll)",
  "jxl.dll:     SHA-256 $dllHash",
  "Built:       $( Get-Date -Format 'yyyy-MM-dd' ) by Build-JxlDll.ps1 (https://github.com/ijbranch/libjxl-delphi)",
  '',
  'The libjxl source is unmodified. The licences of libjxl and of the libraries linked into jxl.dll',
  '(Brotli, Highway, skcms) are in this folder.'
)
[IO.File]::WriteAllLines( ( Join-Path $stage 'BUILD-INFO.txt' ), [string[]] $info )
$sums = Get-ChildItem -LiteralPath $stage -File | Sort-Object Name |
  ForEach-Object { "$( Get-Sha256 $_.FullName )  $( $_.Name )" }
[IO.File]::WriteAllLines( ( Join-Path $stage 'SHA256SUMS.txt' ), [string[]] $sums )

$zip = Join-Path $DistDir "$name.zip"
$pdbZip = Join-Path $DistDir "$name-pdb.zip"
New-Zip $stage $zip
New-Zip $pdbStage $pdbZip
Write-Host "=== jxl.dll SHA-256 $dllHash"
Write-Host "=== $zip"
Write-Host "    SHA-256 $( Get-Sha256 $zip )"
Write-Host "=== $pdbZip"
Write-Host "    SHA-256 $( Get-Sha256 $pdbZip )"
exit 0
