<#
.SYNOPSIS
Validiert, dass die erwartete Anzahl Jump Clients für einen Run online ist.

.DESCRIPTION
Das Skript pollt die PRA-API bis zur konfigurierten Zeitgrenze. Als Filter wird der
Tag "run:<RunId>" verwendet, wodurch nur Objekte des aktuellen Deployments erfasst
werden. Die Soll-Anzahl kann direkt übergeben oder aus einer Manifest-Datei
abgeleitet werden.

Wichtig:
- API-Zugangsdaten werden ausschließlich über Umgebungsvariablen gelesen.
- Bei Timeout wird mit klarer Fehlernachricht abgebrochen.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$ExpectedClients,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ManifestPath = (Join-Path $PSScriptRoot 'manifest.json'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 120)]
    [int]$TimeoutMinutes = 20,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 300)]
    [int]$PollSeconds = 30
)

$ErrorActionPreference = 'Stop'

# Holt ein OAuth2 Access Token via Client-Credentials-Flow.
# Das Token wird für alle Folgeaufrufe gegen /api/config/v1 benötigt.
function Get-PraAccessToken {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][string]$ClientSecret
    )

    $tokenUri = "$BaseUrl/oauth2/token"
    Write-Host "Requesting OAuth token from $tokenUri"

    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $response = Invoke-RestMethod -Method Post -Uri $tokenUri -Body $body -ContentType 'application/x-www-form-urlencoded'

    if (-not $response.access_token) {
        throw 'PRA token response did not include access_token.'
    }

    return $response.access_token
}

# Liest alle Jump Clients mit dem angegebenen Tag und zählt jene, die
# anhand bekannter Felder als online interpretierbar sind.
function Get-OnlineClientCount {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    $encodedFilter = [System.Uri]::EscapeDataString("tag:$Tag")
    $uri = "$BaseUrl/api/config/v1/jump-client?filter=$encodedFilter"
    Write-Host "Polling PRA API endpoint: $uri"

    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $Token" }

    $clients = if ($response -is [System.Array]) {
        $response
    }
    elseif ($response.items) {
        @($response.items)
    }
    elseif ($null -eq $response) {
        @()
    }
    else {
        @($response)
    }

    $onlineClients = $clients | Where-Object {
        $_.is_online -eq $true -or $_.online -eq $true -or $_.status -eq 'online'
    }

    return ($onlineClients | Measure-Object).Count
}

$baseUrl = $env:PRA_BASE_URL
$clientId = $env:PRA_CLIENT_ID
$clientSecret = $env:PRA_CLIENT_SECRET

if (-not $baseUrl -or -not $clientId -or -not $clientSecret) {
    throw 'PRA_BASE_URL, PRA_CLIENT_ID and PRA_CLIENT_SECRET environment variables are required.'
}

$tag = "run:$RunId"
if (-not $PSBoundParameters.ContainsKey('ExpectedClients')) {
    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
        throw "Manifest file not found: $ManifestPath"
    }

    $manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.runId -and $manifest.runId -ne $RunId) {
        throw "Manifest runId '$($manifest.runId)' does not match provided RunId '$RunId'."
    }

    $ExpectedClients = @($manifest.items | Where-Object { $_.install_client -eq $true -or $_.as_jumpoint -eq $true }).Count
}

if ($ExpectedClients -lt 1) {
    throw 'ExpectedClients must be >= 1 (directly or derived from manifest install_client/as_jumpoint flags).'
}
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$script:pollAttempt = 0

$token = Get-PraAccessToken -BaseUrl $baseUrl -ClientId $clientId -ClientSecret $clientSecret

while ((Get-Date) -lt $deadline) {
    $script:pollAttempt++
    $onlineCount = Get-OnlineClientCount -BaseUrl $baseUrl -Token $token -Tag $tag
    Write-Host "[Validation] Attempt #$script:pollAttempt - online clients: $onlineCount / expected: $ExpectedClients"

    if ($onlineCount -ge $ExpectedClients) {
        Write-Host "[Validation] Success: all expected clients with tag '$tag' are online."
        exit 0
    }

    Start-Sleep -Seconds $PollSeconds
}

throw "[Validation] Timeout after $TimeoutMinutes minute(s). Expected $ExpectedClients online clients for tag '$tag'."
