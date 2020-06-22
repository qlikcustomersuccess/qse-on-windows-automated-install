#Requires -Version 5.0 -RunAsAdministrator

# Include paths
. "$PSScriptRoot\..\helpers\common-paths.ps1"

# Log script execution to trace/log file
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

# Uninstall related choco packages, based on package names
# Only invoke uninstall on currently installed packages
choco list --local | `
Where-Object {     $_ -like "postgresql9*"  `
               -OR $_ -like "postgresql11*" `
               -OR $_ -like "pgadmin4*" } | `
ForEach-Object { $_.Split(" ")[0] } | `
ForEach-Object { choco uninstall $_ --yes }

# Clear password variable
[System.Environment]::SetEnvironmentVariable("PGPASSWORD", $null, [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable("PGDATA", $null, [System.EnvironmentVariableTarget]::User)

# Remove all listed files, if they exist
# PAssword files, DB config files, etc.
@("$path_secrets\.pg_super_pwd", `
  "$path_secrets\.pg_user_pwd") | `
ForEach-Object { 
    if([System.IO.File]::Exists("$PSScriptRoot\$_")) { 
        Write-Host "Removing $PSScriptRoot\$_" -ForegroundColor Green
        Remove-Item -Path "$PSScriptRoot\$_"
    } 
}

Stop-Transcript