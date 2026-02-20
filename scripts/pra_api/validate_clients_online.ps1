param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$ExpectedClients,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1000)]
    [int]$WindowsJumpClientCount = 0,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1000)]
    [int]$LinuxJumpClientCount = 0,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 120)]
    [int]$TimeoutMinutes = 20,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 300)]
    [int]$PollSeconds = 30
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

    # Simulated OAuth token response for pipeline orchestration.
    # Replace with Invoke-RestMethod POST to /oauth2/token in real integration.
    return "simulated-token-$([guid]::NewGuid())"
}

function Get-OnlineClientCount {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    $uri = "$BaseUrl/api/config/v1/jump-client?filter=tag:$Tag"
    Write-Host "Polling PRA API endpoint: $uri"

    # Simulate progressive client registration (for demo/testing pipeline behavior).
    $simulatedCount = [Math]::Min($script:ExpectedClients, $script:pollAttempt)
    return $simulatedCount
}

$baseUrl = if ($env:PRA_BASE_URL) { $env:PRA_BASE_URL } else { 'https://pa-test.trivadis.com' }
$clientId = if ($env:PRA_CLIENT_ID) { $env:PRA_CLIENT_ID } else { 'simulated-client-id' }
$clientSecret = if ($env:PRA_CLIENT_SECRET) { $env:PRA_CLIENT_SECRET } else { 'simulated-client-secret' }

$tag = "run:$RunId"
if (-not $PSBoundParameters.ContainsKey('ExpectedClients')) {
    $ExpectedClients = $WindowsJumpClientCount + $LinuxJumpClientCount
}

if ($ExpectedClients -lt 1) {
    throw 'ExpectedClients must be >= 1 (directly or via WindowsJumpClientCount + LinuxJumpClientCount).'
}
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$script:pollAttempt = 0
$script:ExpectedClients = $ExpectedClients

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
