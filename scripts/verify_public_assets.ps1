Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'assets/screenshots/screenshot_manifest.json'
$pagePath = Join-Path $repoRoot 'privacy_policy.html'
$indexPath = Join-Path $repoRoot 'index.html'
$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $manifestPath)) {
    throw "Missing screenshot manifest: $manifestPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 -Path $manifestPath | ConvertFrom-Json
$pageHtml = Get-Content -Raw -Encoding UTF8 -Path $pagePath

Add-Type -AssemblyName System.Drawing

foreach ($item in $manifest.screenshots) {
    $assetPath = Join-Path $repoRoot $item.file
    if (-not (Test-Path $assetPath)) {
        $failures.Add("Missing screenshot file: $($item.file)")
        continue
    }

    $file = Get-Item $assetPath
    if ($file.Length -gt [int64]$item.maxBytes) {
        $failures.Add("Screenshot exceeds maxBytes: $($item.file) is $($file.Length), max $($item.maxBytes)")
    }

    $image = [System.Drawing.Image]::FromFile($assetPath)
    try {
        if ($image.Width -ne [int]$item.width -or $image.Height -ne [int]$item.height) {
            $failures.Add("Screenshot dimensions mismatch: $($item.file) is $($image.Width)x$($image.Height), expected $($item.width)x$($item.height)")
        }
    }
    finally {
        $image.Dispose()
    }

    $capturedAt = [DateTime]::ParseExact($item.capturedAt, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $ageDays = ([DateTime]::UtcNow.Date - $capturedAt.Date).Days
    if ($ageDays -gt [int]$manifest.freshnessDays) {
        $failures.Add("Screenshot is stale: $($item.file) captured $($item.capturedAt), freshnessDays $($manifest.freshnessDays)")
    }

    $srcPattern = [regex]::Escape($item.file)
    if ($pageHtml -notmatch $srcPattern) {
        $failures.Add("privacy_policy.html does not reference: $($item.file)")
    }

    $altPattern = '<img[^>]+src="' + [regex]::Escape($item.file) + '"[^>]+alt="' + [regex]::Escape($item.requiredAlt) + '"'
    if ($pageHtml -notmatch $altPattern) {
        $failures.Add("privacy_policy.html alt mismatch for: $($item.file)")
    }
}

$htmlFiles = @($pagePath, $indexPath)
foreach ($htmlFile in $htmlFiles) {
    $html = Get-Content -Raw -Encoding UTF8 -Path $htmlFile
    [regex]::Matches($html, '(?:src|href|content)="([^"]+)"') | ForEach-Object {
        $ref = $_.Groups[1].Value
        if ($ref -match '^(#|mailto:|https?:|summary_|website$|ja_JP$|0;|YACOS|[^/]+$)' -and $ref -notmatch 'assets/') {
            return
        }
        if ($ref -notmatch '^(assets/|privacy_policy\.html$)') {
            return
        }
        $targetPath = Join-Path (Split-Path $htmlFile) $ref
        if (-not (Test-Path $targetPath)) {
            $failures.Add("$([IO.Path]::GetFileName($htmlFile)) references missing local asset: $ref")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Public asset verification passed. $($manifest.screenshots.Count) screenshots are referenced, fresh, and within guardrails."
