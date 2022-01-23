
$ModulePath = Join-Path -Path (
    Split-Path $MyInvocation.MyCommand.Source
)  -ChildPath "../DroneCI.psd1"


$scriptDir = Split-Path $MyInvocation.MyCommand.Source
$modulePDS = Resolve-Path (Join-Path -Path $scriptDir -ChildPath "../DroneCI.psd1")
Remove-Module "DroneCI" -Force -ErrorAction Ignore
Import-Module $modulePDS -Force

InModuleScope -ModuleName DroneCI -ScriptBlock {

    BeforeAll {
        ## Examples
        # $GlobalValue = 'Some Test Value'
        # Mock Run-ThirdPartyFunction
        $GlobalTimestamp = 1641378777
    }
    Describe 'ConvertTo-DateTime' {
        It 'Given a valid unix timestamp, it should be converted to a DateTime' {
            $time = ConvertTo-DateTime -Timestamp $GlobalTimestamp
            $time.GetType().FullName | Should -Be "System.DateTime"
            $time.Year | Should -Be 2022
            $time.Month | Should -Be 01
            $time.Day | Should -Be 05
            $time.Hour | Should -Be 10
            $time.Minute | Should -Be 32
            $time.Second | Should -Be 57
        }
    }
}