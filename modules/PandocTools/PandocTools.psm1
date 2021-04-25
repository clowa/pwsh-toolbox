function Convert-OverHTML {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]
        $Source,

        [Parameter(Mandatory)]
        [System.String]
        $Dest,

        [Parameter()]
        [System.String]
        $From = 'markdown',

        [Parameter()]
        [System.String]
        $To = 'docx'
    )

    if (-Not (Get-Command pandoc.exe)){
        thow "Pandoc.exe not found"
    }

    Write-Verbose "Converting file from $From to $To over HTML ..."
    Invoke-Command -ScriptBlock { pandoc.exe --from $From --to html -i $Source | pandoc.exe --from html --to $To -o $Dest }
}

