<#
.SYNOPSIS
Entfernt alle PRA-Objekte eines Deployments anhand des Run-Tags.

.DESCRIPTION
Für einen gegebenen RunId wird der Tag "run:<RunId>" gebildet. Anschließend werden
alle relevanten Objekttypen (Jumpoint, Shell Jump, Remote Jump, Jump Client)
abgerufen und gelöscht. Das Skript ist idempotenznah ausgelegt: Objekte ohne ID
werden übersprungen, leere Trefferlisten sind zulässig.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId
)

$ErrorActionPreference = 'Stop'

# OAuth2-Anmeldung gegenüber PRA. Ohne gültiges Token sind keine
# Konfigurationsabfragen/Löschoperationen möglich.
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

# Ruft alle Objekte eines Typs ab, die mit dem Run-Tag markiert sind.
# Rückgabe wird auf eine einheitliche Array-Form normalisiert.
function Get-PraObjectsByType {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$ObjectType
    )

    $encodedFilter = [System.Uri]::EscapeDataString("tag:$Tag")
    $uri = "$BaseUrl/api/config/v1/$ObjectType?filter=$encodedFilter"

    Write-Host "[Cleanup] Querying $ObjectType with tag '$Tag' via $uri"

    $headers = @{ Authorization = "Bearer $Token" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

    if ($null -eq $response) { return @() }
    if ($response -is [System.Array]) { return $response }
    if ($response.items) { return @($response.items) }
    return @($response)
}

# Löscht alle zuvor gefundenen Objekte eines Typs sequenziell.
# Sequenzielles Löschen erleichtert Troubleshooting im Pipeline-Log.
function Remove-PraObjectsByType {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$ObjectType
    )

    $objects = Get-PraObjectsByType -BaseUrl $BaseUrl -Token $Token -Tag $Tag -ObjectType $ObjectType

    foreach ($obj in $objects) {
        if (-not $obj.id) {
            Write-Warning "[Cleanup] Skipping $ObjectType object without id."
            continue
        }

        $deleteUri = "$BaseUrl/api/config/v1/$ObjectType/$($obj.id)"
        Write-Host "[Cleanup] Deleting $ObjectType '$($obj.name)' ($($obj.id)) via $deleteUri"

        Invoke-RestMethod -Method Delete -Uri $deleteUri -Headers @{ Authorization = "Bearer $Token" }
    }

    Write-Host "[Cleanup] $ObjectType cleanup complete. Removed $($objects.Count) object(s)."
}

$baseUrl = $env:PRA_BASE_URL
$clientId = $env:PRA_CLIENT_ID
$clientSecret = $env:PRA_CLIENT_SECRET

if (-not $baseUrl -or -not $clientId -or -not $clientSecret) {
    throw 'PRA_BASE_URL, PRA_CLIENT_ID and PRA_CLIENT_SECRET environment variables are required.'
}

$tag = "run:$RunId"
$token = Get-PraAccessToken -BaseUrl $baseUrl -ClientId $clientId -ClientSecret $clientSecret

$objectTypes = @(
    'jumpoint',
    'shell-jump',
    'remote-jump',
    'jump-client'
)

foreach ($type in $objectTypes) {
    Remove-PraObjectsByType -BaseUrl $baseUrl -Token $token -Tag $tag -ObjectType $type
}

Write-Host "Cleanup finished for PRA objects tagged '$tag'."
