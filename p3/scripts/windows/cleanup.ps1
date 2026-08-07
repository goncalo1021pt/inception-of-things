[CmdletBinding()]
param([string]$ClusterName = 'iot')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$p3Directory = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$installedK3d = Get-Command k3d -ErrorAction SilentlyContinue
if ($installedK3d) {
    $k3d = $installedK3d.Source
}
else {
    $k3d = Join-Path $p3Directory '.tools\k3d.exe'
}

if (-not (Test-Path $k3d)) {
    throw 'K3d is not installed.'
}

$clusters = @((& $k3d cluster list -o json 2>$null | ConvertFrom-Json))
$clusterExists = @($clusters | Where-Object { $_.name -eq $ClusterName }).Count -gt 0
if ($clusterExists) {
    & $k3d cluster delete $ClusterName
}
else {
    Write-Host "Cluster $ClusterName does not exist."
}
