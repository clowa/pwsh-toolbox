<#
.SYNOPSIS
    This cmdlet let you access the argoCD dashboard and stores password in clipboard.
.DESCRIPTION
    This cmdlet fetches the argoCD admin password and opens the dashboard URL via kubernetes porxy. The admin password is stored to clipboard.
.EXAMPLE
    PS C:\> Start-ArgoDashboard -Namespace "argo-cd"
    Expects the argocd deployment in kubernetes namespace "argo-cd" and opens the std. browser with argo dashboard. Use admin as username and password from clipboard.
#>
function Start-KubernetesDashboard {
    param (
        # Namespace of argo deployment
        [Parameter()]
        [String]
        $Namespace = "argocd"
    )
    # Get admin password
    $passwd = kubectl -n $Namespace get secrets argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -D | ConvertTo-SecureString -AsPlainText
    $passwd | ConvertFrom-SecureString -AsPlainText | Set-Clipboard


    # Open URI of argo dashboard
    Start-Process "http://localhost:8001/api/v1/namespaces/$Namespace/services/https:argocd-server:https/proxy"

    # Start kubernetes proxy
    kubectl proxy
}

Set-Alias -Name kdash -Value Start-KubernetesDashboard -Description 'Shortcut to open kubernetes dashboard'  