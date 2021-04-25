
function Write-InfoMessage {
    [CmdletBinding()]
    param (
        # Message to log
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        # Severity of message
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'Information',
            'Warning',
            'Error'
        )]
        [string] $Severity = 'Information',

        # Subject used in email alert
        [Parameter(
            ParameterSetName = 'Email'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $Subject = 'Script notification',

        # SES email sender
        [Parameter(
            ParameterSetName = 'Email'
        )]
        [System.String] $EmailSender,

        # Email recipient
        [Parameter(
            ParameterSetName = 'Email'
        )]
        [System.String[]] $EmailRecipients,

        # AWS region
        [Parameter(
            Mandatory,
            ParameterSetName = 'Email'
        )]
        [System.String] $AWSRegion,

        # AWS profile name
        [Parameter(
            ParameterSetName = 'Email'        
        )]
        [System.String] $AWSProfile = 'default'
    )

    # create message and write to log
    $logMessage = Write-LogMessage -Message $Message -Path $logFile -Severity $Severity
    # send warnings and errors as email
    if ($logMessage.Severity -ne 'Information' -and $EmailRecipients.Length -gt 0 -and $logMessage.Message.Length -gt 0) {
        # send email to each recipient in array
        foreach ($email in $EmailRecipients) {
            Write-Verbose "Send email from $emailSender to $email with Subject $Subject and Message $Message"
            Send-AWSCliSESEmal -From $EmailSender -Emails $EmailRecipients -Subject $Subject -Message $logMessage.ToString() -AWSRegion $AWSRegion -AWSProfile $AWSRegion -Silent
            #aws.exe ses send-email --from="$EmailSender" --to="$email" --subject="$Subject" --text="$Message" --region="$AWSRegion" --profile="$AWSProfile" > $null
        }
    }
}

class LogMessage {
    [ValidateNotNullOrEmpty()][System.String]$Time
    [ValidateNotNullOrEmpty()][System.String]$Pid
    [ValidateNotNullOrEmpty()][System.String]$User
    [ValidateNotNullOrEmpty()][System.String]$Severity
    [ValidateNotNullOrEmpty()][System.String]$Message

    # Create new LogMessage object.
    LogMessage($_severity, $_message) {
        $this.Time = [System.DateTime]::Now
        $this.Pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $this.User = [System.Environment]::UserName
        $this.Severity = $_severity
        $this.Message = $_message
    }

    # Create new LogMessage object from JSON.
    LogMessage([System.Collections.Hashtable]$json) {
        $this.Time = [System.DateTime]::Parse($json['Time'], [cultureinfo]::GetCultureInfo('en-US'))
        $this.Pid = $json['Pid']
        $this.User = $json['User']
        $this.Severity = $json['Severity']
        $this.Message = $json['Message']
    }

    # Convert LogMessage to String format.
    [System.String] ToString() {
        [System.DateTime]$Date = $this.Time
        $displayTime = '{0}-{1}-{2} {3}:{4}:{5}' -f $Date.Year, $Date.Month, $Date.Day, $Date.Hour, $Date.Minute, $Date.Second
        return '{0} - {1} - {2} - {3} - {4}' -f $displayTime, $this.Pid, $this.User, $this.Severity, $this.Message 
    }

    # Convert LogMessage to JSON.
    [System.String] ToJSON() {
        return $this | ConvertTo-Json
    }
}

