# Set the code page to the one used by PostGres
chcp 1252

Import-Module posh-git            # https://github.com/dahlbyk/posh-git
# Import-Module PsGoogle            # https://github.com/gfody/PsGoogle
Import-Module PSSudo              # https://github.com/ecsousa/PSSudo
Import-Module DockerCompletion    # https://github.com/matt9ucci/DockerCompletion
Import-Module Get-ChildItemColor  # https://github.com/joonro/Get-ChildItemColor
Import-Module -Name Terminal-Icons # https://www.hanselman.com/blog/take-your-windows-terminal-and-powershell-to-the-next-level-with-terminal-icons

# Set the oh-my-posh theme. I use the MesloLGS NF font in the console.
#Set-PoshPrompt -Theme powerlevel10k_classic # ~/.alteridem.omp.json

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

Write-Host Initializing VS2022 Environment

# get VS tools
Get-Batchfile "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VSDevCmd.bat"
$Env:VisualStudioVersion = "17.0"
$Env:DevToolsVersion = "170"

# Set up aliases
Set-Alias ex "explorer.exe"
Set-Alias linq "C:\Program Files (x86)\LINQPad5\LINQPad.exe"
Set-Alias wm "C:\Program Files (x86)\WinMerge\WinMergeU.exe"
Set-Alias np "C:\Program Files (x86)\Notepad++\notepad++.exe"
Set-Alias st "C:\Program Files (x86)\Atlassian\SourceTree\SourceTree.exe"
Set-Alias vs "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\DevEnv.exe"
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
# (& "~\Anaconda3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | Invoke-Expression
#endregion

Set-PoshPrompt '~\.bubbles.omp.json'