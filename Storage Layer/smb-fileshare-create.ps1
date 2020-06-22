#Requires -Version 5.0 -RunAsAdministrator

<#
    .SYNOPSIS
    Automated install of SMB file share for Qlik Sense persistance storage

    .DESCRIPTION

    .PARAMETER Path
    Local folder path on server to share folder.  
    Default path is c:\qlik-share\

    .PARAMETER  Share
    Name of SMB file share.
    Default value is QlikShare

    .PARAMETER  ServiceAccount
    Domain user account that runs Qlik Sense services, definde in format DOAMIN\USER. 
    This user will be granted full access to SMB file share to enable Qlik Sense to 
    both read and write files. 
    No default value, must be defined at script call. 

    .EXAMPLE
    C:\PS> .\smb-fileshare-create.ps1 -ServiceAccount DOMAIN\QlikService

    Folder c:\qlik-sahre is shared as SMB share QlikShare to DOMAIN\Service

    .NOTES
    Copyright (c) 2020. This script is provided "AS IS", without any warranty, under the MIT License.     
#>

param (
    [Parameter()]
    [string] $Path = "c:\qlik-share\",
    [Parameter()]
    [string] $Share = "QlikShare",
    [Parameter(Mandatory=$true)]
    [String] $ServiceAccount  
)

# Break on any error
$ErrorActionPreference = "Stop"

# Common folder paths
$path_logs    = "$PSScriptRoot\..\.logs"

# Log script execution to trace/log file
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber | Out-Null

# Validate user name format
if ($ServiceAccount -cnotmatch '^[a-zA-Z][a-zA-Z0-9‌​\-\.]{0,61}[a-zA-Z]\\\w[\w\.\- ]*$') {
    throw "ERROR: ServiceAccount parameter value '$ServiceAccount' not in valid DOMAIN\USER format"
}

#Create folder if not already exist
New-Item -Path "$Path" -Type Directory -Force | Out-Null

# Create new SMB share
# Expected to fail if same name share already exists
try {    
    New-SmbShare -Path "$Path" -Name "$Share" -fullaccess "$env:userdomain\$env:username" | Out-Null
} catch {}
Grant-SmbShareAccess -Name "$Share" -AccountName "$ServiceAccount" -AccessRight Full -Force | Out-Null

# Return Share URI
Write-Output "\\$env:COMPUTERNAME.$env:UserDnsDomain\$Share"

Stop-Transcript | Out-Null