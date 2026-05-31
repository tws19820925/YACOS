Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'assets/screenshots/screenshot_manifest.json'
$galleryManifestPath = Join-Path $repoRoot 'assets/ritual/gallery_manifest.json'
$pagePath = Join-Path $repoRoot 'privacy_policy.html'
$indexPath = Join-Path $repoRoot 'index.html'
$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $manifestPath)) {
    throw "Missing screenshot manifest: $manifestPath"
}

if (-not (Test-Path $galleryManifestPath)) {
    throw "Missing ritual gallery manifest: $galleryManifestPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 -Path $manifestPath | ConvertFrom-Json
$galleryManifest = Get-Content -Raw -Encoding UTF8 -Path $galleryManifestPath | ConvertFrom-Json
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

$galleryChecks = @(
    @{
        Name = 'tarot'
        ExpectedCount = 78
        ExpectedWidth = 360
        ExpectedHeight = 540
        Directory = 'assets/ritual/tarot'
        MaxBytes = 120000
    },
    @{
        Name = 'omikuji'
        ExpectedCount = 7
        ExpectedWidth = 320
        ExpectedHeight = 622
        Directory = 'assets/ritual/omikuji'
        MaxBytes = 60000
    }
)

if ($galleryManifest.watermarkMode -ne 'html-overlay') {
    $failures.Add("Ritual gallery watermarkMode should be html-overlay.")
}

$expectedWatermark = "$([char]0x00A9)arcadia-labs"
if ($galleryManifest.displayWatermark -ne $expectedWatermark) {
    $failures.Add("Ritual gallery displayWatermark should be copyright arcadia-labs.")
}

foreach ($requiredSnippet in @(
        'id="artworks"',
        'gallery-image-frame::before',
        '\00a9 arcadia-labs',
        'tarotMajorCards',
        'tarotSuits',
        'tarotRanks',
        'omikujiPapers'
    )) {
    if ($pageHtml -notmatch [regex]::Escape($requiredSnippet)) {
        $failures.Add("privacy_policy.html is missing ritual gallery snippet: $requiredSnippet")
    }
}

foreach ($check in $galleryChecks) {
    $collection = $galleryManifest.collections.($check.Name)
    if ($null -eq $collection) {
        $failures.Add("Ritual gallery manifest is missing collection: $($check.Name)")
        continue
    }

    $items = @($collection.items)
    if ([int]$collection.expectedCount -ne [int]$check.ExpectedCount) {
        $failures.Add("Ritual gallery expectedCount mismatch for $($check.Name): $($collection.expectedCount)")
    }
    if ($items.Count -ne [int]$check.ExpectedCount) {
        $failures.Add("Ritual gallery item count mismatch for $($check.Name): $($items.Count)")
    }

    $actualFiles = @(Get-ChildItem -Path (Join-Path $repoRoot $check.Directory) -Filter '*.webp' -File)
    if ($actualFiles.Count -ne [int]$check.ExpectedCount) {
        $failures.Add("Ritual gallery file count mismatch for $($check.Directory): $($actualFiles.Count)")
    }

    foreach ($item in $items) {
        $assetPath = Join-Path $repoRoot $item.file
        if (-not (Test-Path $assetPath)) {
            $failures.Add("Missing ritual gallery file: $($item.file)")
            continue
        }

        $file = Get-Item $assetPath
        if ($file.Length -le 0) {
            $failures.Add("Ritual gallery file is empty: $($item.file)")
        }
        if ($file.Length -gt [int64]$check.MaxBytes) {
            $failures.Add("Ritual gallery file exceeds maxBytes: $($item.file) is $($file.Length), max $($check.MaxBytes)")
        }
        if ([int]$item.bytes -ne [int]$file.Length) {
            $failures.Add("Ritual gallery manifest byte mismatch: $($item.file) is $($file.Length), manifest $($item.bytes)")
        }
        if ([int]$item.width -ne [int]$check.ExpectedWidth -or [int]$item.height -ne [int]$check.ExpectedHeight) {
            $failures.Add("Ritual gallery manifest dimension mismatch: $($item.file) is $($item.width)x$($item.height), expected $($check.ExpectedWidth)x$($check.ExpectedHeight)")
        }
    }
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $failures.Add("Python is required to verify WebP gallery dimensions.")
}
else {
    $dimensionCheckScript = @'
import json
import sys
from pathlib import Path
from PIL import Image

repo = Path(sys.argv[1])
manifest = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
errors = []
for collection in manifest["collections"].values():
    for item in collection["items"]:
        path = repo / item["file"]
        try:
            with Image.open(path) as image:
                actual = image.size
        except Exception as exc:
            errors.append(f"{item['file']}: {exc}")
            continue
        expected = (int(item["width"]), int(item["height"]))
        if actual != expected:
            errors.append(f"{item['file']}: {actual[0]}x{actual[1]} != {expected[0]}x{expected[1]}")
print(json.dumps(errors, ensure_ascii=False))
'@
    $dimensionOutput = $dimensionCheckScript | & $python.Source - $repoRoot $galleryManifestPath
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Python WebP dimension check failed.")
    }
    else {
        $dimensionFailures = $dimensionOutput | ConvertFrom-Json
        if ($null -ne $dimensionFailures) {
            foreach ($failure in @($dimensionFailures)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$failure)) {
                    $failures.Add("Ritual gallery dimension check failed: $failure")
                }
            }
        }
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

$tarotCount = @($galleryManifest.collections.tarot.items).Count
$omikujiCount = @($galleryManifest.collections.omikuji.items).Count
Write-Output "Public asset verification passed. $($manifest.screenshots.Count) screenshots and $tarotCount tarot / $omikujiCount omikuji gallery previews are referenced, fresh, and within guardrails."
