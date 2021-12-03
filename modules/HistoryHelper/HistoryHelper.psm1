###
# History
###
function Get-FullHistory () {
    Get-Content -Path (Get-PSReadLineOption).HistorySavePath
}
Set-Alias -Name 'history' -Value Get-FullHistory -Description 'Get command history across all Powershell sessions.'

function Remove-FromHistory () {
    param (
        [String] $Pattern
    )
    $historyPath = (Get-PSReadLineOption).HistorySavePath
    Get-Content $historyPath | Where-Object { $_ -notlike $Pattern } | Set-Content $historyPath
}