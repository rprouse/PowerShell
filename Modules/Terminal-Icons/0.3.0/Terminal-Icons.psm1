
function Add-Theme {
    [cmdletbinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName  = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [switch]$Force,

        [ValidateSet('Color', 'Icon')]
        [Parameter(Mandatory)]
        [string]$Type
    )

    process {
        # Resolve path(s)
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $paths = Resolve-Path -Path $Path | Select-Object -ExpandProperty Path
        } elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $paths = Resolve-Path -LiteralPath $LiteralPath | Select-Object -ExpandProperty Path
        }

        foreach ($resolvedPath in $paths) {
            if (Test-Path $resolvedPath) {
                $item = Get-Item -LiteralPath $resolvedPath

                $statusMsg  = "Adding $($type.ToLower()) theme [$($item.BaseName)]"
                $confirmMsg = "Are you sure you want to add file [$resolvedPath]?"
                $operation  = "Add $($Type.ToLower())"
                if ($PSCmdlet.ShouldProcess($statusMsg, $confirmMsg, $operation) -or $Force.IsPresent) {
                    if (-not $themeData.Themes.$Type.ContainsKey($item.BaseName) -or $Force.IsPresent) {

                        # Convert color theme into escape sequences for lookup later
                        if ($Type -eq 'Color') {
                            $colorData = ConvertFrom-Psd1 $item.FullName
                            # Directories
                            $colorData.Types.Directories.WellKnown.GetEnumerator().ForEach({
                                $script:colorSequences[$item.BaseName].Types.Directories[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
                            })
                            # Wellknown files
                            $colorData.Types.Files.WellKnown.GetEnumerator().ForEach({
                                $script:colorSequences[$item.BaseName].Types.Files.WellKnown[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
                            })
                            # File extensions
                            $colorData.Types.Files.GetEnumerator().Where({$_.Name -ne 'WellKnown'}).ForEach({
                                $script:colorSequences[$item.BaseName].Types.Files[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
                            })
                        }

                        $colorData = ConvertFrom-Psd1 $item.FullName
                        $themeData.Themes.$Type[$item.Basename] = $colorData
                        Save-Theme -Theme $themeData
                    } else {
                        Write-Error "$Type theme [$($item.BaseName)] already exists. Use the -Force switch to overwrite."
                    }
                }
            } else {
                Write-Error "Path [$resolvedPath] is not valid."
            }
        }
    }
}
function ConvertFrom-ColorEscapeSequence {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Sequence
    )

    process {
        # Example input sequence: 'e[38;2;135;206;250m'
        $arr = $Sequence.Split(';')
        $r   = '{0:x}' -f [int]$arr[2]
        $g   = '{0:x}' -f [int]$arr[3]
        $b   = '{0:x}' -f [int]$arr[4].TrimEnd('m')

        ($r + $g + $b).ToUpper()
    }
}
function ConvertFrom-Psd1 {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]
        [hashtable]$Data
    )

    process {
        return $Data
    }
}
function ConvertFrom-RGBColor {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$RGB
    )

    process {
        $RGB = $RGB.Replace('#', '')
        $r   = [convert]::ToInt32($RGB.SubString(0,2), 16)
        $g   = [convert]::ToInt32($RGB.SubString(2,2), 16)
        $b   = [convert]::ToInt32($RGB.SubString(4,2), 16)

        $escape = [char]27
        "${escape}[38;2;$r;$g;$b`m"
    }
}
function Get-ThemeStoragePath {
    [CmdletBinding()]
    param()

    if ($IsLinux -or $IsMacOs) {
        if (-not ($path = @($env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator))[0])) {
            $path = [IO.Path]::Combine($HOME, '.local', 'share')
        }
    } else {
        if (-not ($path = $env:APPDATA)) {
            $path = [Environment]::GetFolderPath('ApplicationData')
        }
    }

    if ($path) {
        [IO.Path]::Combine($path, 'powershell', 'Community', 'Terminal-Icons', 'theme.xml')
    }
}
function Resolve-Icon {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [IO.FileSystemInfo]$FileInfo
    )

    begin {
        $icons  = $script:themeData.Themes.Icon[$themeData.CurrentIconTheme]
        $colors = $script:colorSequences[$themeData.CurrentColorTheme]
    }

    process {
        $displayInfo = @{
            Icon     = $null
            Color    = $null
            Target   = ''
        }

        if ($FileInfo.PSIsContainer) {
            $type = 'Directories'
        } else {
            $type = 'Files'
        }

        switch ($FileInfo.LinkType) {
            # Determine symlink or junction icon and color
            'Junction' {
                $iconName = $icons.Types.($type)['junction']
                $colorSeq = $colors.Types.($type)['junction']
                $displayInfo['Target'] = ' -> ' + $FileInfo.Target
                break
            }
            'SymbolicLink' {
                $iconName = $icons.Types.($type)['symlink']
                $colorSeq = $colors.Types.($type)['symlink']
                $displayInfo['Target'] = ' -> ' + $FileInfo.Target
                break
            } default {
                # Determine normal directory icon and color
                $iconName = $icons.Types.$type.WellKnown[$FileInfo.Name]
                if (-not $iconName) {
                    if ($FileInfo.PSIsContainer) {
                        $iconName = $icons.Types.$type[$FileInfo.Name]
                    } elseif ($icons.Types.$type.ContainsKey($FileInfo.Extension)) {
                        $iconName = $icons.Types.$type[$FileInfo.Extension]
                    } else {
                        # File probably has multiple extensions
                        # Fallback to computing the full extension
                        $firstDot = $FileInfo.Name.IndexOf('.')
                        if ($firstDot) {
                            $fullExtension = $FileInfo.Name.Substring($firstDot)
                            $iconName = $icons.Types.$type[$fullExtension]
                        }
                    }
                    if (-not $iconName) {
                        $iconName = $icons.Types.$type['']
                    }
                }
                $colorSeq = $colors.Types.$type.WellKnown[$FileInfo.Name]
                if (-not $colorSeq) {
                    if ($FileInfo.PSIsContainer) {
                        $colorSeq = $colors.Types.$type[$FileInfo.Name]
                    } elseif ($colors.Types.$type.ContainsKey($FileInfo.Extension)) {
                        $colorSeq = $colors.Types.$type[$FileInfo.Extension]
                    } else {
                        # File probably has multiple extensions
                        # Fallback to computing the full extension
                        $firstDot = $FileInfo.Name.IndexOf('.')
                        if ($firstDot) {
                            $fullExtension = $FileInfo.Name.Substring($firstDot)
                            $colorSeq = $colors.Types.$type[$fullExtension]
                        }
                    }
                    if (-not $colorSeq) {
                        $colorSeq = $colors.Types.$type['']
                    }
                }
            }
        }
        $displayInfo['Icon']  = $glyphs[$iconName]
        $displayInfo['Color'] = $colorSeq
        $displayInfo
    }
}
function Save-Theme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Theme
    )

    process {
        $themePath = Get-ThemeStoragePath
        $Theme | Export-CliXml -Path $themePath -Force
    }
}
function Set-Theme {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [ValidateSet('Color', 'Icon')]
        [Parameter(Mandatory)]
        [string]$Type
    )

    if (-not $themeData.Themes.$Type.ContainsKey($Name)) {
        Write-Error "$Type theme [$Name] not found."
    } else {
        $themeData."Current$($Type)Theme" = $Name
        Save-Theme -Theme $themeData
    }
}
function Add-TerminalIconsColorTheme {
    <#
    .SYNOPSIS
        Add a Terminal-Icons color theme for the current user.
    .DESCRIPTION
        Add a Terminal-Icons color theme for the current user. The theme data
        is stored in the user's profile
    .PARAMETER Path
        The path to the Terminal-Icons color theme file.
    .PARAMETER LiteralPath
        The literal path to the Terminal-Icons color theme file.
    .PARAMETER Force
        Overwrite the color theme if it already exists in the profile.
    .EXAMPLE
        PS> Add-TerminalIconsColorTheme -Path ./my_color_theme.psd1

        Add the color theme contained in ./my_color_theme.psd1.
    .EXAMPLE
        PS> Get-ChildItem ./path/to/colorthemes | Add-TerminalIconsColorTheme -Force

        Add all color themes contained in the folder ./path/to/colorthemes and add them,
        overwriting existing ones if needed.
    .INPUTS
        System.String

        You can pipe a string that contains a path to 'Add-TerminalIconsColorTheme'.
    .OUTPUTS
        None.
    .NOTES
        'Add-TerminalIconsColorTheme' will not overwrite an existing theme by default.
        Add the -Force switch to overwrite.
    .LINK
        Add-TerminalIconsIconTheme
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification='Implemented in private function')]
    [CmdletBinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName  = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [switch]$Force
    )

    process {
        Add-Theme @PSBoundParameters -Type Color
    }
}
function Add-TerminalIconsIconTheme {
    <#
    .SYNOPSIS
        Add a Terminal-Icons icon theme for the current user.
    .DESCRIPTION
        Add a Terminal-Icons icon theme for the current user. The theme data
        is stored in the user's profile
    .PARAMETER Path
        The path to the Terminal-Icons icon theme file.
    .PARAMETER LiteralPath
        The literal path to the Terminal-Icons icon theme file.
    .PARAMETER Force
        Overwrite the icon theme if it already exists in the profile.
    .EXAMPLE
        PS> Add-Terminal-IconsIconTHeme -Path ./my_icon_theme.psd1

        Add the icon theme contained in ./my_icon_theme.psd1.
    .EXAMPLE
        PS> Get-ChildItem ./path/to/iconthemes | Add-TerminalIconsIconTheme -Force

        Add all icon themes contained in the folder ./path/to/iconthemes and add them,
        overwriting existing ones if needed.
    .INPUTS
        System.String

        You can pipe a string that contains a path to 'Add-TerminalIconsIconTheme'.
    .OUTPUTS
        None.
    .NOTES
        'Add-TerminalIconsIconTheme' will not overwrite an existing theme by default.
        Add the -Force switch to overwrite.
    .LINK
        Add-TerminalIconsColorTheme
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification='Implemented in private function')]
    [CmdletBinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName  = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [switch]$Force
    )

    process {
        Add-Theme @PSBoundParameters -Type Icon
    }
}

