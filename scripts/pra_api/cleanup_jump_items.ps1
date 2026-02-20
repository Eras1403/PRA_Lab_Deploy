param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId
)

$ErrorActionPreference = 'Stop'

function Get-PraAccessToken {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][string]$ClientSecret
    )

    $tokenUri = "$BaseUrl/oauth2/token"
    Write-Host "Requesting OAuth token from $tokenUri"

    # Simulated OAuth token request.
    return "simulated-token-$([guid]::NewGuid())"
}

function Remove-PraObjectsByType {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$ObjectType
    )

    $listUri = "$BaseUrl/api/config/v1/$ObjectType?filter=tag:$Tag"
    Write-Host "[Cleanup] Querying $ObjectType with tag '$Tag' via $listUri"

    # Simulated results. Replace with real GET/DELETE calls during production integration.
    $simulatedObjects = @(
        [PSCustomObject]@{ id = "$ObjectType-001"; name = "$ObjectType-for-$Tag" },
        [PSCustomObject]@{ id = "$ObjectType-002"; name = "$ObjectType-backup-$Tag" }
    )

    foreach ($obj in $simulatedObjects) {
        $deleteUri = "$BaseUrl/api/config/v1/$ObjectType/$($obj.id)"
        Write-Host "[Cleanup] Deleting $ObjectType '$($obj.name)' ($($obj.id)) via $deleteUri"
    }

    Write-Host "[Cleanup] $ObjectType cleanup complete. Removed $($simulatedObjects.Count) object(s)."
}

$baseUrl = if ($env:PRA_BASE_URL) { $env:PRA_BASE_URL } else { 'https://pa-test.trivadis.com' }
$clientId = if ($env:PRA_CLIENT_ID) { $env:PRA_CLIENT_ID } else { 'simulated-client-id' }
$clientSecret = if ($env:PRA_CLIENT_SECRET) { $env:PRA_CLIENT_SECRET } else { 'simulated-client-secret' }

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
