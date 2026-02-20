param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ManifestPath = (Join-Path $PSScriptRoot 'manifest.json'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 4,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$RetryDelaySeconds = 3
)

$ErrorActionPreference = 'Stop'

function Invoke-PraApiWithRetry {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Get', 'Post', 'Delete', 'Put', 'Patch')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $false)][hashtable]$Headers,
        [Parameter(Mandatory = $false)]$Body,
        [Parameter(Mandatory = $true)][int]$Attempts,
        [Parameter(Mandatory = $true)][int]$DelaySeconds,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            $invokeParams = @{
                Method = $Method
                Uri    = $Uri
            }

            if ($Headers) {
                $invokeParams.Headers = $Headers
            }

            if ($PSBoundParameters.ContainsKey('Body')) {
                if ($Body -is [string]) {
                    $invokeParams.Body = $Body
                    $invokeParams.ContentType = 'application/x-www-form-urlencoded'
                }
                else {
                    $invokeParams.Body = ($Body | ConvertTo-Json -Depth 20)
                    $invokeParams.ContentType = 'application/json'
                }
            }

            return Invoke-RestMethod @invokeParams
        }
        catch {
            if ($attempt -eq $Attempts) {
                throw "[PRA API] $Operation failed after $Attempts attempt(s). $($_.Exception.Message)"
            }

            Write-Warning "[PRA API] $Operation failed on attempt $attempt/$Attempts. Retrying in $DelaySeconds second(s). Error: $($_.Exception.Message)"
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Get-PraAccessToken {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][string]$ClientSecret,
        [Parameter(Mandatory = $true)][int]$Attempts,
        [Parameter(Mandatory = $true)][int]$DelaySeconds
    )

    $tokenUri = "$BaseUrl/oauth2/token"
    Write-Host "Requesting OAuth token from $tokenUri"

    $body = @{ 
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $response = Invoke-PraApiWithRetry -Method Post -Uri $tokenUri -Body $body -Attempts $Attempts -DelaySeconds $DelaySeconds -Operation 'Get OAuth token'

    if (-not $response.access_token) {
        throw 'PRA token response did not include access_token.'
    }

    return $response.access_token
}

function ConvertTo-ObjectArray {
    param([Parameter(Mandatory = $false)]$Response)

    if ($null -eq $Response) { return @() }
    if ($Response -is [System.Array]) { return $Response }
    if ($Response.items) { return @($Response.items) }
    return @($Response)
}

function Get-PraSingleObjectByName {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$ObjectType,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Attempts,
        [Parameter(Mandatory = $true)][int]$DelaySeconds
    )

    $filter = [System.Uri]::EscapeDataString("name:$Name")
    $uri = "$BaseUrl/api/config/v1/$ObjectType?filter=$filter"
    $response = Invoke-PraApiWithRetry -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $Token" } -Attempts $Attempts -DelaySeconds $DelaySeconds -Operation "Get $ObjectType by name '$Name'"

    $items = ConvertTo-ObjectArray -Response $response | Where-Object { $_.name -eq $Name }

    if ($items.Count -eq 0) {
        throw "Could not find PRA $ObjectType named '$Name'."
    }

    return $items[0]
}

function New-PraJumpShortcut {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [Parameter(Mandatory = $true)][hashtable]$Payload,
        [Parameter(Mandatory = $true)][string]$ShortcutName,
        [Parameter(Mandatory = $true)][int]$Attempts,
        [Parameter(Mandatory = $true)][int]$DelaySeconds
    )

    $uri = "$BaseUrl/api/config/v1/$Endpoint"
    Invoke-PraApiWithRetry -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $Token" } -Body $Payload -Attempts $Attempts -DelaySeconds $DelaySeconds -Operation "Create $Endpoint '$ShortcutName'" | Out-Null
    Write-Host "[Create] Created $Endpoint '$ShortcutName'"
}

if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
    throw "Manifest file not found: $ManifestPath"
}

$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
$runId = $manifest.runId
$jumpGroupName = $manifest.jumpGroup

if (-not $runId) {
    throw "manifest.json does not contain 'runId'."
}

