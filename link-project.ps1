<#
.SYNOPSIS
  Copy pstack skills into a specific project directory.

.DESCRIPTION
  Copies skills to <Target>\.agents\skills. Refreshes pstack copies and replaces
  legacy pstack links. Use -Unlink to remove pstack copies and legacy links.
  Project-owned skills are preserved.

.EXAMPLE
  .\link-project.ps1 -Target D:\Projects\my-app
  .\link-project.ps1 -Target D:\Projects\my-app -Only architect,blast-radius,interrogate
  .\link-project.ps1 -Target D:\Projects\my-app -Unlink
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Target,

  [string[]]$Only = @(),

  [switch]$Unlink
)

$ErrorActionPreference = "Stop"
$pstackSkills = Join-Path $PSScriptRoot "skills"

if (-not (Test-Path $pstackSkills)) {
  throw "pstack skills directory not found: $pstackSkills"
}

$targetRoot = (Resolve-Path $Target -ErrorAction Stop).Path
$skills = Get-ChildItem -Directory $pstackSkills
if ($Only.Count -gt 0) {
  $wanted = @($Only | ForEach-Object { $_.Split(",") } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $skills = $skills | Where-Object { $wanted -contains $_.Name }
  $missing = $wanted | Where-Object { $n = $_; -not ($skills | Where-Object { $_.Name -eq $n }) }
  if ($missing.Count -gt 0) {
    throw "Unknown skill(s): $($missing -join ', ')"
  }
}

$agentsDir = Join-Path $targetRoot ".agents"
$destDir = Join-Path $agentsDir "skills"
$marker = ".pstack-installed"
foreach ($directory in @($agentsDir, $destDir)) {
  $item = Get-Item -LiteralPath $directory -Force -ErrorAction SilentlyContinue
  if ($item -and (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
    throw "Destination must be a real directory: $directory"
  }
}
if ($Unlink -and -not [IO.Directory]::Exists($destDir)) {
  Write-Host "$destDir => not found, skipped"
  return
}
[IO.Directory]::CreateDirectory($destDir) | Out-Null

function Test-PstackSkill($Entry) {
  if ($Entry.LinkType -in @("Junction", "SymbolicLink")) {
    return $Entry.Target -contains (Join-Path $pstackSkills $Entry.Name)
  }
  return $Entry.PSIsContainer -and
    -not ($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
    [IO.File]::Exists((Join-Path $Entry.FullName $marker))
}

$lockPath = Join-Path $agentsDir ".pstack-sync.lock"
[IO.File]::Open($lockPath, [IO.FileMode]::CreateNew).Dispose()
try {
  if ($Unlink) {
    $removed = 0
    foreach ($entry in (Get-ChildItem -LiteralPath $destDir -Force)) {
      if (Test-PstackSkill $entry) {
        [IO.Directory]::Delete($entry.FullName, $true)
        $removed++
      }
    }
    Write-Host "$destDir => removed $removed pstack skill(s)"
    return
  }

  $workDir = Join-Path $agentsDir (".pstack-sync." + [Guid]::NewGuid().ToString("N"))
  [IO.Directory]::CreateDirectory($workDir) | Out-Null
  $next = Join-Path $workDir "next"
  $previous = Join-Path $workDir "previous"
  $entryPath = $null
  try {
    $copied = 0
    $skipped = 0
    foreach ($skill in $skills) {
      $entryPath = Join-Path $destDir $skill.Name
      $entry = Get-Item -LiteralPath $entryPath -Force -ErrorAction SilentlyContinue
      if ($entry -and -not (Test-PstackSkill $entry)) {
        $skipped++
        continue
      }

      # Stage the complete copy before replacing the installed version.
      Copy-Item -LiteralPath $skill.FullName -Destination $next -Recurse -Force
      [IO.File]::WriteAllText((Join-Path $next $marker), "")
      if ($entry) {
        [IO.Directory]::Move($entryPath, $previous)
      }
      [IO.Directory]::Move($next, $entryPath)
      if ($entry) {
        [IO.Directory]::Delete($previous, $true)
      }
      $copied++
    }
    Write-Host "$destDir => copied $copied skill(s) (skipped $skipped project skill(s))"
  } finally {
    if ($entryPath -and (Get-Item -LiteralPath $previous -Force -ErrorAction SilentlyContinue) -and
        -not (Get-Item -LiteralPath $entryPath -Force -ErrorAction SilentlyContinue)) {
      [IO.Directory]::Move($previous, $entryPath)
    }
    [IO.Directory]::Delete($workDir, $true)
  }
} finally {
  [IO.File]::Delete($lockPath)
}
