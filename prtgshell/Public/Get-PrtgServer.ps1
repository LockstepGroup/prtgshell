function Get-PrtgServer {
    [CmdletBinding(DefaultParameterSetName = 'PassHash')]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidatePattern("\d+\.\d+\.\d+\.\d+|(\w\.)+\w")]
        [string]$Server,

        [Parameter(ParameterSetName = "PassHash", Mandatory = $True, Position = 1)]
        [string]$UserName,

        [Parameter(ParameterSetName = "PassHash", Mandatory = $True, Position = 2)]
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
            try {
                $global:PrtgServerObject = [PrtgServer]::new($Server, $Credential, $Protocol, $Port)
                Write-Verbose "$VerbosePrefix PassHash successfully generated."
            } catch {
                # originally I was catching specific types of exceptions, but apparently they're different between core and non-core, which is stupid
                switch -Regex ($_.Exception.Message) {
                    '401\ \(Unauthorized\)' {
                        $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1001, $Server))
                    }
                    default {
                        $PSCmdlet.ThrowTerminatingError($PSItem)
                    }
                }
            }
        }

        # Test API connection
        # When generating an api key, the connection is already tested.
        # This grabs version info from the box and tests if you're just
        # supplying an api key yourself.
        Write-Verbose "$VerbosePrefix Attempting to test connection"
        try {
            $TestConnect = $global:PrtgServerObject.testConnection()
        } catch {
            # originally I was catching specific types of exceptions, but apparently they're different between core and non-core, which is stupid
            switch -Regex ($_.Exception.Message) {
                '401\ \(Unauthorized\)' {
                    $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1001, $Server))
                }
                default {
                    $PSCmdlet.ThrowTerminatingError($PSItem)
                }
            }
        }
        if ($TestConnect) {
            if (!($Quiet)) {
                return $global:PrtgServerObject
            }
        } else {
            Throw "$VerbosePrefix testConnection() failed."
        }
    }
}