function Format-TerminalIcons {
    <#
    .SYNOPSIS
        Prepend a custom icon (with color) to the provided file or folder object when displayed.
    .DESCRIPTION
        Take the provided file or folder object and look up the appropriate icon and color to display.
    .PARAMETER FileInfo
        The file or folder to display
    .EXAMPLE
        Get-ChildItem

        List a directory. Terminal-Icons will be invoked automatically for display.
    .EXAMPLE
        Get-Item ./README.md | Format-TerminalIcons

        Get a file object and pass directly to Format-TerminalIcons.
    .INPUTS
        System.IO.FileSystemInfo

        You can pipe an objects that derive from System.IO.FileSystemInfo (System.IO.DIrectoryInfo and System.IO.FileInfo) to 'Format-TerminalIcons'.
    .OUTPUTS
        System.String

        Outputs a colorized string with an icon prepended.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [IO.FileSystemInfo]$FileInfo
    )

    process {
        $displayInfo = Resolve-Icon $FileInfo
        "$($displayInfo.Color)$($displayInfo.Icon)  $($FileInfo.Name)$($displayInfo.Target)$($script:colorReset)"
    }
}
function Get-TerminalIconsColorTheme {
    <#
    .SYNOPSIS
        List the available color themes.
    .DESCRIPTION
        List the available color themes.
    .Example
        PS> Get-TerminalIconsColorTheme

        Get the list of available color themes.
    .INPUTS
        None.
    .OUTPUTS
        System.Collections.Hashtable

        An array of hashtables representing available color themes.
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    #>
    $themeData.Themes.Color
}
function Get-TerminalIconsIconTheme {
    <#
    .SYNOPSIS
        List the available icon themes.
    .DESCRIPTION
        List the available icon themes.
    .Example
        PS> Get-TerminalIconsIconTheme

        Get the list of available icon themes.
    .INPUTS
        None.
    .OUTPUTS
        System.Collections.Hashtable

        An array of hashtables representing available icon themes.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsTheme
    #>
    $themeData.Themes.Icon
}
function Get-TerminalIconsTheme {
    <#
    .SYNOPSIS
        Get the currently applied color and icon theme.
    .DESCRIPTION
        Get the currently applied color and icon theme.
    .EXAMPLE
        PS> Get-TerminalIconsTheme

        Get the currently applied Terminal-Icons color and icon theme.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        An object representing the currently applied color and icon theme.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    #>
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        PSTypeName = 'TerminalIconsTheme'
        Color      = [pscustomobject]$themeData.Themes.Color[$themeData.CurrentColorTheme]
        Icon       = [pscustomobject]$themeData.Themes.Icon[$themeData.CurrentIconTheme]
    }
}
function Set-TerminalIconsColorTheme {
    <#
    .SYNOPSIS
        Set the Terminal-Icons color theme.
    .DESCRIPTION
        Set the Terminal-Icons color theme to a registered theme.
    .PARAMETER Name
        The name of a registered color theme.
    .EXAMPLE
        PS> Set-TerminalIconsColorTheme -Name devblackops

        Set the color theme to 'devblackops'.
    .INPUTS
        System.String

        The name of a registered color theme.
    .OUTPUTS
        None.
    .LINK
        Set-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        Set-Theme -Name $Name -Type Color
    }
}
function Set-TerminalIconsIconTheme {
    <#
    .SYNOPSIS
        Set the Terminal-Icons icon theme.
    .DESCRIPTION
        Set the Terminal-Icons icon theme to a registered theme.
    .PARAMETER Name
        The name of a registered icon theme.
    .EXAMPLE
        PS> Set-TerminalIconsIconTheme -Name devblackops

        Set the icon theme to 'devblackops'.
    .INPUTS
        System.String

        The name of a registered icon theme.
    .OUTPUTS
        None.
    .LINK
        Set-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    process {
        Set-Theme -Name $Name -Type Icon
    }
}
function Show-TerminalIconsTheme {
    <#
    .SYNOPSIS
        List example directories and files to show the currently applied color and icon themes.
    .DESCRIPTION
        List example directories and files to show the currently applied color and icon themes.
        The directory/file objects show are in memory only, they are not written to the filesystem.
    .EXAMPLE
        Show-TerminalIconsTheme

        List example directories and files to show the currently applied color and icon themes.
    .INPUTS
        None.
    .OUTPUTS
        System.IO.DirectoryInfo
    .OUTPUTS
        System.IO.FileInfo
    .NOTES
        Example directory and file objects only exist in memory. They are not written to the filesystem.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    #>
    [CmdletBinding()]
    param()

    $directories = @(
        [IO.DirectoryInfo]::new('ExampleFolder')
        $themeData.Themes.Icon[$themeData.CurrentIconTheme].Types.Directories.WellKnown.Keys.ForEach({
            [IO.DirectoryInfo]::new($_)
        })
    )
    $wellKnownFiles = @(
        [IO.FileInfo]::new('ExampleFile')
        $themeData.Themes.Icon[$themeData.CurrentIconTheme].Types.Files.WellKnown.Keys.ForEach({
            [IO.FileInfo]::new($_)
        })
    )

    $extensions = $themeData.Themes.Icon[$themeData.CurrentIconTheme].Types.Files.Keys.Where({$_ -ne 'WellKnown'}).ForEach({
        [IO.FileInfo]::new("example$_")
    })

    $directories + $wellKnownFiles + $extensions | Sort-Object
}

