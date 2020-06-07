#Requires -Version 5.0 -RunAsAdministrator

# Set execution location
if($PSScriptRoot -eq $null -or $PSScriptRoot -eq "") { 
    $ScriptLocation = (Get-Location).Path 
} else { 
    $ScriptLocation = $PSScriptRoot       
}

# Log script execution to trace/log file
Start-Transcript -Path "$ScriptLocation\$(split-path $PSCommandPath -Leaf)_$(get-date -format "ddMMyyyyHHmmss").log" -NoClobber

# Install Chocolatey Package manager
Invoke-Expression -Command "$ScriptLocation\..\Chocolatey\install-package-mngr.ps1"

# Secrets folder to store various serets in
$path_secrets   = "$ScriptLocation\..\.secrets"
$path_pg_super_pwd   = "$path_secrets\.pg_super_pwd"
$path_pg_user_pwd    = "$path_secrets\.pg_user_pwd"

# Password for postgres super user, and store to postgres.pwd
# Unless postgres.pwd already exists, then that password will be used
if (-Not [System.IO.File]::Exists($path_pg_super_pwd)) {
    add-type -AssemblyName System.Web
    [System.Web.Security.Membership]::GeneratePassword(16,0) | Out-File -FilePath "$path_pg_super_pwd" -NoNewline
}
if (-Not [System.IO.File]::Exists($path_pg_user_pwd)) {
    add-type -AssemblyName System.Web
    [System.Web.Security.Membership]::GeneratePassword(16,0) | Out-File -FilePath "$path_pg_user_pwd" -NoNewline
}

$pg_super_pwd = Get-Content -Path "$path_pg_super_pwd" -TotalCount 1
$pg_user_pwd  = Get-Content -Path "$path_pg_user_pwd" -TotalCount 1

# Install PostgreSQL 11 and PGAdmin through Chocolatey
choco install postgresql11 --package-parameters "/Password:$pg_super_pwd" --yes
choco install pgadmin4 --yes

# Configure PGPASSWORD to allow usage of PSQL.EXE
[System.Environment]::SetEnvironmentVariable("PGPASSWORD", "$pg_super_pwd", [System.EnvironmentVariableTarget]::User)

# Create databases and configure roles
# https://help.qlik.com/en-US/sense-admin/April2020/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Deploy_QSEoW/Installing-configuring-postgresql.htm
psql.exe --username=postgres --host localhost --port=5432 --no-password --echo-errors --echo-queries `
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

Stop-Transcript