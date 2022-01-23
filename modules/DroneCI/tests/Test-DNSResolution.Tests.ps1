
$ModulePath = Join-Path -Path (
    Split-Path $MyInvocation.MyCommand.Source
)  -ChildPath "../DroneCI.psd1"


$scriptDir = Split-Path $MyInvocation.MyCommand.Source
$modulePDS = Resolve-Path (Join-Path -Path $scriptDir -ChildPath "../DroneCI.psd1")
Remove-Module "DroneCI" -Force -ErrorAction Ignore
Import-Module $modulePDS -Force

InModuleScope -ModuleName DroneCI -ScriptBlock {

    BeforeAll {
        $GlobalValideEndpoint = "http://example.org"
        $GlobalInvalideEndpoint = "http://google.nothing"
    }
    Describe 'Test-DNSResolution' {
        It 'Given a valid dns entry, it should retrun $true' {
            Test-DNSResolution -Uri $GlobalValideEndpoint | Should -Be $true
        }
        It 'Given an invalid dns entry, it should retrun $false' {
            Test-DNSResolution -Uri $GlobalInvalideEndpoint | Should -Be $false
        }
    }
}