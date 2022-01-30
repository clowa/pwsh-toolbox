## Dot source classes, enumerations, etc from lib folder
## Do this before dot sourcing other cmdlets which maybe are using this classes, enumerations, etc.
Get-ChildItem "$(Split-Path $script:MyInvocation.MyCommand.Path)\lib\*" -Filter '*.ps1' -Recurse | ForEach-Object { 
    . $_.FullName 
}

## Dot source private functions
Get-ChildItem (Split-Path $script:MyInvocation.MyCommand.Path) -Filter 'func_*.ps1' -Recurse | ForEach-Object { 
    . $_.FullName 
}

## Export public functions
Get-ChildItem "$(Split-Path $script:MyInvocation.MyCommand.Path)\Public\*" -Filter 'func_*.ps1' -Recurse | ForEach-Object { 
    Export-ModuleMember -Function ($_.BaseName -Split "_")[1] 
}

###
# Set environment variables
###
$env:historyPath = (Get-PSReadLineOption).HistorySavePath