function Write-LogMessage {
    param (
        # Message to log
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Message,

        # Path to log file
        [Parameter(Mandatory)]
        #[ValidateScript()]
        [System.String] $Path,

        # Severity of message
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'Information',
            'Warning',
            'Error'
        )]
        [System.String] $Severity = 'Information',

        # Type of log entri
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'JSON',
            'String'
        )]
        [System.String] $Type = 'String',

        # Deactivate return value
        [Parameter()]
        [Switch] $Silent
    )
    # If $Path doesn't points to a file add file name
    if (!([System.IO.Path]::HasExtension($Path))) { 
        # creating file with basename of calling script or cmdlet
        Write-Verbose "Path isn't a file."
        if ($null -ne $MyInvocation.PSCommandPath) {
            $scriptName = (Get-Item $MyInvocation.PSCommandPath).BaseName
        } else {
            $scriptName = $MyInvocation.MyCommand.Name
        }
        # set extension dependend of type
        switch ($Type) {
            'JSON' { 
                $Path = Join-Path -Path $Path -ChildPath "${scriptName}.json" 
            }
            'String' { 
                $Path = Join-Path -Path $Path -ChildPath "${scriptName}.log"
            }
            Default {
                throw "Type $Type is not implemented"
            }
        }
        Write-Debug "New Path: $Path"
    }
    # If $Path doesn't exist create file
    if (!(Test-Path $Path)) {
        Write-Verbose 'Creating Logfile...'
        New-Item -ItemType File -Path $Path | Out-Null
    }
    # create message
    $logEntri = [LogMessage]::new($Severity, $Message)
    Write-Verbose $logEntri
    # write to logfile dependen of log type
    switch ($Type) {
        # Read in old log and add new log message to JSON list. Write whole back to file.
        'JSON' { 
            if ([System.IO.Path]::GetExtension($Path) -ne '.json') {
                Write-Information "Path doesn't point to a json file."
            }
            Write-Debug 'Converting $logEntri to JSON.'
            $logMessage = $logEntri.ToJSON()
            Write-Debug 'Reading in logfile as hastable.'
            $jsonHashtable = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
            Write-Debug 'Building list of log messages.'
            $logEntriList = New-Object -TypeName 'System.Collections.Generic.List[LogMessage]'
            foreach ($js in $jsonHashtable) {
                $logEntriList.Add([LogMessage]::new($js))
            }
            Write-Debug 'Adding new log message.'
            $logEntriList.Add($logEntri)
            Write-Debug 'Write log messages back to file as JSON.'
            Set-Content -Path $Path -Value ($logEntriList | ConvertTo-Json)
        }
        # Append log message as string to file.
        'String' { 
            if ([System.IO.Path]::GetExtension($Path) -ne '.log') {
                Write-Information "Path doesn't point to a log file."
            }
            $logMessage = $logEntri.ToString()
            Add-Content -Value $logMessage -Path $Path
        }
        Default {
            throw "Type $Type is not implemented"
        }
    }
    if ($Silent) {
        return
    }
    return $logEntri
}

function Send-AWSCliSESEmal {
    param (
        # Email address of sender
        [Parameter(Mandatory)]
        [System.String] $From,

        # List of email addresses of recivers
        [Parameter(Mandatory)]
        [System.String[]] $Emails,

        # Subject of email
        [Parameter()]
        [System.String] $Subject = 'Powershell notification',

        # Email text
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.String] $Message,

        # AWS region
        [Parameter(Mandatory)]
        [System.String] $AWSRegion,

        # AWS profile
        [Parameter()]
        [System.String] $AWSProfile = 'default',

        # Deactivate return value
        [Parameter()]
        [Switch] $Silent
    )
    $messageIDs = @()
    # send email to each recipient in array
    foreach ($_email in $Emails) {
        Write-Verbose "Send email from $From to $_email"
        $messageID = Invoke-Command -ScriptBlock {
            aws.exe ses send-email --from="$From" --to="$_email" --subject="$Subject" --text="$Message" --region="$AWSRegion" --profile="$AWSProfile" 
        }
        Write-Verbose "Message queued for send. ID: $messageID"
        $messageIDs.Add($messageID);
    }
    if ($Silent) {
        return
    }
    return $messageIDs
}

Function Get-Now {
    Param (
        # Append milliseconds
        [Parameter()]
        [Switch]$ms,
        # Append nanoseconds
        [Parameter()]
        [Switch]$ns         
    )
    $Date = Get-Date
    $now = ''
    $now += '{0:0000}-{1:00}-{2:00} ' -f $Date.Year, $Date.Month, $Date.Day
    $now += '{0:00}:{1:00}:{2:00}' -f $Date.Hour, $Date.Minute, $Date.Second
    $nsSuffix = ''
    if ($ns) {
        if ("$($Date.TimeOfDay)" -match '\.\d\d\d\d\d\d') {
            $now += $matches[0]
            $ms = $false
        } else {
            $ms = $true
            $nsSuffix = '000'
        }
    } 
    if ($ms) {
        $now += ".{0:000}$nsSuffix" -f $Date.MilliSecond
    }
    return $now
}