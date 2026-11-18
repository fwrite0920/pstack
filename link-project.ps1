<#
.SYNOPSIS
  Link (or unlink) pstack skills into a specific project directory.

.DESCRIPTION
  Creates directory junctions from D:\Projects\pstack\skills\<skill> into
  <Target>\.agents\skills (used by Antigravity, Codex, OMP, OpenCode) and
  <Target>\.pi\skills (used by Pi). Existing skills in the target project
  are never overwritten. Directory junctions work in both Windows and WSL2.

.EXAMPLE
  .\link-project.ps1 -Target D:\Projects\my-app
  .\link-project.ps1 -Target D:\Projects\my-app -Only architect,blast-radius,interrogate
  .\link-project.ps1 -Target D:\Projects\my-app -Unlink
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Target,

  [string[]]$Tools = @(".agents/skills", ".pi/skills"),

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

foreach ($rel in $Tools) {
  $destDir = Join-Path $targetRoot $rel
  if ($Unlink) {
    if (-not (Test-Path $destDir)) {
      Write-Host "$destDir => not found, skipped"
      continue
    }
    $removed = 0
    Get-ChildItem $destDir -Force | ForEach-Object {
      $isLink = ($_.LinkType -eq "Junction" -or $_.LinkType -eq "SymbolicLink")
      $pointsToPstack = $_.Target -and ($_.Target | Where-Object { $_ -like "$pstackSkills*" })
      if ($isLink -and $pointsToPstack) {
        [System.IO.Directory]::Delete($_.FullName)
        $removed++
      }
    }
    Write-Host "$destDir => unlinked $removed pstack skill(s)"
  } else {
    if (-not (Test-Path $destDir)) {
      New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    $added = 0
    $skipped = 0
    foreach ($s in $skills) {
      $linkPath = Join-Path $destDir $s.Name
      if (Test-Path $linkPath) {
        $skipped++
        continue
      }
      New-Item -ItemType Junction -Path $linkPath -Target $s.FullName | Out-Null
      $added++
    }
    Write-Host "$destDir => linked $added skill(s) (skipped $skipped existing)"
  }
}
