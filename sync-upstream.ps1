<#
.SYNOPSIS
  Sync D:\Projects\pstack with upstream (backnotprop/pstack) and push to your origin fork.
#>
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$dirty = git status --porcelain
if ($dirty) {
  throw "Working tree has uncommitted changes. Commit or stash them before syncing."
}

Write-Host "==> Fetching upstream..." -ForegroundColor Cyan
git fetch upstream

Write-Host "==> Rebasing local commits onto upstream/main..." -ForegroundColor Cyan
git rebase upstream/main

Write-Host "==> Pushing to origin/main..." -ForegroundColor Cyan
git push --force-with-lease origin main

Write-Host "==> Done! Synced with upstream/main." -ForegroundColor Green
