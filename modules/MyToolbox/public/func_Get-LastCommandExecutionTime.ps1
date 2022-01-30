function Get-LastCommandExecutionTime () {
    param (
        # Number of 
        [Parameter(Position = 0)]
        [ValidateRange(1, 1000)]
        [Int]
        $Count = 1
    )

    $negativeCount = $Count * (-1)

    $commands = (Get-History)[$negativeCount..-1]

    $execTimes = foreach ($cmd in $commands) {
        $start = $cmd.StartExecutionTime
        $end = $cmd.EndExecutionTime
        $duration = $end - $start
        [PSCustomObject]@{
            Command  = $cmd.CommandLine
            Start    = $start
            End      = $end
            Duration = $duration
        }
    }

    return $execTimes
}