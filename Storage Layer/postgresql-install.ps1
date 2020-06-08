#Requires -Version 5.0 -RunAsAdministrator

<#
    .SYNOPSIS
    Automated install of PostgreSQL database server for use as Qlik Sense Repository database

    .DESCRIPTION
    Utilize Chocolately package manager to install PostgreSQL server in Windows environement. Setup databases and roles as required for Qlik Sense Enterprise on Windows.     

    .PARAMETER  Release
    Defines the PostgreSQL major version to be installed. Value is defined as the Chocolatey package names postgresql9 or postgresql11. 
    Default value is postgresql11.

    .PARAMETER  DummyPassword
    Flag if dummy password Password123! should be forced to database super user and Qlik Sense databse users. By default random passwords are generated and shared in .secrets folder.

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1

    Installs PostgreSQL 11.x server with Qlik Sense databases. Superuser password and and database user password are random. 

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -DummyPassword
    
    Installs PostgreSQL 11.x server with Qlik Sense databases. Superuser password and and database user password are are forced to Password123!. 

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -release "postgresql9"
    
    Installs PostgreSQL 9.6.x server with Qlik Sense databases. Superuser password and and database user password are random. 

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -release "postgresql9" -DummyPassword
    
    Installs PostgreSQL 9.6.x server with Qlik Sense databases. Superuser password and and database user password are are forced to Password123!. 

    .NOTES
    Copyright (c) 2020. This script is provided "AS IS", without any warranty, under the MIT License.     
#>

param (
    [Parameter()]
    [ValidateSet("postgresql9", "postgresql11")]
    [string] $Release = "postgresql11", 
    [Parameter(Mandatory=$false)]
    [Switch] $DummyPassword
)

# Break on any error
$ErrorActionPreference = "Stop"

# Define outpu locations
$path_logs          = "$PSScriptRoot\..\.logs"
$path_secrets       = "$PSScriptRoot\..\.secrets"
$path_pg_super_pwd  = "$path_secrets\.pg_super_pwd"
$path_pg_user_pwd   = "$path_secrets\.pg_user_pwd"

# Log script execution to trace/log file
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

# Invoke Chcolatey installation 
Invoke-Expression -Command """$PSScriptRoot\..\Chocolatey\install-package-mngr.ps1"""

# Create secrets folder
New-Item -Type Directory -Path "$path_secrets" -Force

# Generate new password files if files are missing or if DummyPassword is enforced
# Password files are written to .secrets folder
if ( $DummyPassword ) {
    "Password123!" | Out-File -FilePath "$path_pg_super_pwd" -NoNewline
    "Password123!" | Out-File -FilePath "$path_pg_user_pwd" -NoNewline
} 
Add-Type -AssemblyName System.Web
if (-Not [System.IO.File]::Exists($path_pg_super_pwd)) {
    [System.Web.Security.Membership]::GeneratePassword(16,0) | Out-File -FilePath "$path_pg_super_pwd" -NoNewline
}
if (-Not [System.IO.File]::Exists($path_pg_user_pwd)) {
    [System.Web.Security.Membership]::GeneratePassword(16,0) | Out-File -FilePath "$path_pg_user_pwd" -NoNewline
}

$pg_super_pwd = Get-Content -Path "$path_pg_super_pwd" -TotalCount 1
$pg_user_pwd  = Get-Content -Path "$path_pg_user_pwd" -TotalCount 1

# Install PostgreSQL and PGAdmin through Chocolatey
choco install $Release --package-parameters "/Password:$pg_super_pwd" --yes
choco install pgadmin4 --yes

# Configure PGPASSWORD to allow usage of PSQL.EXE
# Refresh variable in current temrinal session
[System.Environment]::SetEnvironmentVariable("PGPASSWORD", "$pg_super_pwd", [System.EnvironmentVariableTarget]::User)
$env:PGPASSWORD = [System.Environment]::GetEnvironmentVariable("PGPASSWORD","User")

# Create databases and configure roles
# https://help.qlik.com/en-US/sense-admin/April2020/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Deploy_QSEoW/Installing-configuring-postgresql.htm

