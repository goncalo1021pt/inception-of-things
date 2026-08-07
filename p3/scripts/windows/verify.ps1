Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess {
    param([string]$Action)
    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed with exit code $LASTEXITCODE."
    }
}

Write-Host "`n== Namespaces ==" -ForegroundColor Cyan
& kubectl get namespaces argocd dev
Assert-NativeSuccess 'Reading namespaces'

Write-Host "`n== Argo CD application ==" -ForegroundColor Cyan
& kubectl get application iot-app -n argocd
Assert-NativeSuccess 'Reading the Argo CD application'

Write-Host "`n== Development workload ==" -ForegroundColor Cyan
& kubectl get deployment,pod,service -n dev
Assert-NativeSuccess 'Reading the development workload'

Write-Host "`n== Deployed image ==" -ForegroundColor Cyan
$image = & kubectl get deployment playground -n dev `
    -o 'jsonpath={.spec.template.spec.containers[0].image}'
Assert-NativeSuccess 'Reading the deployed image'
Write-Host $image

Write-Host "`n== Application response ==" -ForegroundColor Cyan
& curl.exe --fail --show-error --silent --max-time 10 http://localhost:8888/
Assert-NativeSuccess 'Calling the application endpoint'
Write-Host ''
