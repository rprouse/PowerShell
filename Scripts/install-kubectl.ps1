<#PSScriptInfo
.VERSION 1.6
.GUID 32a11a36-f91c-4241-a11f-af0cf3e90f38
.AUTHOR Karsten.Bott@labbuildr.com
.COMPANYNAME 
.COPYRIGHT 
.TAGS 
.LICENSEURI 
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 This script is used during unsattended installs or to download kubectl on windows 
#>  
param(
$Downloadlocation = $env:TEMP
)

if (!(Test-Path $Downloadlocation))
    {
    New-Item -ItemType Directory $Downloadlocation -ErrorAction SilentlyContinue | out-null
    } 
$uri = "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
Write-Host -ForegroundColor White "==>Getting download link from  $uri"   
$req = Invoke-WebRequest -UseBasicParsing -Uri $uri
try
    {
        Write-Host -ForegroundColor White "==>analyzing Downloadlink"   
        $downloadlink = ($req.Links | where href -Match "kubectl.exe").href
    }
catch
    {
    Write-Warning "Error Parsing Link"
    Break
    }
Write-Host -ForegroundColor White "==>starting Download from $downloadlink using Bitstransfer"   
Start-BitsTransfer $downloadlink -DisplayName "Getting KubeCTL from $downloadlink" -Destination $Downloadlocation
$Downloadfile = Join-Path $Downloadlocation "kubectl.exe"
Unblock-File $Downloadfile
Write-Host -ForegroundColor White "==>starting '$Downloadfile version'"   
.$Downloadfile version
$Kube_Local = New-Item -ItemType directory "$($HOME)/.kube" -force
Write-Host
Write-Host -ForegroundColor Magenta "You can now start kubectl from $Downloadfile
copy your remote kubernetes cluster information to $($Kube_Local.fullname)/config
"
