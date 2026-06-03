# ==============================================================================
# Launch with
# pwsh.exe -NoExit -ExecutionPolicy Bypass -NoProfile -Command "& {. '~\\OneDrive\\Documents\\PowerShell\\Profile.esp32.ps1' }"

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
# Claude Code Alias to run with a specific MCP server configuration
function cc { claude --strict-mcp-config --mcp-config "$env:USERPROFILE\.mcp.json" --  @args}

# ==============================================================================
# ESP32 Setup
. "C:\Espressif\tools\Microsoft.v6.0.1.PowerShell_profile.ps1"

# ==============================================================================
# Skip the rest of the profile if running in an AI agent session
# ==============================================================================
if (Test-IsAiAgentSession) {
    return
}

# ==============================================================================
Import-Module Get-ChildItemColor   # https://github.com/joonro/Get-ChildItemColor
Import-Module -Name Terminal-Icons # https://www.hanselman.com/blog/take-your-windows-terminal-and-powershell-to-the-next-level-with-terminal-icons

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

# Initialize oh-my-posh
if ($env:WT_SESSION) {
    # Place Windows Terminal-specific behavior here
    #Clear-Host
    Write-Host
    Write-Host " Hack " -ForegroundColor White -NoNewline
    Write-Host " λ " -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " Chips " -ForegroundColor White
    Write-Host
} else {
    # Place alternative behavior here
    figlet -f doom "Hack Chips" | lolcat
}

# Posh up my world
oh-my-posh --init --shell pwsh --config "~\.bubbles.omp.json" | Invoke-Expression
