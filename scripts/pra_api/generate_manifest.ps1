<#
.SYNOPSIS
Generiert ein standardisiertes Deployment-Manifest aus einer Matrix-Definition.

.DESCRIPTION
Die Matrix beschreibt gewünschte Serverrollen (z. B. Jumpoint, Targets), Betriebssystem,
Anzahl und optionale Features (Client-Installation, Shortcut-Erzeugung). Das Skript
validiert diese Eingaben streng und erzeugt daraus eine normalisierte manifest.json,
die in nachgelagerten Pipeline-Schritten verwendet wird.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DeploymentMatrixJson,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'manifest.json')
)

$ErrorActionPreference = 'Stop'

# Der Manifestgenerator ist die zentrale Quelle für konsistente Deployments:
# Er normalisiert Eingaben, ergänzt sinnvolle Defaults und erzwingt
# Mindestanforderungen (z. B. mindestens ein Jumpoint).
$tag = "run:$RunId"
$jumpGroup = "Lab/$RunId"

try {
    $deploymentMatrix = @($DeploymentMatrixJson | ConvertFrom-Json)
}
catch {
    throw "DeploymentMatrixJson is not valid JSON. $($_.Exception.Message)"
}

if ($deploymentMatrix.Count -eq 0) {
    throw 'Deployment matrix must contain at least one definition.'
}

$items = [System.Collections.Generic.List[Object]]::new()
$totalRequestedServers = 0

foreach ($definition in $deploymentMatrix) {
    if (-not $definition.name_prefix) {
        throw "Every matrix definition requires 'name_prefix'."
    }

    if (-not $definition.os) {
        throw "Matrix definition '$($definition.name_prefix)' requires 'os'."
    }

    if (-not $definition.role) {
        throw "Matrix definition '$($definition.name_prefix)' requires 'role'."
    }

    if ($null -eq $definition.count) {
        throw "Matrix definition '$($definition.name_prefix)' requires 'count'."
    }

    $count = [int]$definition.count
    if ($count -lt 0) {
        throw "Matrix definition '$($definition.name_prefix)' has invalid count '$count'."
    }

    $normalizedOs = $definition.os.ToString().ToLowerInvariant()
    if ($normalizedOs -notin @('windows', 'linux')) {
        throw "Matrix definition '$($definition.name_prefix)' has unsupported os '$($definition.os)'."
    }

    $installClient = $definition.install_client -eq $true
    $asJumpoint = $definition.as_jumpoint -eq $true
    $createShortcut = $definition.create_shortcut -eq $true

    if ($createShortcut -and [string]::IsNullOrWhiteSpace($definition.protocol)) {
        throw "Matrix definition '$($definition.name_prefix)' has create_shortcut=true but no protocol."
    }

    $protocol = $null
    if (-not [string]::IsNullOrWhiteSpace($definition.protocol)) {
        $protocol = $definition.protocol
    }

    $modulePath = $definition.module_path
    if ([string]::IsNullOrWhiteSpace($modulePath)) {
        if ($normalizedOs -eq 'windows') {
            $modulePath = 'Terraform_templates/WindowsVMs_with_PublicIP'
        }
        else {
            $modulePath = 'Terraform_templates/LinuxVMs_with_PublicIP'
        }
    }

    $adminUser = $definition.admin_user
    if ([string]::IsNullOrWhiteSpace($adminUser)) {
        $adminUser = 'LocalAdmin'
    }

    for ($i = 1; $i -le $count; $i++) {
        $name = "$($definition.name_prefix)-{0:D2}" -f $i
        $role = $definition.role.ToString()

        $items.Add([PSCustomObject]@{
                name            = $name
                role            = $role
                os              = $normalizedOs
                distro          = $definition.distro
                jumpGroup       = $jumpGroup
                tags            = @($tag, "type:$($normalizedOs)-$role")
                adminUser       = $adminUser
                install_client  = $installClient
                as_jumpoint     = $asJumpoint
                create_shortcut = $createShortcut
                protocol        = $protocol
                modulePath      = $modulePath
            })
    }

    $totalRequestedServers += $count
}

if ($totalRequestedServers -eq 0) {
    throw 'At least one matrix entry must have count > 0. Empty deployments are not allowed.'
}

if (@($items | Where-Object { $_.as_jumpoint -eq $true -or $_.role -eq 'jumpoint' }).Count -eq 0) {
    throw "Deployment matrix must include at least one jumpoint item (role='jumpoint' or as_jumpoint=true)."
}

$manifest = [PSCustomObject]@{
    runId             = $RunId
    jumpGroup         = $jumpGroup
    tag               = $tag
    createdUtc        = (Get-Date).ToUniversalTime().ToString('o')
    vnetResourceGroup = 'rg_sandbox_north_network'
    vnetName          = 'vnet_sandbox_north'
    items             = $items
}

$manifestDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($manifestDir)) {
    New-Item -Path $manifestDir -ItemType Directory -Force | Out-Null
}

$manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Manifest generated successfully: $OutputPath"
