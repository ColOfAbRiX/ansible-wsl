#
# Starts the configuration of WSL
# MUST run from the root of the repository with .\scripts\wsl\install_wsl.ps1
#

Param(
    [Switch]$SkipDependencies,
    [Switch]$SkipSecrets,
    [Switch]$SkipCoreConfig,
    [Switch]$SkipMainConfig
)

# Load settings
$configPath = Join-Path $PSScriptRoot "settings.conf"
$configContent = Get-Content -Path $configPath | ForEach-Object { $_ -replace '"', '' }
$config = $configContent | ConvertFrom-StringData
$ansibleRepoPath = $config.ANSIBLE_REPO_PATH

# Setting permissions for this script
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Ask the user what distribution to use
do
{
    # I have no idea how to write this better in PowerShell. But it gets the job done :P
    $choices = wsl --list | Select-Object -Skip 1 | Where-Object {$_.trim() -ne ""}
    $choices = $choices -replace "(.)\0", '$1' -replace "\(Default\)","" -replace "(^\W+|\W+$)",""
    if ($choices.Count -eq 1)
    {
        $distribution = $choices | Select-Object -first 1
        break
    }
    $choices = $choices | ForEach-Object {$_.ToString().ToLower().Trim()} | Out-String -Stream

    wsl --list
    Write-Host -nonewline "`nInsert the name of the distribution you want to configure (empty for default): "
    $distribution = (Read-Host).Trim().ToLower()

    if ($distribution -eq "") {
        $distribution = $choices | Select-Object -first 1
    }

    $ok = $choices -contains $distribution -or $distribution -eq ""
    if (-not $ok)
    {
        Write-Host "Invalid selection"
        Write-Host ""
    }
} until ($ok)

# #  Prerequisites  # #

# Fixing file permissions issue with initial FS configuration
Write-Host "`nFixing file permissions issue with initial FS configuration"
wsl -d "$distribution" -u root grep -q automount /etc/wsl.conf
if (!$?)
{
    Write-Host "    Updating wsl.conf options"
    wsl -d "$distribution" -u root echo "[automount]`nenabled = true`noptions = metadata,umask=22,fmask=11" `>> /etc/wsl.conf
    wsl --terminate "$distribution"
}

# Install Dependencies
if (-not $SkipDependencies)
{
    Write-Host "`nInstalling system dependencies"
    wsl -d "$distribution" -u root ./scripts/install_dependencies.sh
    if (!$?)
    {
        Write-Host "ERROR: Couldn't install dependencies"
        exit 1
    }
}

# Initialize repository
Write-Host "`nInitializing repository in WSL"
wsl -d "$distribution" ./scripts/init_repo.sh
if (!$?)
{
    Write-Host "ERROR: Couldn't initialize repository"
    exit 1
}

# Initialize repository
if (-not $SkipSecrets)
{
    Write-Host "`nInitializing repository secrets"
    wsl -d "$distribution" ./scripts/setup_secrets.py
    if (!$?)
    {
        Write-Host "ERROR: Couldn't initialize repository secrets"
        exit 1
    }
}

# # #  Initial configuration  # #

# Run core WSL configuration
if (-not $SkipCoreConfig)
{
    Write-Host "`nRun core WSL configuration"
    wsl -d "$distribution" $ansibleRepoPath/scripts/start_ansible.sh playbook.yml -t wsl-config
    if (!$?)
    {
        Write-Host "ERROR: Core configuration of WSL failed"
        exit 1
    }

    Write-Host "`nRestart WSL"
    wsl --terminate "$distribution"
    if (!$?)
    {
        Write-Host "ERROR: Restart of WSL failed"
        exit 1
    }
}

# # #  Full configuration  # #

# # Registering WSL startup services
# $registryPath = "HKCU:Software\Microsoft\Windows\CurrentVersion\Run"
# $name = "WSL Services $distribution"
# $value = "`"C:\Windows\System32\wsl.exe`" -d $distribution -u root /etc/wsl-services-init 3"
# If (-NOT (Test-Path $registryPath)) {
#     New-Item $registryPath | Out-Null
# }
# New-ItemProperty -Path $registryPath `
#     -Name $name `
#     -Value $value `
#     -PropertyType ExpandString `
#     -Force | Out-Null
# New-Item -ItemType Directory `
#     -Force `
#     -Path "$env:APPDATA\WSLServices" | Out-Null

# Run the environment WSL configuration
if (-not $SkipMainConfig)
{
    Write-Host "`nRun the environment WSL configuration"
    wsl -d "$distribution" $ansibleRepoPath/scripts/start_ansible.sh playbook.yml --skip-tags wsl-win-integration
    if (!$?)
    {
        Write-Host "ERROR: Environment configuration of WSL failed"
        exit 1
    }

    # Last restart of WSL
    Write-Host "`nRestart WSL"
    wsl --terminate "$distribution"
    if (!$?)
    {
        Write-Host "ERROR: Restart of WSL failed"
        exit 1
    }
}
