# Copyright (c) 2026 Ian Branch. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

<#
.SYNOPSIS
  Copies the libjxl run-time DLLs next to a Delphi executable.

.DESCRIPTION
  The test runner (Tests\LibJxlTests.dproj) and the demo (Demos\JxlViewer\JxlViewer.dproj) run this as a post-build
  event. Either layout of libjxl's Windows DLLs is copied, whichever is found; the binding detects it at run time:
  - a single self-contained jxl.dll;
  - upstream's shared build: jxl.dll, jxl_threads.dll, jxl_cms.dll and the DLLs they need (Brotli, and for a vcpkg
    build its other dependencies), found by reading each DLL's import table.

  Where the DLLs are looked for, first match wins:
  1. -SourceDir;
  2. the LIBJXL_BIN_WIN64 / LIBJXL_BIN_WIN32 environment variable for the platform being built;
  3. the LIBJXL_BIN environment variable.
  Each of these may name the folder holding jxl.dll, a folder with a Win64 / Win32 subfolder holding it, a CMake build
  tree (lib\Release, with the Brotli DLLs in third_party\brotli\Release), a vcpkg installed tree (bin), or an
  extracted official release archive (jxl-x64-windows.zip / jxl-x86-windows.zip: x64-windows\bin / x86-windows\bin).
  MinGW / MSYS2 names (libjxl.dll, libjxl_threads.dll, libjxl_cms.dll) are accepted too.
  4. When none is set and this folder sits inside a libjxl checkout: the checkout's build* folders, first a Win64 /
     Win32 subfolder or the folder itself, then CMake build trees.
  Only a jxl.dll built for the platform (x64 or x86) is accepted.

  A DLL already next to the executable is compared with its source by SHA-256: an identical one is left alone, a
  different one is replaced and reported as stale, and every copy is checked against its source afterwards. The names
  copied are recorded in CopyJxlDlls.txt in the output folder, and a DLL an earlier run copied that the current layout
  does not use is deleted, so switching layouts leaves no stale DLL behind.

  Outcomes:
  - No libjxl DLLs found: reported, not an error, so the Delphi build still succeeds; the executable then cannot use
    libjxl until they are copied.
  - A copy that fails (typically the executable is still running and holds the DLL) or does not match its source:
    the script exits non-zero and the Delphi build FAILS. This is deliberate: an executable silently running against
    a stale libjxl is worse than a failed build.

.PARAMETER Platform
  Delphi platform name: Win64 or Win32.

.PARAMETER OutputDir
  Folder the executable is built into.

.PARAMETER SourceDir
  Folder holding the libjxl DLLs (see the search order above). Optional.
#>
param(
  [Parameter( Mandatory = $true )] [ValidateSet( 'Win64', 'Win32' )] [string] $Platform,
  [Parameter( Mandatory = $true )] [string] $OutputDir,
  [string] $SourceDir = ''
)

$ErrorActionPreference = 'Stop'

$machine = $( if ( $Platform -eq 'Win64' ) { 0x8664 } else { 0x014C } )
$releaseBin = $( if ( $Platform -eq 'Win64' ) { 'x64-windows\bin' } else { 'x86-windows\bin' } )
$manifestName = 'CopyJxlDlls.txt'

# Reads a PE image's machine type and the names of the DLLs it imports. Returns $null for a file that is not a
# readable PE image.
function Read-PeImage( [string] $File ) {
  try {
    $bytes = [IO.File]::ReadAllBytes( $File )
    $pe = [BitConverter]::ToInt32( $bytes, 0x3C )

    if ( [BitConverter]::ToUInt32( $bytes, $pe ) -ne 0x4550 ) { return $null }

    $fileMachine = [BitConverter]::ToUInt16( $bytes, $pe + 4 )
    $sectionCount = [BitConverter]::ToUInt16( $bytes, $pe + 6 )
    $optionalSize = [BitConverter]::ToUInt16( $bytes, $pe + 20 )
    $optional = $pe + 24
    $magic = [BitConverter]::ToUInt16( $bytes, $optional )
    $directories = $optional + $( if ( $magic -eq 0x20B ) { 112 } else { 96 } )
    $importRva = [BitConverter]::ToUInt32( $bytes, $directories + 8 )
    $sections = $optional + $optionalSize

    $toOffset = {
      param( [uint32] $Rva )

      for ( $i = 0; $i -lt $sectionCount; $i++ ) {
        $header = $sections + $i * 40
        $virtualSize = [BitConverter]::ToUInt32( $bytes, $header + 8 )
        $virtualAddress = [BitConverter]::ToUInt32( $bytes, $header + 12 )
        $rawSize = [BitConverter]::ToUInt32( $bytes, $header + 16 )
        $rawOffset = [BitConverter]::ToUInt32( $bytes, $header + 20 )

        if ( ( $Rva -ge $virtualAddress ) -and ( $Rva -lt $virtualAddress + [Math]::Max( $virtualSize, $rawSize ) ) ) {
          return [int]( $Rva - $virtualAddress + $rawOffset )
        }
      }

      return -1
    }

    $imports = @()

    if ( $importRva -ne 0 ) {
      $descriptor = & $toOffset $importRva

      while ( $descriptor -ge 0 ) {
        $nameRva = [BitConverter]::ToUInt32( $bytes, $descriptor + 12 )

        if ( $nameRva -eq 0 ) { break }

        $nameOffset = & $toOffset $nameRva
        $end = [Array]::IndexOf( $bytes, [byte]0, $nameOffset )
        $imports += [Text.Encoding]::ASCII.GetString( $bytes, $nameOffset, $end - $nameOffset )
        $descriptor += 20
      }
    }

    return [pscustomobject]@{ Machine = $fileMachine; Imports = $imports }
  } catch {
    return $null
  }
}

