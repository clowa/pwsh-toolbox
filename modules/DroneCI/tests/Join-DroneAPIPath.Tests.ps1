
$ModulePath = Join-Path -Path (
    Split-Path $MyInvocation.MyCommand.Source
)  -ChildPath "../DroneCI.psd1"


$scriptDir = Split-Path $MyInvocation.MyCommand.Source
$modulePDS = Resolve-Path (Join-Path -Path $scriptDir -ChildPath "../DroneCI.psd1")
Remove-Module "DroneCI" -Force -ErrorAction Ignore
Import-Module $modulePDS -Force

InModuleScope -ModuleName DroneCI -ScriptBlock {

    BeforeAll {
        [Uri]$GlobalExpected = "https://example.org/api/info"
    }
    Describe 'Join-DroneAPIPath' {
        It "Given a DNS URI and API path whithout tailing '/', they should be joined together." {
            [Uri]$GlobalDroneServerUri = "https://example.org"
            $GlobalAPIPath = "/api/info"

            $ApiUri = Join-DroneAPIPath -Uri $GlobalDroneServerUri -Path $GlobalAPIPath

            $ApiUri.OriginalString | Should -Be $GlobalExpected.OriginalString
            $ApiUri.AbsolutePath | Should -Be $GlobalExpected.AbsolutePath
            $ApiUri.Equals($GlobalExpected)
        }
        It "Given a DNS URI and API path with tailing '/', they should be joined together without tailing '/'." {
            [Uri]$GlobalDroneServerUri = "https://example.org/"
            $GlobalAPIPath = "/api/info/"
            
            $ApiUri = Join-DroneAPIPath -Uri $GlobalDroneServerUri -Path $GlobalAPIPath

            $ApiUri.OriginalString | Should -Be $GlobalExpected.OriginalString
            $ApiUri.AbsolutePath | Should -Be $GlobalExpected.AbsolutePath
            $ApiUri.Equals($GlobalExpected)
        }
        It "Given a non root URI, there should be an error." {
            [Uri]$GlobalDroneServerUri = "https://example.org/subpath"
            
            { Join-DroneAPIPath -Uri $GlobalDroneServerUri | Should -Throw -ErrorType [System.ArgumentException] }
        }
    }
}