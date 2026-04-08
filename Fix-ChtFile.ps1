# Fix-ChtFile.ps1
# Sorts cheats alphabetically by description and renumbers them correctly.
# Usage: .\Fix-ChtFile.ps1 -Path "Final Fantasy.cht"
#        .\Fix-ChtFile.ps1 -Path "Final Fantasy.cht" -OutputPath "Final Fantasy_fixed.cht"

param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the .cht file to process.")]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Output path. Defaults to overwriting the input file.")]
    [string]$OutputPath
)

# Validate input file
if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

if ([System.IO.Path]::GetExtension($Path) -ne ".cht") {
    Write-Warning "File does not have a .cht extension: $Path"
}

$lines = Get-Content -Path $Path

# --- Parse cheats into objects ---
$cheats = @{}

foreach ($line in $lines) {
    # Match lines like: cheat0_desc = "..." or cheat12_code = "..." or cheat3_enable = false
    if ($line -match '^cheat(\d+)_(desc|code|enable)\s*=\s*(.+)$') {
        $index  = [int]$Matches[1]
        $field  = $Matches[2]
        $value  = $Matches[3].Trim()

        if (-not $cheats.ContainsKey($index)) {
            $cheats[$index] = @{ desc = $null; code = $null; enable = $null }
        }
        $cheats[$index][$field] = $value
    }
}

if ($cheats.Count -eq 0) {
    Write-Error "No cheat entries found in the file."
    exit 1
}

# --- Sort cheats alphabetically by description (case-insensitive) ---
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
    # Preserve enable value if present; default to false if missing
    $enableVal = if ($null -ne $cheat.enable) { $cheat.enable } else { "false" }
    $output.Add("cheat${i}_enable = $enableVal")
}

# --- Write output ---
$destination = if ($OutputPath) { $OutputPath } else { $Path }

$output | Set-Content -Path $destination -Encoding UTF8

Write-Host "Done! Processed $($sorted.Count) cheat(s)." -ForegroundColor Green
Write-Host "Output written to: $destination" -ForegroundColor Cyan
