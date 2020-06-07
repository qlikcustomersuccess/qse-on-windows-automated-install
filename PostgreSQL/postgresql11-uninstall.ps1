#Requires -Version 5.0 -RunAsAdministrator

# Log script execution to trace/log file
Start-Transcript -Path "$PSScriptRoot\$(split-path $PSCommandPath -Leaf)_$(get-date -format "ddMMyyyyHHmmss").log" -NoClobber

# Install PostgreSQL 11 and PGAdmin through Chocolatey
choco uninstall postgresql11 --yes
choco uninstall pgadmin4 --yes

# Clear password variable
[System.Environment]::SetEnvironmentVariable("PGPASSWORD", $null, [System.EnvironmentVariableTarget]::User)

Stop-Transcript