# The folders a root names, in the order they are tried.
function Get-ProbeFolders( [string] $Root ) {
  return @(
    ( Join-Path $Root $Platform ),
    $Root,
    ( Join-Path $Root 'lib\Release' ),
    ( Join-Path $Root 'bin' ),
    ( Join-Path $Root $releaseBin )
  )
}

# The main DLL in a folder: jxl.dll, or libjxl.dll as MinGW / MSYS2 builds name it; $null when neither exists.
function Get-MainLibrary( [string] $Folder ) {
  foreach ( $name in @( 'jxl.dll', 'libjxl.dll' ) ) {
    $file = Join-Path $Folder $name

    if ( Test-Path -LiteralPath $file -PathType Leaf ) { return $file }
  }

  return $null
}

# The first folder holding a jxl.dll for this platform, or $null.
function Find-LibraryFolder( [string[]] $Folders ) {
  foreach ( $folder in $Folders ) {
    $candidate = Get-MainLibrary $folder

    if ( -not $candidate ) { continue }

    $image = Read-PeImage $candidate

    if ( $image -and ( $image.Machine -eq $machine ) ) { return ( Resolve-Path -LiteralPath $folder ).Path }

    Write-Host "CopyJxlDlls: skipping '$candidate': not built for $Platform."
  }

  return $null
}

$roots = @()

if ( $SourceDir -ne '' ) {
  $roots += , @( 'the -SourceDir parameter', $SourceDir )
}

foreach ( $variable in @( "LIBJXL_BIN_$( $Platform.ToUpper() )", 'LIBJXL_BIN' ) ) {
  $value = [Environment]::GetEnvironmentVariable( $variable )

  if ( $value ) { $roots += , @( "the $variable environment variable", $value ) }
}

$libraryFolder = $null
$origin = ''

foreach ( $root in $roots ) {
  $libraryFolder = Find-LibraryFolder ( Get-ProbeFolders $root[ 1 ] )

  if ( $libraryFolder ) {
    $origin = $root[ 0 ]
    break
  }

  Write-Host "CopyJxlDlls: no $Platform jxl.dll under '$( $root[ 1 ] )' ($( $root[ 0 ] ))."
}

$checkout = Resolve-Path ( Join-Path $PSScriptRoot '..' )

if ( ( -not $libraryFolder ) -and ( $roots.Count -eq 0 ) -and ( Test-Path ( Join-Path $checkout 'lib\include\jxl' ) ) ) {
  $builds = @( Get-ChildItem -LiteralPath $checkout -Directory -Filter 'build*' | Sort-Object Name | ForEach-Object { $_.FullName } )
  $libraryFolder = Find-LibraryFolder ( @( $builds | ForEach-Object { Join-Path $_ $Platform; $_ } ) )

  if ( -not $libraryFolder ) {
    $libraryFolder = Find-LibraryFolder ( @( $builds | ForEach-Object { Join-Path $_ 'lib\Release' } ) )
  }

  $origin = "the build folders of '$checkout'"
}

if ( -not $libraryFolder ) {
  Write-Host "CopyJxlDlls: no libjxl DLLs for $Platform found; the executable cannot use libjxl until they are copied next to it."
  Write-Host "  Build libjxl (see README.md) and set LIBJXL_BIN (or LIBJXL_BIN_$( $Platform.ToUpper() )) to the folder holding jxl.dll."

  if ( Test-Path -LiteralPath ( Join-Path $OutputDir 'jxl.dll' ) ) {
    Write-Host "  '$OutputDir' still holds a jxl.dll from an earlier copy, which could not be checked and may be stale."
  }

  exit 0
}

# Folders a dependency may come from: jxl.dll's own, and in a CMake build tree the third-party Release folders.
$searchFolders = @( $libraryFolder )

if ( ( Split-Path $libraryFolder -Leaf ) -eq 'Release' ) {
  $buildTree = Split-Path ( Split-Path $libraryFolder -Parent ) -Parent
  $thirdParty = Join-Path $buildTree 'third_party'

  if ( Test-Path -LiteralPath $thirdParty ) {
    $searchFolders += @( Get-ChildItem -LiteralPath $thirdParty -Directory -Recurse -Filter 'Release' | ForEach-Object { $_.FullName } )
  }
}

