# Non-interactive session (VS Code Remote-SSH bootstrap, scp, `ssh host cmd`): load nothing.
if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }

# ==============================================================================
function Test-IsAiAgentSession {

    # Env hint (Claude Code sets CLAUDECODE=1)
    if ($env:CLAUDECODE -or $env:CLAUDE_SHELL) { return $true }

    # Parent process
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $PID" |
    Select-Object -ExpandProperty ParentProcessId |
    ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }

    if ($parent.Name -match 'claude|copilot') {
        return $true
    }

    # Command automation flags
    $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").CommandLine
    if ($cmdLine -match '-NonInteractive|-EncodedCommand') {
        return $true
    }

    return $false
}

# Runs a batch file and then updates the PS environment variables with the results
function Get-Batchfile ($file) {
    $cmd = "`"$file`" & set"
    cmd /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}

# ==============================================================================
# Git related functions
function Prune-LocalBranches() {
    git branch --merged master | grep -v 'master$' | ForEach-Object { git branch -d $_.Trim() }
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
    Set-Location -Path D:\src
}

function nguid() {
    return [guid]::NewGuid().ToString("B").ToUpperInvariant();
}

# Edit this file in VS Code
function Edit-Profile { code $profile.CurrentUserAllHosts }

# List aliases for any command
function Get-CmdletAlias ($cmdletname) {
    Get-Alias |
    Where-Object -FilterScript { $_.Definition -like "$cmdletname" } |
    Format-Table -Property Definition, Name -AutoSize
}

# Current PowerShell version
function Get-Version() {
    "PowerShell " + $PSVersionTable.PSVersion.ToString()
}

# ==============================================================================
# Claude Code Alias to run with a specific MCP server configuration
function cc { claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.json" --  @args}

# Claude Code with Cowork style MCP config
function cowork { claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.cowork.json" --  @args }

# ==============================================================================
# Claude Code Aliases to in my Obsidian vaults
function notes {
    Set-Location -Path "G:\My Drive\todo\notes"
    claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.obsidian.json" -- @args
}

function til {
    Set-Location -Path "G:\My Drive\todo\til"
    claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.obsidian.json" -- @args
}

function electronics {
    Set-Location -Path "G:\My Drive\todo\electronics"
    claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.obsidian.json" -- @args
}

function hax {
    Set-Location -Path "G:\My Drive\todo\H@X Notes"
    claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.obsidian.json" -- @args
}

function recipes {
    Set-Location -Path "G:\My Drive\Recipes"
    claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.obsidian.json" -- @args
}

# ==============================================================================
# Initialize the development environment
# Does the VS2022 or VS2026 environment exist?
if (Test-Path "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat") {
    Write-Host "Initializing VS2026 Environment..."
    Get-Batchfile "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"
    Set-Alias vs "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\DevEnv.exe"
    $Env:VisualStudioVersion = "18.0"
    $Env:DevToolsVersion = "180"
}
else {
    Write-Host "No Visual Studio environment found"
}

# ==============================================================================
# Skip the rest of the profile if running in an AI agent session
# ==============================================================================
if (Test-IsAiAgentSession) {
    return
}

# ==============================================================================
Import-Module posh-git             # https://github.com/dahlbyk/posh-git
# Import-Module PsGoogle           # https://github.com/gfody/PsGoogle
Import-Module DockerCompletion     # https://github.com/matt9ucci/DockerCompletion
Import-Module Get-ChildItemColor   # https://github.com/joonro/Get-ChildItemColor
Import-Module -Name Terminal-Icons # https://www.hanselman.com/blog/take-your-windows-terminal-and-powershell-to-the-next-level-with-terminal-icons
Import-Module -Name Microsoft.WinGet.CommandNotFound
# Import-Module PowerShellGet

# ==============================================================================
# Set up aliases
# Write-Host "Setting up aliases..."
Set-Alias ex "explorer.exe"
Set-Alias np "C:\Program Files\Notepad++\notepad++.exe"
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
Set-Alias paste Get-Clipboard
Set-Alias pbpaste Get-Clipboard
Set-Alias pbcopy Set-Clipboard
Set-Alias profile Edit-Profile

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# ==============================================================================
# dotnet suggest shell start
# Write-Host "Setting up dotnet-suggest tab completion..."
if (Get-Command "dotnet-suggest" -errorAction SilentlyContinue)
{
    $availableToComplete = (dotnet-suggest list) | Out-String
    $availableToCompleteArray = $availableToComplete.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)

    Register-ArgumentCompleter -Native -CommandName $availableToCompleteArray -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $fullpath = (Get-Command $commandAst.CommandElements[0]).Source

        $arguments = $commandAst.Extent.ToString().Replace('"', '\"')
        dotnet-suggest get -e $fullpath --position $cursorPosition -- "$arguments" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
else
{
    "Unable to provide System.CommandLine tab completion support unless the [dotnet-suggest] tool is first installed."
    "See the following for tool installation: https://www.nuget.org/packages/dotnet-suggest"
}

$env:DOTNET_SUGGEST_SCRIPT_VERSION = "2.0.8"
# dotnet suggest script end

# Shows navigable menu of all options when hitting Ctrl-Space
Set-PSReadlineKeyHandler -Key Ctrl-Spacebar -Function MenuComplete

# This function searches command history for command lines that start with the current contents of the command line.
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ESC clears the line
Set-PSReadLineKeyHandler -Key Escape -Function BackwardDeleteInput

# ==============================================================================
# WinGet Command Line Tab Completion
# https://github.com/microsoft/winget-cli/blob/1fbfacc13950de8a17875d40a8beb99fc6ada6c2/doc/Completion.md
# Write-Host "Setting up winget tab completion..."
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# ==============================================================================
# PowerShell parameter completion shim for the dotnet CLI
# https://learn.microsoft.com/en-ca/dotnet/core/tools/enable-tab-autocomplete?WT.mc_id=modinfra-35653-salean#powershell
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
     param($commandName, $wordToComplete, $cursorPosition)
         dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
         }
 }

# Initialize oh-my-posh
if ($env:WT_SESSION) {
    # Place Windows Terminal-specific behavior here
    #Clear-Host
    Write-Host
    Write-Host " Write " -ForegroundColor White -NoNewline
    Write-Host " λ " -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " Code " -ForegroundColor White
    Write-Host
} else {
    # Place alternative behavior here
    figlet -f doom "Write Code" | lolcat
}

# Posh up my world
oh-my-posh --init --shell pwsh --config "~\.bubbles.omp.json" | Invoke-Expression

# Zoxide
Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
