###
# Process and Env
###
function Get-LastCommandExecutionTime () {
    $end = (Get-History)[-1].EndExecutionTime
    $start = (Get-History)[-1].StartExecutionTime
    return $end - $start
}
Set-Alias -Name 'lastexectime' -Value Get-LastCommandExecutionTime -Description 'Get execution time of last command in history.'

function Get-EnvVars { return Get-ChildItem env: }
Set-Alias -Name 'printenv' -Value Get-EnvVars -Description 'Get all environment variables of the current session.'