# jxl.dll, the split build's two companions when present, and every DLL they import that the search folders hold.
$queue = New-Object System.Collections.Generic.Queue[string]
$sources = [ordered]@{}
$systemImports = @{}

foreach ( $name in @( 'jxl.dll', 'jxl_threads.dll', 'jxl_cms.dll', 'libjxl.dll', 'libjxl_threads.dll', 'libjxl_cms.dll' ) ) {
  $file = Join-Path $libraryFolder $name

  if ( Test-Path -LiteralPath $file -PathType Leaf ) { $queue.Enqueue( $file ) }
}

while ( $queue.Count -gt 0 ) {
  $file = $queue.Dequeue()
  $key = ( Split-Path $file -Leaf ).ToLowerInvariant()

  if ( $sources.Contains( $key ) ) { continue }

  $sources[ $key ] = $file
  $image = Read-PeImage $file

  if ( -not $image ) { continue }

  foreach ( $import in $image.Imports ) {
    $found = $searchFolders | ForEach-Object { Join-Path $_ $import } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
      Select-Object -First 1

    if ( $found ) { $queue.Enqueue( $found ) } else { $systemImports[ $import.ToLowerInvariant() ] = $true }
  }
}

$layout = $( if ( $sources.Contains( 'jxl_threads.dll' ) -or $sources.Contains( 'libjxl_threads.dll' ) ) { 'split (shared) build' } else { 'single DLL' } )

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# .NET rather than Get-FileHash, which does not load in Windows PowerShell started from PowerShell 7 (inherited
# PSModulePath).
function Get-Sha256( [string] $File ) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::Open( $File, 'Open', 'Read', 'ReadWrite, Delete' )

  try {
    return ( [BitConverter]::ToString( $sha.ComputeHash( $stream ) ) -replace '-', '' )
  } finally {
    $stream.Dispose()
    $sha.Dispose()
  }
}

# DLLs an earlier run copied that this layout does not use (e.g. the split build's after switching to a single DLL).
$manifest = Join-Path $OutputDir $manifestName

if ( Test-Path -LiteralPath $manifest ) {
  foreach ( $previous in ( Get-Content -LiteralPath $manifest ) ) {
    if ( ( $previous -eq '' ) -or $sources.Contains( $previous.ToLowerInvariant() ) ) { continue }

    $stale = Join-Path $OutputDir $previous

    if ( Test-Path -LiteralPath $stale ) {
      try {
        Remove-Item -LiteralPath $stale -Force
        Write-Host "CopyJxlDlls: removed '$stale', copied by an earlier run and not part of this layout."
      } catch {
        Write-Host "CopyJxlDlls: WARNING: could not remove the stale '$stale': $( $_.Exception.Message )"
      }
    }
  }
}

$copied = 0
$current = 0

foreach ( $source in $sources.Values ) {
  $target = Join-Path $OutputDir ( Split-Path $source -Leaf )
  $sourceHash = Get-Sha256 $source

  if ( Test-Path -LiteralPath $target ) {
    if ( ( Get-Sha256 $target ) -eq $sourceHash ) {
      $current++
      continue
    }

    Write-Host "CopyJxlDlls: '$target' differs from '$source' (stale); replacing it."
  }

  # Throws (and so fails the build) when the target is locked by a running executable.
  Copy-Item -LiteralPath $source -Destination $target -Force

  if ( ( Get-Sha256 $target ) -ne $sourceHash ) {
    Write-Host "CopyJxlDlls: ERROR: '$target' does not match '$source' after the copy."
    exit 1
  }

  $copied++
}

Set-Content -LiteralPath $manifest -Value @( $sources.Values | ForEach-Object { Split-Path $_ -Leaf } ) -Encoding ascii

$version = ( Get-Item -LiteralPath ( Get-MainLibrary $libraryFolder ) ).VersionInfo.FileVersion

if ( -not $version ) { $version = 'without a version resource' }

Write-Host "CopyJxlDlls: $layout, $copied DLL(s) copied, $current already current, from '$libraryFolder' ($origin) to '$OutputDir' (jxl.dll $version)."

# A default CMake or vcpkg build links the Visual C++ runtime dynamically; say whether this machine has it.
$runtime = @( $systemImports.Keys | Where-Object { $_ -match '^(vcruntime|msvcp)\d+' } )

if ( $runtime.Count -gt 0 ) {
  $systemFolder = Join-Path $env:SystemRoot $( if ( ( $Platform -eq 'Win32' ) -and [Environment]::Is64BitOperatingSystem ) { 'SysWOW64' } else { 'System32' } )
  $absent = @( $runtime | Where-Object { -not ( Test-Path -LiteralPath ( Join-Path $systemFolder $_ ) ) } )

  if ( $absent.Count -gt 0 ) {
    Write-Host "CopyJxlDlls: WARNING: the DLLs need the Visual C++ runtime ($( $absent -join ', ' )), which is not installed for $Platform; install the Visual C++ Redistributable or ship those DLLs."
  } else {
    Write-Host "CopyJxlDlls: the DLLs need the Visual C++ runtime ($( $runtime -join ', ' )); it is installed here, and must be on the target machine too."
  }
}
