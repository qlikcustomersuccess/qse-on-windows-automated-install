#Requires -Version 5.0 -RunAsAdministrator

# Log script execution to trace/log file
Start-Transcript -Path "$PSScriptRoot\..\.logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

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

# Remove all listed files, if they exist
# PAssword files, DB config files, etc.
@("..\.secrets\.pg_super_pwd", `
  "..\.secrets\.pg_super_pwd", `
  "postgresql.conf", `
  "pg_hba.conf" ) | `
ForEach-Object { 
    if([System.IO.File]::Exists("$PSScriptRoot\$_")) { 
        Write-Host "Removing $PSScriptRoot\$_" -ForegroundColor Green
        Remove-Item -Path "$PSScriptRoot\$_"
    } 
}

Stop-Transcript