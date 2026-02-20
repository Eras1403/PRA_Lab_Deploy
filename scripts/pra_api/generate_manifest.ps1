param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$WindowsJumpClientCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$RhelCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$SuseCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$UbuntuCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$DebianCount,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 500)]
    [int]$FedoraCount,

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

function Add-LinuxJumpClients {
    param(
        [Parameter(Mandatory = $true)][string]$Distro,
        [Parameter(Mandatory = $true)][int]$Count,
        [Parameter(Mandatory = $true)][string]$NamePrefix
    )

    if ($Count -le 0) {
        return
    }

    for ($i = 1; $i -le $Count; $i++) {
        $items.Add([PSCustomObject]@{
                name       = "$NamePrefix-{0:D2}" -f $i
                role       = 'jump-client'
                os         = 'linux'
                distro     = $Distro
                jumpGroup  = $jumpGroup
                tags       = @($tag, 'type:linux-client')
                adminUser  = 'LocalAdmin'
                modulePath = 'Terraform_templates/LinuxVMs_with_PublicIP'
            })
    }
}

Add-LinuxJumpClients -Distro 'rhel-9.4' -Count $RhelCount -NamePrefix 'rhel-jump-client'
Add-LinuxJumpClients -Distro 'suse-15' -Count $SuseCount -NamePrefix 'suse-jump-client'
Add-LinuxJumpClients -Distro 'ubuntu-24.04' -Count $UbuntuCount -NamePrefix 'ubuntu-jump-client'
Add-LinuxJumpClients -Distro 'debian-12' -Count $DebianCount -NamePrefix 'debian-jump-client'
Add-LinuxJumpClients -Distro 'fedora-40' -Count $FedoraCount -NamePrefix 'fedora-jump-client'

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
