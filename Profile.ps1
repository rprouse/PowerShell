# Set the code page to the one used by PostGres
chcp 1252

Import-Module posh-git
Import-Module oh-my-posh
Import-Module PsGoogle
Import-Module PSSudo

# Set the oh-my-posh theme. I use the Hack NF font in the console.
Set-Theme Paradox

# Override Theme Colors
$ThemeSettings.Colors.DriveForegroundColor              = [System.ConsoleColor]::Blue
$ThemeSettings.Colors.PromptBackgroundColor             = [System.ConsoleColor]::Blue
$ThemeSettings.Colors.WithForegroundColor               = [System.ConsoleColor]::White
$ThemeSettings.Colors.PromptSymbolColor                 = [System.ConsoleColor]::White
$ThemeSettings.Colors.AdminIconForegroundColor          = [System.ConsoleColor]::DarkRed
$ThemeSettings.Colors.WithBackgroundColor               = [System.ConsoleColor]::DarkRed

# Override Theme Symbols
$ThemeSettings.GitSymbols.BranchUntrackedSymbol         = [char]::ConvertFromUtf32(0xF192)
$ThemeSettings.GitSymbols.BranchIdenticalStatusToSymbol = [char]::ConvertFromUtf32(0x2261)
$ThemeSettings.PromptSymbols.PromptIndicator            = [char]::ConvertFromUtf32(0x03BB)
$ThemeSettings.PromptSymbols.ElevatedSymbol             = [char]::ConvertFromUtf32(0x03A9)

$DefaultUser = 'rob'

# Edit this file in VS Code
function Edit-Profile { code $profile.CurrentUserAllHosts }

# List aliases for any command
function Get-CmdletAlias ($cmdletname) {
  Get-Alias |
    Where-Object -FilterScript {$_.Definition -like "$cmdletname"} |
      Format-Table -Property Definition, Name -AutoSize
}

# Set up aliases
Set-Alias ex "explorer.exe"
Set-Alias linq "C:\Program Files (x86)\LINQPad5\LINQPad.exe"
Set-Alias np "C:\Program Files (x86)\Notepad++\notepad++.exe"
Set-Alias st "C:\Program Files (x86)\Atlassian\SourceTree\SourceTree.exe"
Set-Alias vs "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\DevEnv.exe"

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

Clear-Host
Write-Host
Write-Host " Write " -ForegroundColor White -NoNewline
Write-Host " λ " -ForegroundColor Black -BackgroundColor White -NoNewline
Write-Host " Code " -ForegroundColor White
Write-Host