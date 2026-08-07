Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$encodedPassword = & kubectl get secret argocd-initial-admin-secret -n argocd `
    -o 'jsonpath={.data.password}'
if ($LASTEXITCODE -ne 0) {
    throw 'Could not read the initial Argo CD password.'
}
$password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encodedPassword))

Write-Host 'Argo CD URL: https://localhost:8080'
Write-Host 'Username: admin'
Write-Host "Password: $password`n"
Write-Host 'Keep this process running and press Ctrl+C when finished.'
& kubectl port-forward service/argocd-server -n argocd 8080:443
