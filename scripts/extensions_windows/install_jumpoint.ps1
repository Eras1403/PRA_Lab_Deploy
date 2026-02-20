<#
.SYNOPSIS
Bereitet die unbeaufsichtigte BeyondTrust-Jumpoint-Installation auf Windows vor.

.DESCRIPTION
Dieses Skript führt bewusst KEINE direkte Installation aus, sondern erstellt eine
CMD-Datei mit allen benötigten Silent-Installationsparametern. Dadurch kann die
Ausführung zeitlich getrennt erfolgen (z. B. in einem späteren Provisioning-Schritt)
und bleibt durch Log-Dateien nachvollziehbar.

Hauptschritte:
1) Parameter validieren (RunId/JumpGroup).
2) PRA-Endpunkt auf Erreichbarkeit prüfen.
3) Arbeitsverzeichnis unter C:\ProgramData\BeyondTrust\LabBootstrap anlegen.
4) Installer-Befehl generieren und protokollieren.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [string]$JumpGroup
)

$ErrorActionPreference = 'Stop'

# Vorabprüfung auf PRA-Erreichbarkeit, um fehlerhafte Vorbereitungen
# in nicht verbundenen Umgebungen zu verhindern.
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

Write-Host "Preparing BeyondTrust Jumpoint setup for RunId=$RunId, JumpGroup=$JumpGroup"
Test-PraConnectivity

$installRoot = 'C:\ProgramData\BeyondTrust\LabBootstrap'
$logPath = Join-Path $installRoot 'jumpoint-install.log'
$cmdPath = Join-Path $installRoot 'install_jumpoint.cmd'

New-Item -Path $installRoot -ItemType Directory -Force | Out-Null

# Simulate/preset silent Jumpoint setup command.
$installerCommand = @(
    'BeyondTrustJumpoint.exe /quiet /norestart',
    "RUN_ID=$RunId",
    "JUMP_GROUP=$JumpGroup",
    'BIND_ADDRESS=0.0.0.0',
    'REGISTER_SERVICE=true'
) -join ' '

Set-Content -Path $cmdPath -Value $installerCommand -Encoding ASCII

"$(Get-Date -Format o) Prepared Jumpoint silent installation command: $installerCommand" |
    Tee-Object -FilePath $logPath -Append

Write-Host "Jumpoint preparation completed. Command file: $cmdPath"
