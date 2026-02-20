param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [string]$JumpGroup
)

$ErrorActionPreference = 'Stop'

function Test-PraConnectivity {
    param(
        [string]$Uri = 'https://pa-test.trivadis.com',
        [int]$MaxAttempts = 12,
        [int]$DelaySeconds = 10
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Write-Host "[Connectivity] Attempt $attempt/$MaxAttempts -> $Uri"
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -Method Get -TimeoutSec 15
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                Write-Host "[Connectivity] Endpoint reachable. StatusCode=$($response.StatusCode)"
                return $true
            }
        }
        catch {
            Write-Warning "[Connectivity] Attempt $attempt failed: $($_.Exception.Message)"
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    throw "[Connectivity] Unable to reach $Uri after $MaxAttempts attempts."
}

Write-Host "Preparing BeyondTrust Jump Client setup for RunId=$RunId, JumpGroup=$JumpGroup"
Test-PraConnectivity

$installRoot = 'C:\ProgramData\BeyondTrust\LabBootstrap'
$logPath = Join-Path $installRoot 'jump-client-install.log'
$cmdPath = Join-Path $installRoot 'install_jump_client.cmd'

New-Item -Path $installRoot -ItemType Directory -Force | Out-Null

# Simulate/preset silent installer command used by CSE.
$installerCommand = @(
    'msiexec /i BeyondTrustJumpClient.msi /qn /norestart',
    "RUN_ID=$RunId",
    "JUMP_GROUP=$JumpGroup",
    'INSTALL_SCOPE=machine',
    'LOG_VERBOSITY=verbose'
) -join ' '

Set-Content -Path $cmdPath -Value $installerCommand -Encoding ASCII

"$(Get-Date -Format o) Prepared Jump Client silent installation command: $installerCommand" |
    Tee-Object -FilePath $logPath -Append

Write-Host "Jump Client preparation completed. Command file: $cmdPath"
