function Get-PrtgServer {
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidatePattern("\d+\.\d+\.\d+\.\d+|(\w\.)+\w")]
        [string]$Server,

        [Parameter(ParameterSetName = "ApiKey", Mandatory = $True, Position = 1)]
        [string]$UserName,

        [Parameter(ParameterSetName = "ApiKey", Mandatory = $True, Position = 2)]
        [string]$PassHash,

        [Parameter(ParameterSetName = "Credential", Mandatory = $True, Position = 1)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory = $False, Position = 2)]
        [int]$Port = 443,

        [Parameter(Mandatory = $False)]
        [alias('http')]
        [switch]$HttpOnly,

        [Parameter(Mandatory = $False)]
        [switch]$SkipCertificateCheck,

        [Parameter(Mandatory = $False)]
        [alias('q')]
        [switch]$Quiet
    )

    BEGIN {
        $VerbosePrefix = "Get-PrtgServer:"

        if ($HttpOnly) {
            $Protocol = "http"
            if (!$Port) { $Port = 80 }
        } else {
            $Protocol = "https"
            if (!$Port) { $Port = 443 }
        }
    }

    PROCESS {

        if ($PassHash) {
            Write-Verbose "$VerbosePrefix Attempting to connect with provided Username and PassHash"
            $global:PrtgServerObject = [PrtgServer]::new($Server, $UserName, $PassHash, $Protocol, $Port)
        } else {
            Write-Verbose "$VerbosePrefix Attempting to generate PassHash with provided Credential."
            $global:PrtgServerObject = [PrtgServer]::new($Server, $Credential, $Protocol, $Port)
            Write-Verbose "$VerbosePrefix PassHash successfully generated."
        }

        # Test API connection
        # When generating an api key, the connection is already tested.
        # This grabs version info from the box and tests if you're just
        # supplying an api key yourself.
        Write-Verbose "$VerbosePrefix Attempting to test connection"
        $TestConnect = $global:PrtgServerObject.testConnection()
        if ($TestConnect) {
            if (!($Quiet)) {
                return $global:PaDeviceObject
            }
        } else {
            Throw "$VerbosePrefix testConnection() failed."
        }
    }
}