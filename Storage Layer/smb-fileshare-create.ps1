#Requires -Version 5.0 -RunAsAdministrator

param (
    [Parameter()]
    [string] $Path = "c:\qlik-share\",
    [Parameter()]
    [string] $Share = "QlikShare",
    [Parameter(Mandatory)]
    [String] $QlikSA  
)

# Include paths
. "..\helpers\common-paths.ps1"

# Common folder paths
$path_logs    = "$PSScriptRoot\..\.logs"

# Create folders if missing
if(-Not (Test-Path "$path_logs"))    { New-Item -Type Directory -Path "$path_logs" -Force    }

# Log script execution to trace/log file
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

# Break on any error
$ErrorActionPreference = "Stop"

# Validate user name format
if ($QlikSA -cnotmatch '^[a-zA-Z][a-zA-Z0-9‌​\-\.]{0,61}[a-zA-Z]\\\w[\w\.\- ]*$') {
    throw "ERROR: QlikSA parameter value '$QlikSA' not in valid DOMAIN\USER format"
}

# Split SA user and domain
$SADomain = $QlikSA.Split("\")[0]
$SAUser   = $QlikSA.Split("\")[1]

# Import and add AD module if needed
if (-Not (Get-Module -ListAvailable -Name ServerManager)) {
    Import-Module ServerManager
}
Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature

# Validate SA account as valid domain user
$QlikSA_UserPrincipalName = (Get-ADUser -Filter "Name -like ""$SAUser""").UserPrincipalName
if($null -eq $QlikSA_UserPrincipalName) {
    throw "ERROR: $SADomain\$SAUser not in valid user in domain $env:UserDnsDomain"
} 

# Add SA to local admin group
try {
    Add-LocalGroupMember -Group "Administrators" -Member "$QlikSA_UserPrincipalName"
} catch {
    Write-Host "$QlikSA_UserPrincipalName already exists in local administrator"
}

# Create folder if not already exist
if (-Not (Test-Path -Path "$Path")) {
    New-Item -Path "$Path" -Type Directory -Force
}

#    Grant-SmbShareAccess -Name "$Share" -AccountName "$env:userdomain\$env:username" -AccessRight Full -Force
if($null -eq (Get-SmbShare -Name "$Share")) { 
    New-SmbShare -Path "$Path" -Name "$Share" -fullaccess "$QlikSA_UserPrincipalName"
} else {
    Write-Host "SMB share $Share already exists" -ForegroundColor Yellow
}

If( (Get-SmbShareAccess -Name "$Share" | Where-Object { ($_.AccountName -eq "$env:userdomain\$env:username") -or ($_.AccountName -eq "$SADomain\$SAUser") } | Measure-Object).Count -ne 2) {
    Grant-SmbShareAccess -Name "$Share" -AccountName "$env:userdomain\$env:username" -AccessRight Full -Force
    Grant-SmbShareAccess -Name "$Share" -AccountName "$SADomain\$SAUser" -AccessRight Full -Force
}

# Store share path 
Write-Host "SMB file share has been successfully created;`n\\$env:COMPUTERNAME.$env:UserDnsDomain\$Share" -ForegroundColor Green

Stop-Transcript