# # Dot source public/private functions
# $public  = @(Get-ChildItem -Path ([IO.Path]::Combine($PSScriptRoot, 'Public/*.ps1'))  -Recurse -ErrorAction Stop)
# $private = @(Get-ChildItem -Path ([IO.Path]::Combine($PSScriptRoot, 'Private/*.ps1')) -Recurse -ErrorAction Stop)
# @($public + $private).ForEach({
#     try {
#         . $_.FullName
#     } catch {
#         throw $_
#         $PSCmdlet.ThrowTerminatingError("Unable to dot source [$($import.FullName)]")
#     }
# })

$glyphs     = . $PSScriptRoot/Data/glyphs.ps1
$escape     = [char]27
$colorReset = "${escape}[0m"

# Import module theme files
$colorThemes = @{}

# Converted color themes
$script:colorSequences = @{}

(Get-ChildItem -Path $PSScriptRoot/Data/colorThemes -Filter '*.psd1').Foreach({

    # Import the color theme and convert to escape sequences
    $colorData = ConvertFrom-Psd1 $_.FullName
    $colorSequences[$_.Basename] = @{
        Name = $colorData.Name
        Types = @{
            Directories = @{
                #''        = "`e[0m"
                symlink  = ''
                junction = ''
                WellKnown = @{}
            }
            Files = @{
                #''        = "`e[0m"
                symlink  = ''
                junction = ''
                WellKnown = @{}
            }
        }
    }
    # Directories
    $script:colorSequences[$colorData.Name].Types.Directories['symlink']  = ConvertFrom-RGBColor -RGB $colorData.Types.Directories['symlink']
    $script:colorSequences[$colorData.Name].Types.Directories['junction'] = ConvertFrom-RGBColor -RGB $colorData.Types.Directories['junction']
    $colorData.Types.Directories.WellKnown.GetEnumerator().ForEach({
        $script:colorSequences[$colorData.Name].Types.Directories[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
    })
    # Wellknown files
    $script:colorSequences[$colorData.Name].Types.Files['symlink']  = ConvertFrom-RGBColor -RGB $colorData.Types.Files['symlink']
    $script:colorSequences[$colorData.Name].Types.Files['junction'] = ConvertFrom-RGBColor -RGB $colorData.Types.Files['junction']
    $colorData.Types.Files.WellKnown.GetEnumerator().ForEach({
        $script:colorSequences[$colorData.Name].Types.Files.WellKnown[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
    })
    # File extensions
    $colorData.Types.Files.GetEnumerator().Where({$_.Name -ne 'WellKnown'}).ForEach({
        $script:colorSequences[$colorData.Name].Types.Files[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
    })

    $colorThemes.Add($colorData.Name, $colorData)
    $colorThemes[$colorData.Name].Types.Directories[''] = $colorReset
    $colorThemes[$colorData.Name].Types.Files['']       = $colorReset
})
$iconThemes = @{}
(Get-ChildItem -Path $PSScriptRoot/Data/iconThemes).Foreach({
    $iconThemes.Add($_.Basename, (Import-PowerShellDataFile -Path $_.FullName))
})

$defaultTheme = 'devblackops'

# Import local theme data
$themePath = Get-ThemeStoragePath
$themeBasePath = Split-Path $themePath
if (-not (Test-Path $themeBasePath)) {
    New-Item -Path $themeBasePath -ItemType Directory -Force
}

if (Test-Path $themePath) {
    $themeData = Import-CliXml -Path $themePath
}
if (-not $themeData) {
    # We have no theme data saved (first time use?)
    # Create one and save it
    $themeData = @{
        CurrentIconTheme  = $defaultTheme
        CurrentColorTheme = $defaultTheme
        Themes = @{
            Color = $colorThemes
            Icon  = $iconThemes
        }
    }
} else {
    # Load or set default theme (if missing)
    if ([string]::IsNullOrEmpty($themeData.CurrentColorTheme)) {
        $themeData.CurrentColorTheme = $defaultTheme
    }
    if ([string]::IsNullOrEmpty($themeData.CurrentIconTheme)) {
        $themeData.CurrentIconTheme = $defaultTheme
    }

    if ($null -eq $themeData.Themes -or $themeData.Themes.Count -eq 0) {
        $themeData.Themes = @{
            Color = @{}
            Icon  = @{}
        }
    }

    # Update the builtin themes
    $colorThemes.GetEnumerator().ForEach({
        $themeData.Themes.Color[$_.Name] = $_.Value
    })
    $iconThemes.GetEnumerator().ForEach({
        $themeData.Themes.Icon[$_.Name] = $_.Value
    })
}

$themeData | Export-Clixml -Path $themePath -Force

# Export-ModuleMember -Function $public.Basename

Update-FormatData -Prepend ([IO.Path]::Combine($PSScriptRoot, 'Terminal-Icons.format.ps1xml'))

