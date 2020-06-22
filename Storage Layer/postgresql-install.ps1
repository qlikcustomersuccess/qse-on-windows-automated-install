#Requires -Version 5.0 -RunAsAdministrator

<#
    .SYNOPSIS
    Automated install of PostgreSQL database server for use as Qlik Sense Repository database

    .DESCRIPTION
    PostgreSQL database server is installed on Windows server. Internet access and Local Administrator 
    right are required for the executing user, as Chocolately package manager is utilized to download 
    and install PostgreSQL server and PgAdmin. 

    After installation databases and roles are configured to match Qlik Sense Enterprise requirements. 
    Additionally, custom PostgreSQL config files are generated, so that database server can be accessed 
    by all Qlik Sense nodes and manage the expected workload. 

    Custom configuration is controlled through template files pg_hba11.tmp.conf and postgresql11.tmp.conf, 
    which are invoked as expressions during execution to generated variable controlled content. 

    Database passwords are generated during installation. One password is created for the database server 
    super user (postgres), and one password is created for the database users. The passwords are stored in 
    .secrets folder in the files .pg_super_pwd and .pg_user_pwd. 
    Custom passwords can be applied by addind .pg_super_pwd and .pg_user_pwd plain text password files to 
    .secrets folder prior to executing installation. 
    For test instances in isolated environments, -DummyPassword flag enables simple generation of a 
    generic dummy password. 

    .PARAMETER  DummyPassword
    Flag to genrated dummy password (Password123!) for both super user and database users. 
    By default random passwords are generated.

    .PARAMETER  NoPgAdmin
    Flag to skip installation of PgAdmin. 
    By default PgAdmin is installed.

    .PARAMETER Port
    Listening port for PostgreSQL database server. 
    Default 5432.

    .PARAMETER  QlikSenseNodes
    Number of Qlik Sense nodes that will connect to PostgreSQL database server instance. This value is 
    used to adjust PostgreSQL configuration to fit the expected connection volume. 
    Default value is 1.

    .PARAMETER  Release
    Defines the PostgreSQL major version to be installed. Currently supported values match version 
    supported by Qlik Sense on Windows as repository database. Parameter value is defined as the Chocolatey 
    package names postgresql9 or postgresql11. The actually installed version will be the latest minpr 
    version available through Chocolatey. 
    Default value is postgresql11.

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1
    Installs PostgreSQL 11.x server listening on port 5432. User passwords are random. 

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -DummyPassword
    Installs PostgreSQL 11.x server listening on port 5432. User passwords are set to Password123!

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -release "postgresql9"
    Installs PostgreSQL 9.6.x server listening on port 5432. User passwords are random. 

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -release "postgresql9" -DummyPassword
    Installs PostgreSQL 9.6.x server listening on port 5432. User passwords are set to Password123!

    .EXAMPLE
    C:\PS> .\postgresql-install.ps1 -QlikSenseNodes 4 -DummyPassword
    Installs PostgreSQL 11.x server listening on port 5432. User passwords are set to Password123!
    PostgreSQL configuration is adjusted for multi-node deployment, with 4 Qlik Sense nodes. 

    .NOTES
    Copyright (c) 2020. This script is provided "AS IS", without any warranty, under the MIT License.     
#>

param (
    [Parameter()]
    [ValidateSet("postgresql9", "postgresql11")]
    [string] $Release = "postgresql11", 
    [Parameter()]
    [Int] $QlikSenseNodes = 1,
    [Parameter()]
    [Int] $Port = 5432,
    [Parameter(Mandatory=$false)]
    [Switch] $DummyPassword,
    [Parameter(Mandatory=$false)]
    [Switch] $NoPgAdmin
)

# Break on any error
$ErrorActionPreference = "Stop"

# Common folder paths
$path_logs    = "$PSScriptRoot\..\.logs"
$path_secrets = "$PSScriptRoot\..\.secrets"

# Create folders if missing
if(-Not (Test-Path "$path_logs"))    { New-Item -Type Directory -Path "$path_logs" -Force    }
if(-Not (Test-Path "$path_secrets")) { New-Item -Type Directory -Path "$path_secrets" -Force }  