if($Release -eq "postgresql11") {
    $PostgresInstallPath = "$env:ProgramFiles\PostgreSQL\11\"
} else {
    $PostgresInstallPath = "$env:ProgramFiles\PostgreSQL\9.6\"
}    

Set-Location -Path "$PostgresInstallPath\bin"

.\psql.exe  --username=postgres --host localhost --port=5432 --no-password --echo-errors --echo-queries `
            --command 'CREATE DATABASE "QSR" ENCODING = "UTF8";' `
            --command 'CREATE DATABASE "SenseServices" ENCODING = "UTF8";' `
            --command 'CREATE DATABASE "QSMQ" ENCODING = "UTF8";' `
            --command 'CREATE DATABASE "QLogs" ENCODING = "UTF8";' `
            --command 'CREATE DATABASE "Licenses" ENCODING = "UTF8";' `
            --command "CREATE ROLE qliksenserepository WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION VALID UNTIL 'infinity'; " `
            --command "CREATE ROLE qlogs_users WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION VALID UNTIL 'infinity'; " `
            --command "CREATE ROLE qlogs_reader WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION VALID UNTIL 'infinity'; " `
            --command "CREATE ROLE qlogs_writer WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION VALID UNTIL 'infinity'; " `
            --command "ALTER ROLE qliksenserepository WITH ENCRYPTED PASSWORD '$pg_user_pwd';"  `
            --command "ALTER ROLE qlogs_reader WITH ENCRYPTED PASSWORD '$pg_user_pwd'; " `
            --command "ALTER ROLE qlogs_writer WITH ENCRYPTED PASSWORD '$pg_user_pwd'; " `
            --command 'GRANT qliksenserepository TO postgres;' `
            --command 'ALTER DATABASE QSR OWNER TO qliksenserepository;' `
            --command 'ALTER DATABASE SenseServices OWNER TO qliksenserepository;' `
            --command 'ALTER DATABASE QSMQ OWNER TO qliksenserepository;' `
            --command 'ALTER DATABASE Licenses OWNER TO qliksenserepository;' `
            --command 'GRANT TEMPORARY, CONNECT ON DATABASE "QSMQ" TO PUBLIC;' `
            --command 'GRANT ALL ON DATABASE "QSMQ" TO "postgres";' `
            --command 'GRANT CREATE ON DATABASE "QSMQ" TO "qliksenserepository";' `
            --command 'GRANT TEMPORARY, CONNECT ON DATABASE "SenseServices" TO PUBLIC;' `
            --command 'GRANT ALL ON DATABASE "SenseServices" TO "postgres";' `
            --command 'GRANT CREATE ON DATABASE "SenseServices" TO "qliksenserepository";' `
            --command 'GRANT TEMPORARY, CONNECT ON DATABASE "Licenses" TO PUBLIC;' `
            --command 'GRANT ALL ON DATABASE "Licenses" TO "postgres";' `
            --command 'GRANT CREATE ON DATABASE "Licenses" TO "qliksenserepository";' `
            --command 'GRANT "qlogs_users" TO "qlogs_reader";' `
            --command 'GRANT "qlogs_users" TO "qlogs_writer";' `
            --command 'ALTER DATABASE "QLogs" OWNER TO "qlogs_writer"; ' 

Set-Location -Path "$PSScriptRoot"

# Generate PostgreSQL config files
Invoke-Expression -Command """$PSScriptRoot\postgresql.conf.ps1 -NoOfNodes 4"""
Invoke-Expression -Command """$PSScriptRoot\pg_hba.conf.ps1"""

# Replace PostgreSQL config files
Move-Item -Path "$PostgresInstallPath\data\postgresql.conf" -Destination "$PostgresInstallPath\data\postgresql.conf.orig" -Force
Move-Item -Path "$PostgresInstallPath\data\pg_hba.conf"     -Destination "$PostgresInstallPath\data\pg_hba.conf.orig"     -Force
Copy-Item -Path "$PSScriptRoot\postgresql.conf" -Destination "$PostgresInstallPath\data\postgresql.conf" -Force
Copy-Item -Path "$PSScriptRoot\pg_hba.conf"     -Destination "$PostgresInstallPath\data\pg_hba.conf"     -Force

Stop-Transcript