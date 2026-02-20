param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$WindowsJumpClientCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$LinuxJumpClientCount,

    [Parameter(Mandatory = $true)]
    [ValidateSet('rhel-9.4', 'suse-15', 'ubuntu-24.04', 'debian-12', 'fedora-40')]
    [string]$LinuxDistro,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'manifest.json')
)

$ErrorActionPreference = 'Stop'
$tag = "run:$RunId"
$jumpGroup = "Lab/$RunId"

$items = [System.Collections.Generic.List[Object]]::new()

for ($i = 1; $i -le $WindowsJumpClientCount; $i++) {
    $items.Add([PSCustomObject]@{
            name       = "win-jump-client-{0:D2}" -f $i
            role       = 'jump-client'
            os         = 'windows'
            distro     = $null
            jumpGroup  = $jumpGroup
            tags       = @($tag, 'type:windows-client')
            adminUser  = 'LocalAdmin'
            modulePath = 'Terraform_templates/WindowsVMs_with_PublicIP'
        })
}

for ($i = 1; $i -le $LinuxJumpClientCount; $i++) {
    $items.Add([PSCustomObject]@{
            name       = "linux-jump-client-{0:D2}" -f $i
            role       = 'jump-client'
            os         = 'linux'
            distro     = $LinuxDistro
            jumpGroup  = $jumpGroup
            tags       = @($tag, 'type:linux-client')
            adminUser  = 'LocalAdmin'
            modulePath = 'Terraform_templates/LinuxVMs_with_PublicIP'
        })
}

# Ensure one Jumpoint host placeholder exists for API orchestration visibility.
$items.Add([PSCustomObject]@{
        name       = 'jumpoint-01'
        role       = 'jumpoint'
        os         = 'windows'
        distro     = $null
        jumpGroup  = $jumpGroup
        tags       = @($tag, 'type:jumpoint')
        adminUser  = 'LocalAdmin'
        modulePath = 'Terraform_templates/WindowsVMs_with_PublicIP'
    })

$manifest = [PSCustomObject]@{
    runId          = $RunId
    jumpGroup      = $jumpGroup
    tag            = $tag
    createdUtc     = (Get-Date).ToUniversalTime().ToString('o')
    vnetResourceGroup = 'rg_sandbox_north_network'
    vnetName       = 'vnet_sandbox_north'
    items          = $items
}

$manifestDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($manifestDir)) {
    New-Item -Path $manifestDir -ItemType Directory -Force | Out-Null
}

$manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Manifest generated successfully: $OutputPath"
