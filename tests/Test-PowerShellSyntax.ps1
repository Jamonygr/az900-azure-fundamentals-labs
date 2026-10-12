#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failed = $false
Get-ChildItem -Path (Join-Path $root 'tools'), (Join-Path $root 'labs'), $PSScriptRoot -Recurse -File |
    Where-Object Extension -in @('.ps1', '.psm1') | ForEach-Object {
        $tokens = $null; $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count) {
            $failed = $true
            $parseErrors | ForEach-Object { Write-Host $_.Message }
        }
    }
Get-ChildItem -Path (Join-Path $root 'docs'), (Join-Path $root 'labs'), (Join-Path $root 'README.md') -Recurse -File -Filter '*.md' |
    ForEach-Object {
        $source = $_.FullName
        $text = Get-Content -LiteralPath $source -Raw
        foreach ($match in [regex]::Matches($text, '(?ms)^[ \t]*```powershell\r?\n(.*?)^[ \t]*```')) {
            $tokens = $null; $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($match.Groups[1].Value, [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count) {
                $failed = $true
                Write-Host "Invalid PowerShell example in $source"
                $parseErrors | ForEach-Object { Write-Host $_.Message }
            }
        }
    }
if ($failed) { throw 'PowerShell syntax validation failed.' }
Write-Host 'PASS: PowerShell script, module, and lesson example syntax'
