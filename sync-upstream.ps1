<#
.SYNOPSIS
  Sync D:\Projects\pstack with upstream (backnotprop/pstack) and push to your origin fork.
#>
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Invoke-Git {
  param([string[]]$GitArgs)
  & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
}

$dirty = git status --porcelain
if ($dirty) {
  throw "Working tree has uncommitted changes. Commit or stash them before syncing."
}

Write-Host "==> Fetching upstream..." -ForegroundColor Cyan
Invoke-Git @("fetch", "upstream")

Write-Host "==> Rebasing local commits onto upstream/main..." -ForegroundColor Cyan
& git rebase upstream/main
if ($LASTEXITCODE -ne 0) {
  Write-Host "Rebase hit a conflict. Resolve conflicts, run 'git rebase --continue', then push." -ForegroundColor Yellow
  exit $LASTEXITCODE
}

Write-Host "==> Pushing to origin/main..." -ForegroundColor Cyan
Invoke-Git @("push", "--force-with-lease", "origin", "main")

Write-Host "==> Done! Synced with upstream/main." -ForegroundColor Green
