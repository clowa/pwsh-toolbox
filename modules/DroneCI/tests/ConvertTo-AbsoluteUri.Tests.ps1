
$ModulePath = Join-Path -Path (
    Split-Path $MyInvocation.MyCommand.Source
)  -ChildPath "../DroneCI.psd1"


$scriptDir = Split-Path $MyInvocation.MyCommand.Source
$modulePDS = Resolve-Path (Join-Path -Path $scriptDir -ChildPath "../DroneCI.psd1")
Remove-Module "DroneCI" -Force -ErrorAction Ignore
Import-Module $modulePDS -Force

InModuleScope -ModuleName DroneCI -ScriptBlock {

    BeforeAll {
        $GlobalHostWithoutScheme = "example.org"
        [Uri]$GlobalHostWithScheme = "http://example.org"

        $GlobalHostWithoutSchemeAndCustomPath = "example.org/home"
        [Uri]$GlobalHostWithSchemeAndCustomPath = "http://example.org/home"
    }
    Describe 'ConvertTo-AbsoluteUri' {
        It "Given a dns host without leadin scheme/protocol, it should be default to 'https'" {
            $uri = ConvertTo-AbsoluteUri -Uri $GlobalHostWithoutScheme

            $uri.GetType().Fullname | Should -Be "System.Uri"
            $uri.Scheme | Should -Be "https"
            $uri.Host | Should -Be $GlobalHostWithoutScheme
        }
        It "Given a dns host with scheme/protocol, it should do nothing and return the input object'" {
            $uri = ConvertTo-AbsoluteUri -Uri $GlobalHostWithScheme.OriginalString

            $uri.GetType().Fullname | Should -Be "System.Uri"
            $uri.Equals($GlobalHostWithScheme)
            $uri.Scheme | Should -Be $GlobalHostWithScheme.Scheme
            $uri.Host | Should -Be $GlobalHostWithScheme.Host
        }
        It "Given a dns host without leadin scheme/protocol and a custom path, it should be default to 'https' and set AbsolutePath to '/'" {
            $uri = ConvertTo-AbsoluteUri -Uri $GlobalHostWithoutScheme

            $uri.GetType().Fullname | Should -Be "System.Uri"
            $uri.Scheme | Should -Be "https"
            $uri.AbsolutePath | Should -Be '/'
        }
        It "Given a dns host with scheme/protocol and a custom path, it should set AbsolutePath to '/'" {
            $uri = ConvertTo-AbsoluteUri -Uri $GlobalHostWithSchemeAndCustomPath.OriginalString

            $uri.GetType().Fullname | Should -Be "System.Uri"
            $uri.Equals($GlobalHostWithSchemeAndCustomPath)
            $uri.Scheme | Should -Be $GlobalHostWithSchemeAndCustomPath.Scheme
            $uri.Host | Should -Be $GlobalHostWithSchemeAndCustomPath.Host
            $uri.AbsolutePath | Should -Be '/'
        }
    }
}