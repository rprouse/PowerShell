# Set the code page to the one used by PostGres
chcp 1252

Import-Module posh-git            # https://github.com/dahlbyk/posh-git
Import-Module oh-my-posh          # https://github.com/JanDeDobbeleer/oh-my-posh
Import-Module PsGoogle            # https://github.com/gfody/PsGoogle
Import-Module PSSudo              # https://github.com/ecsousa/PSSudo
Import-Module DockerCompletion    # https://github.com/matt9ucci/DockerCompletion
Import-Module Get-ChildItemColor  # https://github.com/joonro/Get-ChildItemColor

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
#$ThemeSettings.GitSymbols.LocalStagedStatusSymbol       = [char]::ConvertFromUtf32(0x)
$ThemeSettings.GitSymbols.BranchUntrackedSymbol         = [char]::ConvertFromUtf32(0x2205)  # ∅
$ThemeSettings.GitSymbols.BranchIdenticalStatusToSymbol = [char]::ConvertFromUtf32(0x21CB)  # ⇋
#$ThemeSettings.GitSymbols.BranchAheadStatusSymbol       = [char]::ConvertFromUtf32(0x21E7)  # ⇧
#$ThemeSettings.GitSymbols.BranchBehindStatusSymbol      = [char]::ConvertFromUtf32(0x21E9)  # ⇩

$ThemeSettings.PromptSymbols.PromptIndicator            = [char]::ConvertFromUtf32(0x03BB)  # λ
$ThemeSettings.PromptSymbols.ElevatedSymbol             = [char]::ConvertFromUtf32(0x03A9)  # Ω
$ThemeSettings.PromptSymbols.VirtualEnvSymbol           = [char]::ConvertFromUtf32(0x236B)  # ⍫

$DefaultUser = 'rob'

function Prune-LocalBranches() {
  git branch --merged master | grep -v 'master$' | ForEach-Object { git branch -d $_.Trim() }
}

# Edit this file in VS Code
function Edit-Profile { code $profile.CurrentUserAllHosts }

# List aliases for any command
function Get-CmdletAlias ($cmdletname) {
  Get-Alias |
    Where-Object -FilterScript {$_.Definition -like "$cmdletname"} |
      Format-Table -Property Definition, Name -AutoSize
}

# Runs a batch file and then updates the PS environment variables with the results
function Get-Batchfile ($file) {
  $cmd = "`"$file`" & set"
  cmd /c $cmd | Foreach-Object {
      $p, $v = $_.split('=')
      Set-Item -path env:$p -value $v
  }
}

# Current PowerShell version
function Get-Version() {
  "PowerShell " + $PSVersionTable.PSVersion.ToString()
}

# For new machines
function Install-Chocolatey {
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

function nguid() {
  return [guid]::NewGuid().ToString("B").ToUpperInvariant();
}

function Update-Git($default_branch) {
  git checkout $default_branch
  git fetch -p
  git pull
}

function Update-Master() {
  Update-Git('master')
}

function Update-Main() {
  Update-Git('main')
}

function Set-SourceDirectory() {
    Set-Location -Path C:\src
}

Write-Host Initializing VS2019 Environment

# get VS tools
Get-Batchfile "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VSDevCmd.bat"
$Env:VisualStudioVersion = "16.0"
$Env:DevToolsVersion = "160"

# Set up aliases
Set-Alias ex "explorer.exe"
Set-Alias linq "C:\Program Files (x86)\LINQPad5\LINQPad.exe"
Set-Alias wm "C:\Program Files (x86)\WinMerge\WinMergeU.exe"
Set-Alias np "C:\Program Files (x86)\Notepad++\notepad++.exe"
Set-Alias st "C:\Program Files (x86)\Atlassian\SourceTree\SourceTree.exe"
Set-Alias vs "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\DevEnv.exe"
Set-Alias ver Get-Version
Set-Alias which Get-Command
Set-Alias halt "shutdown.exe /s /t 5"
Set-Alias reboot "shutdown.exe /r /t 5"
Set-Alias logoff "Shutdown.exe /l"
Set-Alias lock "rundll32.exe user32.dll,LockWorkStation"
Set-Alias update "start ms-settings:windowsupdate-action"
Set-Alias l Get-ChildItemColor -option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -option AllScope
Set-Alias src Set-SourceDirectory

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# dotnet-suggest configuration, https://github.com/dotnet/command-line-api/blob/main/docs/dotnet-suggest.md
$availableToComplete = (dotnet-suggest list) | Out-String
$availableToCompleteArray = $availableToComplete.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)


    Register-ArgumentCompleter -Native -CommandName $availableToCompleteArray -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $fullpath = (Get-Command $wordToComplete.CommandElements[0]).Source

        $arguments = $wordToComplete.Extent.ToString().Replace('"', '\"')
        dotnet-suggest get -e $fullpath --position $cursorPosition -- "$arguments" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
$env:DOTNET_SUGGEST_SCRIPT_VERSION = "1.0.0"

# Start in my source directory
# Set-Location -Path C:\src

Clear-Host
Write-Host
Write-Host " Write " -ForegroundColor White -NoNewline
Write-Host " λ " -ForegroundColor Black -BackgroundColor White -NoNewline
Write-Host " Code " -ForegroundColor White
Write-Host
#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
(& "C:\Users\rob\Anaconda3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | Invoke-Expression
#endregion

