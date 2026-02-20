<#
.SYNOPSIS
Installiert den BeyondTrust Jump Client auf Windows und validiert den Dienststatus.

.DESCRIPTION
Das Skript ist für automatisierte Umgebungen (CI/CD, IaC-Provisioning) optimiert:
- Silent MSI-Installation über msiexec.
- Detailliertes MSI-Logging.
- Aktive Validierung auf bekannte Service-Namen inkl. Retry-Logik.

Damit wird nicht nur die Installationsrückgabe geprüft, sondern auch der echte
Laufzeitzustand (Service = Running), was in Praxis deutlich robuster ist.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [string]$JumpGroup
)

$ErrorActionPreference = 'Stop'

# Wiederholte Reachability-Prüfung gegen PRA, damit Installationsfehler
# wegen temporärer Netzprobleme klar von MSI-Fehlern getrennt werden können.
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

# Wartet auf den Running-Status eines der erwarteten Dienstnamen,
# da je nach Paketversion unterschiedliche Service-Bezeichnungen vorkommen.
function Wait-ServiceRunning {
    param(
        [Parameter(Mandatory = $true)][string[]]$ServiceNames,
        [int]$MaxAttempts = 12,
        [int]$DelaySeconds = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        foreach ($name in $ServiceNames) {
            $service = Get-Service -Name $name -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') {
                Write-Host "[Validation] Service '$name' is running."
                return $true
            }
        }

        Write-Host "[Validation] Waiting for Jump Client service to start (attempt $attempt/$MaxAttempts)."
        Start-Sleep -Seconds $DelaySeconds
    }

    return $false
}

Write-Host "Installing BeyondTrust Jump Client for RunId=$RunId, JumpGroup=$JumpGroup"
Test-PraConnectivity

$installRoot = 'C:\ProgramData\BeyondTrust\LabBootstrap'
$logPath = Join-Path $installRoot 'jump-client-install.log'
$installerPath = Join-Path (Get-Location) 'BeyondTrustJumpClient.msi'

New-Item -Path $installRoot -ItemType Directory -Force | Out-Null

if (-not (Test-Path $installerPath)) {
    throw "[Install] Installer not found at $installerPath"
}

$msiLogPath = Join-Path $installRoot 'jump-client-msiexec.log'
$arguments = @(
    '/i', "`"$installerPath`"",
    '/qn', '/norestart',
    "RUN_ID=$RunId",
    "JUMP_GROUP=$JumpGroup",
    'INSTALL_SCOPE=machine',
    '/l*v', "`"$msiLogPath`""
)

Write-Host '[Install] Running msiexec for Jump Client...'
$process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "[Install] msiexec failed with exit code $($process.ExitCode). See $msiLogPath"
}

"$(Get-Date -Format o) Executed msiexec with arguments: $($arguments -join ' ')" |
    Tee-Object -FilePath $logPath -Append

$serviceCandidates = @('bomgar-jump-client', 'BeyondTrust Jump Client', 'bomgar-scc')
if (-not (Wait-ServiceRunning -ServiceNames $serviceCandidates)) {
    Get-Service | Where-Object { $_.Name -match 'bomgar|beyondtrust|jump' -or $_.DisplayName -match 'bomgar|beyondtrust|jump' } |
        Format-Table -AutoSize | Out-String | Tee-Object -FilePath $logPath -Append | Write-Host
    throw "[Validation] Jump Client service did not reach Running state."
}

Write-Host "Jump Client installation completed successfully."
