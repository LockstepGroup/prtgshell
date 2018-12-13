if (-not $ENV:BHProjectPath) {
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force


InModuleScope $ENV:BHProjectName {
    $PSVersion = $PSVersionTable.PSVersion.Major
    $ProjectRoot = $ENV:BHProjectPath

    $Verbose = @{}
    if ($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
        $Verbose.add("Verbose", $True)
    }

    Describe "Get-PrtgServer" {
        $PrtgServer = '1.1.1.1'
        $PrtgUsername = 'JohnDoe'
        $PrtgPassHash = '1234567890'
        $PrtgStatus = @'
<?xml version="1.0" encoding="UTF-8"?>
    <status>
        <NewMessages>0</NewMessages>
        <NewAlarms>0</NewAlarms>
        <Alarms>21</Alarms>
        <AckAlarms>7</AckAlarms>
        <NewToDos></NewToDos>
        <Clock>12/12/2018 4:33:04 PM</Clock>
        <ActivationStatusMessage>(Tag activationstatusalert unknown)</ActivationStatusMessage>
        <BackgroundTasks>0</BackgroundTasks>
        <CorrelationTasks>0</CorrelationTasks>
        <AutoDiscoTasks>0</AutoDiscoTasks>
        <Version>18.2.41.1652+</Version>
        <PRTGUpdateAvailable>yes</PRTGUpdateAvailable>
        <IsAdminUser>true</IsAdminUser>
        <IsCluster></IsCluster>
        <ReadOnlyUser></ReadOnlyUser>
        <ReadOnlyAllowAcknowledge></ReadOnlyAllowAcknowledge>
        <ReadOnlyPwChange></ReadOnlyPwChange>
    </status>
'@
        # make a cred to use for tests
        $StoredCred = '{"AesKey":[162,160,87,5,70,136,113,133,145,96,37,116,29,27,8,136,13,71,189,50,118,137,87,63,43,56,182,68,48,45,164,185],"Password":"76492d1116743f0423413b16050a5345MgB8AGYAMABiAHcAUgBtADgASgBYAHEASABOAEgAVQBQAHUAdgArAFYAcgBLAEEAPQA9AHwANQBiADAANABiADgAMgA5AGQANQAxAGEAZQBhAGYANgBlAGIAMwA2AGUAOAAyADkAMQBlADIAOAA0ADEAZABmADIANQBkAGIAMAA0ADQAMwBkAGYAZQBjADAAYgBmADgANgA0AGMAOQA5ADAAOQBhAGUAYQA2ADMAMgA2ADQAOAA="}'
        $StoredCred = $StoredCred | ConvertFrom-Json
        $PrtgPassword = ConvertTo-SecureString $StoredCred.Password -Key $StoredCred.AesKey
        $PrtgCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $PrtgUsername, $PrtgPassword

        $PrtgStatusResult = @{'Content' = $PrtgStatus}

        Context "PassHash Provided" {
            Mock Invoke-WebRequest { return $PrtgStatusResult } -ParameterFilter { $Uri -match 'getstatus.xml' }
            Get-PrtgServer -Server $PrtgServer -UserName $PrtgUsername -PassHash $PrtgPassHash -Quiet
            It "PrtgServerObject should have correct Version" {
                $PrtgServerObject.Version | Should -Be '18.2.41.1652+'
            }
            It "PrtgServerObject should have correct Port" {
                $PrtgServerObject.Port | Should -BeExactly 443
            }
            It "PrtgServerObject should have correct Protocol" {
                $PrtgServerObject.Protocol | Should -Be 'https'
            }
            It "PrtgServerObject should have correct Hostname" {
                $PrtgServerObject.Hostname | Should -Be '1.1.1.1'
            }
            It "PrtgServerObject should have correct UserName" {
                $PrtgServerObject.UserName | Should -Be 'JohnDoe'
            }
            It "PrtgServerObject should have correct PassHash" {
                $PrtgServerObject.PassHash | Should -Be '1234567890'
            }
            It "PrtgServerObject should have correct UrlHistory" {
                $PrtgServerObject.UrlHistory[0] | Should -Be 'https://1.1.1.1:443/api/getstatus.xml?passhash=1234567890&username=JohnDoe'
            }
            It "PrtgServerObject should have correct RawQueryResultHistory" {
                $PrtgServerObject.RawQueryResultHistory.Count | Should -Be 1
            }
            It "PrtgServerObject should have correct QueryHistory" {
                $PrtgServerObject.QueryHistory.Count | Should -Be 1
            }
            It "PrtgServerObject should have correct LastError" {
                $PrtgServerObject.LastError | Should -BeNullOrEmpty
            }
            It "PrtgServerObject should have correct LastResult" {
                $PrtgServerObject.LastResult | Should -Not -Be $null
            }
            It "PrtgServerObject should have correct NewAlarms" {
                $PrtgServerObject.NewAlarms | Should -Be 0
            }
            It "PrtgServerObject should have correct Alarms" {
                $PrtgServerObject.Alarms | Should -Be 21
            }
            It "PrtgServerObject should have correct AckAlarms" {
                $PrtgServerObject.AckAlarms | Should -Be 7
            }
            It "PrtgServerObject should have correct NewToDos" {
                $PrtgServerObject.NewToDos | Should -Be 0
            }
            It "PrtgServerObject should have correct Clock" {
                $PrtgServerObject.Clock | Should -Be '12/12/2018 4:33:04 PM'
            }
            It "PrtgServerObject should have correct ClockasDateTime" {
                $PrtgServerObject.ClockasDateTime | Should -Be (Get-Date '2018-12-12T16:33:04.0000000')
            }
            It "PrtgServerObject should have correct ActivationStatusMessage" {
                $PrtgServerObject.ActivationStatusMessage | Should -Be '(Tag activationstatusalert unknown)'
            }
            It "PrtgServerObject should have correct BackgroundTasks" {
                $PrtgServerObject.BackgroundTasks | Should -Be 0
            }
            It "PrtgServerObject should have correct CorrelationTasks" {
                $PrtgServerObject.CorrelationTasks | Should -Be 0
            }
            It "PrtgServerObject should have correct AutoDiscoTasks" {
                $PrtgServerObject.AutoDiscoTasks | Should -Be 0
            }
            It "PrtgServerObject should have correct PRTGUpdateAvailable" {
                $PrtgServerObject.PRTGUpdateAvailable | Should -BeTrue
            }
            It "PrtgServerObject should have correct IsAdminUser" {
                $PrtgServerObject.IsAdminUser | Should -BeTrue
            }
            It "PrtgServerObject should have correct IsCluster" {
                $PrtgServerObject.IsCluster | Should -BeFalse
            }
            It "PrtgServerObject should have correct ReadOnlyUser" {
                $PrtgServerObject.ReadOnlyUser | Should -BeFalse
            }
            It "PrtgServerObject should have correct ReadOnlyAllowAcknowledge" {
                $PrtgServerObject.ReadOnlyAllowAcknowledge | Should -BeFalse
            }
        }

        $PrtgPassHashResult = @{'Content' = $PrtgPassHash}

        Context "Credential Provided" {
            Mock Invoke-WebRequest { return $PrtgPassHashResult } -ParameterFilter { $Uri -match 'getpasshash.htm' }
            Mock Invoke-WebRequest { return $PrtgStatusResult } -ParameterFilter { $Uri -match 'getstatus.xml' }

            Get-PrtgServer -Server $PrtgServer -Credential $PrtgCred -Quiet
            It "PrtgServerObject should have correct Version" {
                $PrtgServerObject.Version | Should -Be '18.2.41.1652+'
            }
            It "PrtgServerObject should have correct Port" {
                $PrtgServerObject.Port | Should -BeExactly 443
            }
            It "PrtgServerObject should have correct Protocol" {
                $PrtgServerObject.Protocol | Should -Be 'https'
            }
            It "PrtgServerObject should have correct Hostname" {
                $PrtgServerObject.Hostname | Should -Be '1.1.1.1'
            }
            It "PrtgServerObject should have correct UserName" {
                $PrtgServerObject.UserName | Should -Be 'JohnDoe'
            }
            It "PrtgServerObject should have correct PassHash" {
                $PrtgServerObject.PassHash | Should -Be '1234567890'
            }
            It "PrtgServerObject should have correct UrlHistory" {
                $PrtgServerObject.UrlHistory[0] | Should -Be 'https://1.1.1.1:443/api/getpasshash.htm?username=JohnDoe&password=PASSWORDREDACTED'
            }
            It "PrtgServerObject should have correct RawQueryResultHistory" {
                $PrtgServerObject.RawQueryResultHistory.Count | Should -Be 2
            }
            It "PrtgServerObject should have correct QueryHistory" {
                $PrtgServerObject.QueryHistory.Count | Should -Be 2
            }
            It "PrtgServerObject should have correct LastError" {
                $PrtgServerObject.LastError | Should -BeNullOrEmpty
            }
            It "PrtgServerObject should have correct LastResult" {
                $PrtgServerObject.LastResult | Should -Not -Be $null
            }
            It "PrtgServerObject should have correct NewAlarms" {
                $PrtgServerObject.NewAlarms | Should -Be 0
            }
            It "PrtgServerObject should have correct Alarms" {
                $PrtgServerObject.Alarms | Should -Be 21
            }
            It "PrtgServerObject should have correct AckAlarms" {
                $PrtgServerObject.AckAlarms | Should -Be 7
            }
            It "PrtgServerObject should have correct NewToDos" {
                $PrtgServerObject.NewToDos | Should -Be 0
            }
            It "PrtgServerObject should have correct Clock" {
                $PrtgServerObject.Clock | Should -Be '12/12/2018 4:33:04 PM'
            }
            It "PrtgServerObject should have correct ClockasDateTime" {
                $PrtgServerObject.ClockasDateTime | Should -Be (Get-Date '2018-12-12T16:33:04.0000000')
            }
            It "PrtgServerObject should have correct ActivationStatusMessage" {
                $PrtgServerObject.ActivationStatusMessage | Should -Be '(Tag activationstatusalert unknown)'
            }
            It "PrtgServerObject should have correct BackgroundTasks" {
                $PrtgServerObject.BackgroundTasks | Should -Be 0
            }
            It "PrtgServerObject should have correct CorrelationTasks" {
                $PrtgServerObject.CorrelationTasks | Should -Be 0
            }
            It "PrtgServerObject should have correct AutoDiscoTasks" {
                $PrtgServerObject.AutoDiscoTasks | Should -Be 0
            }
            It "PrtgServerObject should have correct PRTGUpdateAvailable" {
                $PrtgServerObject.PRTGUpdateAvailable | Should -BeTrue
            }
            It "PrtgServerObject should have correct IsAdminUser" {
                $PrtgServerObject.IsAdminUser | Should -BeTrue
            }
            It "PrtgServerObject should have correct IsCluster" {
                $PrtgServerObject.IsCluster | Should -BeFalse
            }
            It "PrtgServerObject should have correct ReadOnlyUser" {
                $PrtgServerObject.ReadOnlyUser | Should -BeFalse
            }
            It "PrtgServerObject should have correct ReadOnlyAllowAcknowledge" {
                $PrtgServerObject.ReadOnlyAllowAcknowledge | Should -BeFalse
            }
        }

        Context "Test Custom Port/Protocol" {
            Mock Invoke-WebRequest { return $PrtgStatusResult } -ParameterFilter { $Uri -match 'getstatus.xml' }
            Get-PrtgServer -Server $PrtgServer -UserName $PrtgUsername -PassHash $PrtgPassHash -Quiet -HttpOnly -Port 444
            It "PrtgServerObject should have correct Port" {
                $PrtgServerObject.Port | Should -BeExactly 444
            }
            It "PrtgServerObject should have correct Protocol" {
                $PrtgServerObject.Protocol | Should -Be 'http'
            }
        }
    }
}