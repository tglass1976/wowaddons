param(
    [string]$OutputDir = "release",
    [string]$Version = "",
    [switch]$IncludeReadme,
    [switch]$SkipValidation,
    [switch]$VerboseValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonNames = @("BankMatsViewer", "ProfessionUI")

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-ReleaseZip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,
        [Parameter(Mandatory = $true)]
        [string]$AddonName,
        [switch]$IncludeReadme,
        [switch]$VerboseValidation
    )

    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @($zip.Entries)
        if ($entries.Count -eq 0) {
            throw "Validation failed for ${AddonName}: zip is empty."
        }

        $hasToc = $false
        foreach ($entry in $entries) {
            $full = $entry.FullName
            if ($full -imatch "^$([regex]::Escape($AddonName))[\\/].*\.toc$") {
                $hasToc = $true
                break
            }
        }

        if (-not $hasToc) {
            throw "Validation failed for ${AddonName}: no .toc found under ${AddonName}/."
        }

        foreach ($entry in $entries) {
            $full = $entry.FullName
            if ($full -imatch "\.md$") {
                $isReadme = $full -imatch "[\\/]README\.md$"
                if (-not ($IncludeReadme -and $isReadme)) {
                    throw "Validation failed for ${AddonName}: disallowed markdown file in zip: $full"
                }
            }

            if ($full -notmatch "(?i)^$([regex]::Escape($AddonName))[\\/]") {
                throw "Validation failed for ${AddonName}: zip entry not rooted under addon folder: $full"
            }
        }

        if ($VerboseValidation) {
            Write-Host "Validated $AddonName ($($entries.Count) entries): OK"
        }
    }
    finally {
        $zip.Dispose()
    }
}

$outputPath = Join-Path $repoRoot $OutputDir
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}

$stageRoot = Join-Path $env:TEMP ("wowaddons-release-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stageRoot | Out-Null

try {
    foreach ($addon in $addonNames) {
        $sourcePath = Join-Path $repoRoot $addon
        if (-not (Test-Path $sourcePath)) {
            Write-Warning "Skipping missing addon folder: $addon"
            continue
        }

        $stagedAddonPath = Join-Path $stageRoot $addon
        Copy-Item -Path $sourcePath -Destination $stagedAddonPath -Recurse -Force

        # Remove non-runtime docs from release package.
        Get-ChildItem -Path $stagedAddonPath -Recurse -File | Where-Object {
            ($_.Extension -ieq ".md") -or
            ($_.Name -ieq "AGENTS.md") -or
            ($_.Name -ieq "ADDON_DEV_DOCS.md")
        } | ForEach-Object {
            if ($IncludeReadme -and $_.Name -ieq "README.md") {
                return
            }
            Remove-Item -Path $_.FullName -Force
        }

        $zipBaseName = if ([string]::IsNullOrWhiteSpace($Version)) {
            $addon
        } else {
            "$addon-$Version"
        }

        $zipPath = Join-Path $outputPath ($zipBaseName + ".zip")
        if (Test-Path $zipPath) {
            Remove-Item -Path $zipPath -Force
        }

        Compress-Archive -Path $stagedAddonPath -DestinationPath $zipPath -Force

        if (-not $SkipValidation) {
            Test-ReleaseZip -ZipPath $zipPath -AddonName $addon -IncludeReadme:$IncludeReadme -VerboseValidation:$VerboseValidation
        }

        Write-Host "Built $zipPath"
    }
}
finally {
    if (Test-Path $stageRoot) {
        Remove-Item -Path $stageRoot -Recurse -Force
    }
}

Write-Host "Done. Release zips are in: $outputPath"
