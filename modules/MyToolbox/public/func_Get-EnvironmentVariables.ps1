function Get-EnvironmentVariables {
    return Get-ChildItem env:
}
Set-Alias -Name 'printenv' -Value Get-EnvVars -Description 'Get all environment variables of the current session.'