if (-not $jumpGroupName) {
    throw "manifest.json does not contain 'jumpGroup'."
}

$baseUrl = $env:PRA_BASE_URL
$clientId = $env:PRA_CLIENT_ID
$clientSecret = $env:PRA_CLIENT_SECRET

if (-not $baseUrl -or -not $clientId -or -not $clientSecret) {
    throw 'PRA_BASE_URL, PRA_CLIENT_ID and PRA_CLIENT_SECRET environment variables are required.'
}

$tag = "run:$runId"
$token = Get-PraAccessToken -BaseUrl $baseUrl -ClientId $clientId -ClientSecret $clientSecret -Attempts $MaxRetries -DelaySeconds $RetryDelaySeconds

$jumpGroup = Get-PraSingleObjectByName -BaseUrl $baseUrl -Token $token -ObjectType 'jump-group' -Name $jumpGroupName -Attempts $MaxRetries -DelaySeconds $RetryDelaySeconds
$jumpointManifestItem = @($manifest.items | Where-Object { $_.role -eq 'jumpoint' }) | Select-Object -First 1
if (-not $jumpointManifestItem) {
    throw "manifest.json does not contain an item with role 'jumpoint'."
}
$jumpoint = Get-PraSingleObjectByName -BaseUrl $baseUrl -Token $token -ObjectType 'jumpoint' -Name $jumpointManifestItem.name -Attempts $MaxRetries -DelaySeconds $RetryDelaySeconds

$linuxItems = @($manifest.items | Where-Object { $_.os -eq 'linux' -and $_.role -ne 'jumpoint' })
$windowsItems = @($manifest.items | Where-Object { $_.os -eq 'windows' -and $_.role -ne 'jumpoint' })

foreach ($item in $linuxItems) {
    $privateIp = $item.privateIp
    if (-not $privateIp) {
        $privateIp = $item.private_ip
    }

    if (-not $privateIp) {
        throw "Linux manifest item '$($item.name)' is missing 'privateIp' (or 'private_ip')."
    }

    $shellName = "$($item.name)-ssh"
    $shellPayload = @{
        name          = $shellName
        hostname      = $privateIp
        port          = 22
        protocol      = 'ssh'
        jump_group_id = $jumpGroup.id
        jumpoint_id   = $jumpoint.id
        tags          = @($tag)
    }

    New-PraJumpShortcut -BaseUrl $baseUrl -Token $token -Endpoint 'shell-jump' -Payload $shellPayload -ShortcutName $shellName -Attempts $MaxRetries -DelaySeconds $RetryDelaySeconds

    if ($item.gui -eq $true) {
        $vncName = "$($item.name)-vnc"
        $vncPayload = @{
            name          = $vncName
            hostname      = $privateIp
            port          = 5900
            protocol      = 'vnc'
            jump_group_id = $jumpGroup.id
            jumpoint_id   = $jumpoint.id
            tags          = @($tag)
        }

        New-PraJumpShortcut -BaseUrl $baseUrl -Token $token -Endpoint 'remote-jump' -Payload $vncPayload -ShortcutName $vncName -Attempts $MaxRetries -DelaySeconds $RetryDelaySeconds
    }
}

foreach ($item in $windowsItems) {
    $privateIp = $item.privateIp
    if (-not $privateIp) {
        $privateIp = $item.private_ip
    }

    if (-not $privateIp) {
        throw "Windows manifest item '$($item.name)' is missing 'privateIp' (or 'private_ip')."
    }

    $rdpName = "$($item.name)-rdp"
    $rdpPayload = @{
        name          = $rdpName
        hostname      = $privateIp
        port          = 3389
        protocol      = 'rdp'
        jump_group_id = $jumpGroup.id
        jumpoint_id   = $jumpoint.id
        tags          = @($tag)
    }

    New-PraJumpShortcut -BaseUrl $baseUrl -Token $token -Endpoint 'remote-jump' -Payload $rdpPayload -ShortcutName $rdpName -Attempts $MaxRetries -DelaySeconds $RetryDelaySeconds
}

Write-Host "Shortcut creation complete. Linux SSH: $($linuxItems.Count), Windows RDP: $($windowsItems.Count)."
