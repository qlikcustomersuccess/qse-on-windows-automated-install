<#
    .SYNOPSIS
    Helper script to genrate dynamic postgresql.conf file

    .DESCRIPTION
    Helper script to genrate dynamic postgresql.conf file

    .PARAMETER  NoOfNodes
    Number of Qlik Sense nodes that will communicate with the PostgreSQL databse instance. This details is used to adjust the max_connections values for multi node deployments. Default value is 1. 

    .PARAMETER  port
    Listening port for database server. Default value is 5432.

    .EXAMPLE
    C:\PS> .\postgresql.conf.ps1

    .EXAMPLE
    C:\PS> .\postgresql.conf.ps1 -Port 4432

    .EXAMPLE
    C:\PS> .\postgresql.conf.ps1 -NoOfNodes 4

    .NOTES
    Copyright (c) 2020. This script is provided "AS IS", without any warranty, under the MIT License.     
#>

param (
    [Parameter()]
    [Int] $NoOfNodes = 1,
    [Parameter()]
    [Int] $port = 5432 
)

# Log script execution to trace/log file
$path_logs          = "$PSScriptRoot\..\.logs"
Start-Transcript -Path "$path_logs\$(split-path $PSCommandPath -Leaf)_$(get-date -format "yyyyddMM_HHmmss").log" -NoClobber

@"
/*************************************************
**              postgresql.conf
*************************************************/
listen_addresses = '*'	
port = $port				

max_connections = $($NoOfNodes * 100)
shared_buffers = 128MB			

dynamic_shared_memory_type = windows	

max_wal_size = 1GB
min_wal_size = 80MB

log_destination = 'stderr'	
logging_collector = on		
log_file_mode = 0640		

log_timezone = 'CET'

datestyle = 'iso, mdy'
timezone  = 'CET'

lc_messages = 'English_United States.1252'		
lc_monetary = 'English_United States.1252'		
lc_numeric  = 'English_United States.1252'		
lc_time     = 'English_United States.1252'			

default_text_search_config = 'pg_catalog.english'
"@ | Out-File -FilePath "$PSScriptRoot\postgresql.conf"


Get-Content -PAth "$PSScriptRoot\postgresql.conf" | Write-Host -ForegroundColor Gray

Stop-Transcript