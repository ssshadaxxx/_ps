# Fix-ChtFile.ps1
# Sorts cheats alphabetically by description and renumbers them correctly.
#
# Single file usage:
#   .\Fix-ChtFile.ps1 -Path "Final Fantasy.cht"
#   .\Fix-ChtFile.ps1 -Path "Final Fantasy.cht" -OutputPath "Final Fantasy_fixed.cht"
#
# Directory usage (recursive, timestamped output folder):
#   .\Fix-ChtFile.ps1 -Path "C:\Cheats"

param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to a .cht file or a directory containing .cht files.")]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for single-file mode. Defaults to overwriting the input file.")]
    [string]$OutputPath
)

# ---------------------------------------------------------------------------
# Function: Process a single .cht file and write fixed content to $destination
# ---------------------------------------------------------------------------
function Invoke-FixCht {
    param (
        [string]$FilePath,
        [string]$Destination
    )

    $lines = Get-Content -Path $FilePath

    # --- Parse cheats into objects ---
    $cheats = @{}

    foreach ($line in $lines) {
        if ($line -match '^cheat(\d+)_(desc|code|enable)\s*=\s*(.+)$') {
            $index = [int]$Matches[1]
            $field = $Matches[2]
            $value = $Matches[3].Trim()

            if (-not $cheats.ContainsKey($index)) {
                $cheats[$index] = @{ desc = $null; code = $null; enable = $null }
            }
            $cheats[$index][$field] = $value
        }
    }

    if ($cheats.Count -eq 0) {
        Write-Warning "No cheat entries found in: $FilePath — skipping."
        return $false
    }

    # --- Sort alphabetically by description (case-insensitive) ---
    $sorted = $cheats.Values |
        Where-Object { $_.desc -ne $null } |
        Sort-Object { ($_.desc -replace '^"' -replace '"$').ToLower() }

    # --- Build output lines ---
    $output = [System.Collections.Generic.List[string]]::new()
    $output.Add("cheats = $($sorted.Count)")

    for ($i = 0; $i -lt $sorted.Count; $i++) {
        $cheat = $sorted[$i]
        $output.Add("")
        $output.Add("cheat${i}_desc = $($cheat.desc)")
        $output.Add("cheat${i}_code = $($cheat.code)")
        $enableVal = if ($null -ne $cheat.enable) { $cheat.enable } else { "false" }
        $output.Add("cheat${i}_enable = $enableVal")
    }

    # Ensure destination directory exists
    $destDir = Split-Path -Parent $Destination
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $output | Set-Content -Path $Destination -Encoding UTF8
    return $true
}

# ---------------------------------------------------------------------------
# Validate input path
# ---------------------------------------------------------------------------
if (-not (Test-Path $Path)) {
    Write-Error "Path not found: $Path"
    exit 1
}

$item = Get-Item -Path $Path

# ---------------------------------------------------------------------------
# DIRECTORY MODE
# ---------------------------------------------------------------------------
if ($item.PSIsContainer) {

    if ($OutputPath) {
        Write-Warning "-OutputPath is ignored in directory mode."
    }

    $chtFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.cht"

    if ($chtFiles.Count -eq 0) {
        Write-Error "No .cht files found under: $Path"
        exit 1
    }

    # Timestamped output folder alongside the input directory
    $timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outputRoot  = Join-Path (Split-Path -Parent $item.FullName) "$($item.Name)_fixed_$timestamp"

    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    Write-Host "Output folder: $outputRoot" -ForegroundColor Cyan

    $successCount = 0
    $skipCount    = 0

    foreach ($file in $chtFiles) {
        # Preserve relative subfolder structure inside the output root
        $relativePath = $file.FullName.Substring($item.FullName.Length).TrimStart('\','/')
        $destination  = Join-Path $outputRoot $relativePath

        $ok = Invoke-FixCht -FilePath $file.FullName -Destination $destination

        if ($ok) {
            Write-Host "  Fixed: $relativePath" -ForegroundColor Green
            $successCount++
        } else {
            $skipCount++
        }
    }

    Write-Host ""
    Write-Host "Done! $successCount file(s) fixed, $skipCount skipped." -ForegroundColor Green

# ---------------------------------------------------------------------------
# SINGLE FILE MODE
# ---------------------------------------------------------------------------
} else {

    if ([System.IO.Path]::GetExtension($Path) -ne ".cht") {
        Write-Warning "File does not have a .cht extension: $Path"
    }

    $destination = if ($OutputPath) { $OutputPath } else { $Path }

    $ok = Invoke-FixCht -FilePath $item.FullName -Destination $destination

    if ($ok) {
        Write-Host "Done! Output written to: $destination" -ForegroundColor Green
    }
}
