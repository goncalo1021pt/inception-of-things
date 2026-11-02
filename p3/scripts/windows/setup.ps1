[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://github\.com/[^/]+/[^/]+(\.git)?$')]
    [string]$RepoUrl,

    [string]$TargetRevision = 'main',
    [string]$AppPath = 'p3/confs/dev',
    [string]$ClusterName = 'iot',
    [string]$K3dVersion = 'v5.9.0',
    [string]$ArgoCdVersion = 'v3.4.2'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess {
    param([string]$Action)
    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed with exit code $LASTEXITCODE."
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

foreach ($commandName in @('docker', 'kubectl')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "$commandName is required. Install and start Docker Desktop first."
    }
}

$dockerOs = (& docker info --format '{{.OSType}}' 2>$null).Trim()
Assert-NativeSuccess 'Checking Docker Desktop'
if ($dockerOs -ne 'linux') {
    throw 'Docker Desktop must be running Linux containers.'
}

$p3Directory = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$toolsDirectory = Join-Path $p3Directory '.tools'
$localK3d = Join-Path $toolsDirectory 'k3d.exe'
$installedK3d = Get-Command k3d -ErrorAction SilentlyContinue

if ($installedK3d) {
    $k3d = $installedK3d.Source
}
else {
    $k3d = $localK3d
    if (-not (Test-Path $k3d)) {
        Write-Step "Downloading K3d $K3dVersion"
        New-Item -ItemType Directory -Force -Path $toolsDirectory | Out-Null
        $releaseBase = "https://github.com/k3d-io/k3d/releases/download/$K3dVersion"
        Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/k3d-windows-amd64.exe" -OutFile $k3d
    }

    # Windows PowerShell returns application/octet-stream responses as Byte[].
    # Decode the checksum asset explicitly and verify even an existing download,
    # including one left behind by an interrupted previous run.
    $releaseBase = "https://github.com/k3d-io/k3d/releases/download/$K3dVersion"
    $checksumResponse = Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/checksums.txt"
    if ($checksumResponse.Content -is [byte[]]) {
        $checksums = [Text.Encoding]::UTF8.GetString($checksumResponse.Content)
    }
    else {
        $checksums = [string]$checksumResponse.Content
    }
    $checksumLine = $checksums -split "`r?`n" |
        Where-Object { $_ -match 'k3d-windows-amd64\.exe\s*$' } |
        Select-Object -First 1
    if (-not $checksumLine) {
        throw 'Could not find the Windows binary checksum in the K3d release.'
    }
    $expectedHash = ($checksumLine.Trim() -split '\s+')[0].ToLowerInvariant()
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $k3d).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        Remove-Item -Force $k3d
        throw 'The downloaded K3d checksum did not match.'
    }
}

$clusters = @((& $k3d cluster list -o json 2>$null | ConvertFrom-Json))
$cluster = $clusters | Where-Object { $_.name -eq $ClusterName } | Select-Object -First 1

if ($cluster) {
    $loadBalancerName = "k3d-$ClusterName-serverlb"
    $hasLoadBalancer = @($cluster.nodes | Where-Object { $_.name -eq $loadBalancerName }).Count -gt 0
    if (-not $hasLoadBalancer) {
        Write-Step "Recreating incomplete K3d cluster $ClusterName"
        & $k3d cluster delete $ClusterName
        Assert-NativeSuccess 'Removing the incomplete K3d cluster'
        $cluster = $null
    }
}

if (-not $cluster) {
    Write-Step "Creating K3d cluster $ClusterName"
    & $k3d cluster create $ClusterName `
        --servers 1 `
        --agents 1 `
        --port '8888:30080@loadbalancer' `
        --wait
    Assert-NativeSuccess 'Creating the K3d cluster'
}
else {
    if (($cluster.serversRunning -lt $cluster.serversCount) -or
        ($cluster.agentsRunning -lt $cluster.agentsCount)) {
        Write-Step "Starting existing K3d cluster $ClusterName"
        & $k3d cluster start $ClusterName
        Assert-NativeSuccess 'Starting the K3d cluster'
    }
    else {
        Write-Step "Using existing K3d cluster $ClusterName"
    }
}

& kubectl config use-context "k3d-$ClusterName" | Out-Null
Assert-NativeSuccess 'Selecting the K3d context'

Write-Step 'Creating the required namespaces'
$namespaceYaml = & kubectl create namespace argocd --dry-run=client -o yaml
$namespaceYaml | & kubectl apply -f -
Assert-NativeSuccess 'Creating the argocd namespace'
$namespaceYaml = & kubectl create namespace dev --dry-run=client -o yaml
$namespaceYaml | & kubectl apply -f -
Assert-NativeSuccess 'Creating the dev namespace'

Write-Step "Installing Argo CD $ArgoCdVersion"
$argoManifest = "https://raw.githubusercontent.com/argoproj/argo-cd/$ArgoCdVersion/manifests/install.yaml"
& kubectl apply --server-side --force-conflicts -n argocd -f $argoManifest
Assert-NativeSuccess 'Installing Argo CD'
& kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=2m
Assert-NativeSuccess 'Waiting for the Argo CD CRD'
& kubectl rollout status deployment/argocd-server -n argocd --timeout=5m
Assert-NativeSuccess 'Waiting for the Argo CD server'
& kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=5m
Assert-NativeSuccess 'Waiting for the Argo CD repository server'

$templatePath = Join-Path $p3Directory 'confs\argocd\application.yaml.tpl'
$rendered = (Get-Content -Raw $templatePath).
    Replace('__REPO_URL__', $RepoUrl).
    Replace('__TARGET_REVISION__', $TargetRevision).
    Replace('__APP_PATH__', $AppPath)
$temporaryManifest = Join-Path ([IO.Path]::GetTempPath()) "iot-argocd-$([guid]::NewGuid()).yaml"

try {
    [IO.File]::WriteAllText($temporaryManifest, $rendered, [Text.UTF8Encoding]::new($false))
    Write-Step 'Registering the GitOps application'
    & kubectl apply -f $temporaryManifest
    Assert-NativeSuccess 'Registering the Argo CD application'
}
finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $temporaryManifest
}

Write-Step 'Waiting for the first Git synchronization'
$syncCondition = '--for=jsonpath={.status.sync.status}=Synced'
& kubectl wait application/iot-app -n argocd $syncCondition --timeout=5m
Assert-NativeSuccess 'Waiting for Argo CD synchronization'
& kubectl rollout status deployment/playground -n dev --timeout=5m
Assert-NativeSuccess 'Waiting for the playground deployment'

Write-Step 'Windows test environment is ready'
Write-Host 'Application: http://localhost:8888'
Write-Host 'Argo CD UI: powershell -ExecutionPolicy Bypass -File p3/scripts/windows/argocd-ui.ps1'
