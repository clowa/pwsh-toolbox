function Get-FullHistory () {
    Get-Content -Path (Get-PSReadLineOption).HistorySavePath
}
Set-Alias -Name 'history' -Value Get-FullHistory -Description 'Get command history across all Powershell sessions.'