# Common file paths
$path_pg_super_pwd = "$path_secrets\.pg_super_pwd"
$path_pg_user_pwd  = "$path_secrets\.pg_user_pwd"

if($Release -eq "postgresql11") { 
    $PostgresInstallPath = "$env:ProgramFiles\PostgreSQL\11"  
} else { 
    $PostgresInstallPath = "$env:ProgramFiles\PostgreSQL\9.6" 
}    
$PostgreSqlData = "$PostgresInstallPath\data"
$PostgreSqlBin  = "$PostgresInstallPath\bin"

# Log script execution to trace/log file
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

# Install Chocolatey based on Gist snippet
. "https://gist.githubusercontent.com/tonikautto/66b6913fc476ef77ea8b452a0936e7a6/raw/5fb744f41a230efde45b0567516dfc2ead5a7e27/chocolatey-install.ps1"

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
If(!$NoPgAdmin) {
    choco install pgadmin4 --yes
}    

# Configure PostgreSQL environment variables 
# Refresh variable in current temrinal session
[System.Environment]::SetEnvironmentVariable("PGPASSWORD", "$pg_super_pwd", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable("PGDATA", "$PostgreSqlData", [System.EnvironmentVariableTarget]::User)
$env:PGPASSWORD = [System.Environment]::GetEnvironmentVariable("PGPASSWORD","User")
$env:PGDATA     = [System.Environment]::GetEnvironmentVariable("PGDATA","User")

# Create databases and configure roles
# https://help.qlik.com/en-US/sense-admin/April2020/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Deploy_QSEoW/Installing-configuring-postgresql.htm

try {
    & "$PostgreSqlBin\psql.exe" --username=postgres --host localhost --port=5432 --no-password --echo-errors --echo-queries `
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
    Write-Host "PostgreSQL content has been created. " -ForegroundColor Green
} catch {
    Write-Host "PostgreSQL content creation could not be finished. It may already exist." -ForegroundColor Magenta
}

# Stop PostgreSQL server
try {
    Get-Service | Where-Object { $_.Name -like "postgresql*" } | Stop-Service
    Write-Host "PostgreSQL has been stopped." -ForegroundColor Green
} catch {
    Write-Host "PostgreSQL can not be stopped. It may already be stopped." -ForegroundColor Magenta
}

# Safe copies of PostgreSQL config files, unless already exist
if (-Not [System.IO.File]::Exists("$PostgreSqlData\postgresql.conf.orig")) {
    Copy-Item -Path "$PostgreSqlData\postgresql.conf" -Destination "$PostgreSqlData\postgresql.conf.orig" -Force
}
if (-Not [System.IO.File]::Exists("$PostgreSqlData\pg_hba.conf.orig")) {
    Copy-Item -Path "$PostgreSqlData\pg_hba.conf"     -Destination "$PostgreSqlData\pg_hba.conf.orig" -Force
}    


# Generate config files from templates, and store to PostgreSQL data folder
# Replace linebreask, to make readable in Notepad
Invoke-Expression "@`"`r`n$((Get-Content "$PSScriptRoot\pg_hba11.tmp.conf" -Raw).Replace("`n", "`r`n"))`r`n`"@" | `
Out-File -FilePath "$PostgreSqlData\pg_hba.conf" -Encoding ASCII -Force

Invoke-Expression "@`"`r`n$((Get-Content "$PSScriptRoot\postgresql11.tmp.conf" -Raw).Replace("`n", "`r`n"))`r`n`"@" | `
Out-File -FilePath "$PostgreSqlData\postgresql.conf" -Encoding ASCII -Force

# Start PostgreSQL server
try {
    Get-Service | Where-Object { $_.Name -like "postgresql*" } | Start-Service    
    Write-Host "PostgreSQL has started." -ForegroundColor Green
} catch {
    Write-Host "PostgreSQL can not be started. Config files may be incorrect." -ForegroundColor Magenta
}

Write-Host "$Release has been successfully installed on port $Port" -ForegroundColor Green
Write-Host "and configured for $QlikSenseNodes Qlik Sense node(s)." -ForegroundColor Green
Write-Host "See password files for super user and database user passwords:" -ForegroundColor Green
Write-Host "$path_pg_super_pwd `n$path_pg_user_pwd" -ForegroundColor Yellow

Stop-Transcript