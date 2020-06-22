#Requires -Version 5.0 -RunAsAdministrator

param (
    [Parameter()]
    [ValidateSet("postgresql9", "postgresql11")]
    [string] $Release = "postgresql11", 
    [Parameter()]
    [Int] $QlikSenseNodes = 1,
    [Parameter(Mandatory=$false)]
    [Switch] $DummyPassword,
    [Parameter(Mandatory=$true)]
    [String] $ServiceAccount  
)

# Break on any error
$ErrorActionPreference = "Stop"

# Common folder paths
$path_logs    = "$PSScriptRoot\..\.logs"
$path_secrets = "$PSScriptRoot\..\.secrets"
$path_install = "$PSScriptRoot\..\.install-share"      

# Log script execution to trace/log file
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

# Create folders if missing
if(-Not (Test-Path "$path_logs"))    { New-Item -Type Directory -Path "$path_logs" -Force    }
if(-Not (Test-Path "$path_secrets")) { New-Item -Type Directory -Path "$path_secrets" -Force }  
if(-Not (Test-Path "$path_install")) { New-Item -Type Directory -Path "$path_install" -Force }

# Install fileshare first, if it fails no need ot install DB
$SmbRootDir     = Invoke-Expression -Command """$PSScriptRoot\smb-fileshare-create.ps1 -ServiceAccount $ServiceAccount""" 

# Install PostgreSQL
Invoke-Expression -Command """$PSScriptRoot\postgresql-install.ps1 -Release $Release -QlikSenseNodes $QlikSenseNodes $(if($DummyPassword){ "-Dummypassword" })""" 

$DbUserPassword = Get-Content -Path "$path_secrets\.pg_user_pwd"
$DbHost         = "$env:COMPUTERNAME.$env:UserDnsDomain"
$DbPort         = "5432"

# Central node installation config file
@"
<?xml version="1.0"?>
<SharedPersistenceConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <DbUserName>qliksenserepository</DbUserName>
    <DbUserPassword>$DbUserPassword</DbUserPassword>
    <DbHost>$DbHost</DbHost>
    <DbPort>$DbPort</DbPort>
    <RootDir>$SmbRootDir</RootDir>
    <StaticContentRootDir>$SmbRootDir\StaticContent</StaticContentRootDir>
    <ArchivedLogsDir>$SmbRootDir\ArchivedLogs</ArchivedLogsDir>
    <AppsDir>$SmbRootDir\Apps</AppsDir>
    <CreateCluster>true</CreateCluster>
    <InstallLocalDb>false</InstallLocalDb>
    <ConfigureLogging>true</ConfigureLogging>
    <SetupLocalLoggingDb>false</SetupLocalLoggingDb>
    <QLogsWriterPassword>$DbUserPassword</QLogsWriterPassword>
    <QLogsReaderPassword>$DbUserPassword</QLogsReaderPassword>
    <QLogsHostname>$DbHost</QLogsHostname>
    <QLogsPort>$DbPort</QLogsPort>
</SharedPersistenceConfiguration>
"@ | Out-File -FilePath "$path_install\qseow-spc-central-node.xml" -Encoding ASCII -Force

# Rim node config file
@"
<?xml version="1.0"?>
<SharedPersistenceConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <DbUserName>qliksenserepository</DbUserName>
    <DbUserPassword>$DbUserPassword</DbUserPassword>
    <DbHost>$DbHost</DbHost>
    <DbPort>$DbPort</DbPort>
    <RootDir>$SmbRootDir</RootDir>
    <StaticContentRootDir>$SmbRootDir\StaticContent</StaticContentRootDir>
    <ArchivedLogsDir>$SmbRootDir\ArchivedLogs</ArchivedLogsDir>
    <AppsDir>$SmbRootDir\Apps</AppsDir>
    <JoinCluster>true</JoinCluster>
</SharedPersistenceConfiguration>
"@ | Out-File -FilePath "$path_install\qseow-spc-rim-node.xml" -Encoding ASCII -Force

Stop-Transcript