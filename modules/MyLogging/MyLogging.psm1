class LogMessage {
    [ValidateNotNullOrEmpty()][String]$Time
    [ValidateNotNullOrEmpty()][String]$Pid
    [ValidateNotNullOrEmpty()][String]$User
    [ValidateNotNullOrEmpty()][String]$Severity
    [ValidateNotNullOrEmpty()][String]$Message

    # Create new LogMessage object.
    LogMessage($_severity, $_message) {
        $this.Time = [DateTime]::Now
        $this.Pid = [Diagnostics.Process]::GetCurrentProcess().Id
        $this.User = [Environment]::UserName
        $this.Severity = $_severity
        $this.Message = $_message
    }

    # Create new LogMessage object from JSON.
    LogMessage([Collections.Hashtable]$json) {
        $this.Time = [DateTime]::Parse($json['Time'], [cultureinfo]::GetCultureInfo('en-US'))
        $this.Pid = $json['Pid']
        $this.User = $json['User']
        $this.Severity = $json['Severity']
        $this.Message = $json['Message']
    }

    # Convert LogMessage to String format.
    [String] ToString() {
        [DateTime]$Date = $this.Time
        $displayTime = '{0}-{1}-{2} {3}:{4}:{5}' -f $Date.Year, $Date.Month, $Date.Day, $Date.Hour, $Date.Minute, $Date.Second
        return '{0} - {1} - {2} - {3} - {4}' -f $displayTime, $this.Pid, $this.User, $this.Severity, $this.Message 
    }

    # Convert LogMessage to JSON.
    [String] ToJSON() {
        return $this | ConvertTo-Json
    }
}

function New-LogMessage {
    param (
        # Severity of message
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet(
            'Information',
            'Warning',
            'Error'
        )]
        [String] $Severity = 'Information',

        # Message to log
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Message
    )

    return [LogMessage]::new($Severity, $Message)
}

function Write-LogMessage {
    param (
        # Message to log
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String] $Message,

        # Path to log file
        [Parameter(Mandatory)]
        #[ValidateScript()]
        [String] $Path,

        # Severity of message
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'Information',
            'Warning',
            'Error'
        )]
        [String] $Severity = 'Information',

        # Type of log entri
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'JSON',
            'String'
        )]
        [String] $Type = 'String',

        # Deactivate return value
        [Parameter()]
        [Switch] $Quiet
    )

    # If $Path doesn't points to a file add file name
    if (!([IO.Path]::HasExtension($Path))) { 
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
    $LogMessageObj = [LogMessage]::new($Severity, $Message)
    Write-Debug $LogMessageObj

    Write-Information "Log: $($LogMessageObj.Message)"

    # write to logfile dependen of log type
    switch ($Type) {
        # Read in old log and add new log message to JSON list. Write whole back to file.
        'JSON' { 
            if ([IO.Path]::GetExtension($Path) -ne '.json') {
                Write-Information "Path doesn't point to a json file."
            }
            Write-Debug 'Converting $LogMessageObj to JSON.'
            $logMessage = $LogMessageObj.ToJSON()
            Write-Debug 'Reading in logfile as hastable.'
            $jsonHashtable = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
            Write-Debug 'Building list of log messages.'
            $LogMessageObjList = New-Object -TypeName 'Collections.Generic.List[LogMessage]'
            foreach ($js in $jsonHashtable) {
                $LogMessageObjList.Add([LogMessage]::new($js))
            }
            Write-Debug 'Adding new log message.'
            $LogMessageObjList.Add($LogMessageObj)
            Write-Debug 'Write log messages back to file as JSON.'
            Set-Content -Path $Path -Value ($LogMessageObjList | ConvertTo-Json)
        }
        # Append log message as string to file.
        'String' { 
            if ([IO.Path]::GetExtension($Path) -ne '.log') {
                Write-Information "Path doesn't point to a log file."
            }
            $logMessage = $LogMessageObj.ToString()
            Add-Content -Value $logMessage -Path $Path
        }
        Default {
            throw "Type $Type is not implemented"
        }
    }
    return $LogMessageObj
}

function Send-AWSCLISESEmail {
    [CmdletBinding()]
    param (
        # Email address of sender
        [Parameter(Mandatory)]
        [String] $From,

        # List of email addresses of recivers
        [Parameter(Mandatory)]
        [String[]] $Emails,

        # Subject of email
        [Parameter(
            ValueFromPipelineByPropertyName
        )]
        [String] $Subject = 'Powershell notification',

        # ! ValidateNotNullOrEmpty doesn't work in pipeline !!!!
        # Email text
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String] $Message,

        # AWS credentials used by cli.
        [Parameter(Mandatory)]
        [AWSCredential]
        $AWSCredential,

        # AWS region
        [Parameter(Mandatory)]
        [String]
        $AWSRegion
    )

    # * Could be removed if ValidateNotNullOrEmpty is working correctly
    if ($Message.Length -eq 0) {
        return
    }

    $messageIDs = New-Object -TypeName 'System.Collections.Generic.List[String]'
    # send email to each recipient in array
    foreach ($_email in $Emails) {
        Write-Verbose "Send email from $From to $_email"
        Write-Verbose "Message length: $($Message.Length)"

        # Set AWS CLI env vars
        if($AWSCredential) {
            Write-Verbose 'Credential object detected. Configuring environment variables.'
            $AWSCredential.setEnv()
        }

        $messageID = Invoke-Command -ScriptBlock {
            aws.exe ses send-email --from="$From" --to="$_email" --subject="$Subject" --text="$Message" --region="$AWSRegion" 
        }
        Write-Verbose "Message queued for send. ID: $($messageID)"
        $messageIDs.Add($messageID);

        # Unset AWS CLI env vars
        if($AWSCredential) {
            Write-Verbose 'Credential object detected. Destroying environment variables.'
            $AWSCredential.unsetEnv()
        }
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