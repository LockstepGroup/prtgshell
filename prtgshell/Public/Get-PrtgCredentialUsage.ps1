function Get-PrtgCredentialUsage {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [int[]]$ObjectId
    )

    BEGIN {
        $VerbosePrefix = "Get-PrtgCredentialUsage:"
        if (!($global:PrtgServerObject.Connected)) {
            try {
                Throw
            } catch {
                $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1000, $global:PrtgServerObject.Hostname))
            }
        }

        $ReturnData = @()
    }

    PROCESS {
        Write-Verbose "$VerbosePrefix Checking Credential Usage for Object: $($ObjectId[0])"
        $New = "" | Select-Object -Property ObjectId, ObjectType, WindowsDomain, WindowsUsername, LinuxUsername, EsxUsername, SnmpV3User
        $New.ObjectId = $ObjectId[0]
        $New.ObjectType = $_.GetType().Name
        $New.WindowsDomain = Get-PrtgObjectProperty -Property windowslogindomain -ObjectId $ObjectId
        $New.WindowsUsername = Get-PrtgObjectProperty -Property windowsloginusername -ObjectId $ObjectId
        $New.LinuxUsername = Get-PrtgObjectProperty -Property linuxloginusername -ObjectId $ObjectId
        $New.EsxUsername = Get-PrtgObjectProperty -Property esxuser -ObjectId $ObjectId
        $New.SnmpV3User = Get-PrtgObjectProperty -Property snmpuser -ObjectId $ObjectId

        $ReturnData += $New
    }

    END {
        $ReturnData
    }
}