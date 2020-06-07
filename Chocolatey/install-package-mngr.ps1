#Requires -Version 5.0 -RunAsAdministrator

try {

    # Attempt Chocolatey upgrade
    # If fails, it has not yet been installed
    choco upgrade chocolatey --yes

} catch {

    # Install Chocolatey Package manager
    # Reference: https://chocolatey.org/install

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')

}

