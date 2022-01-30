function Remove-FromHistory () {
    param (
        [String] $Pattern
    )
    $historyPath = (Get-PSReadLineOption).HistorySavePath
    Get-Content $historyPath | Where-Object { $_ -notlike $Pattern } | Set-Content $historyPath
}