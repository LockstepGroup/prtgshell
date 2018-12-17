function Invoke-PrtgApiQuery {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$QueryPage,

        [Parameter(Mandatory = $True, Position = 1)]
        [hashtable]$QueryHashtable
    )

    BEGIN {
        $VerbosePrefix = "Invoke-PrtgApiQuery:"
    }

    PROCESS {
        if ($global:PrtgServerObject.Connected) {
            try {
                $global:PrtgServerObject.invokeApiQuery($QueryPage, $QueryHashtable)
            } catch {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"No Prtg connection established. Use Get-PrtgServer to connect first."),
                        '1000',
                        [System.Management.Automation.ErrorCategory]::CloseError,
                        $Server
                    )
                )
            }
        } else {
            try {
                throw
            } catch {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"No Prtg connection established. Use Get-PrtgServer to connect first."),
                        '1000',
                        [System.Management.Automation.ErrorCategory]::CloseError,
                        $Server
                    )
                )
            }
        }

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
                        $PSCmdlet.ThrowTerminatingError(
                            [System.Management.Automation.ErrorRecord]::new(
                                ([System.ArgumentException]"Unauthorized, please check your credentials."),
                                '1000',
                                [System.Management.Automation.ErrorCategory]::CloseError,
                                $Server
                            )
                        )
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
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                            ([System.ArgumentException]"Unauthorized, please check your credentials."),
                            '1000',
                            [System.Management.Automation.ErrorCategory]::CloseError,
                            $Server
                        )
                    )
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