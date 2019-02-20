function Get-PrtgObjectParentId {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [int[]]$ObjectId
    )

    BEGIN {
        $VerbosePrefix = "Get-PrtgObjectParentId:"
        if (!($global:PrtgServerObject.Connected)) {
            try {
                Throw
            } catch {
                $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1000, $global:PrtgServerObject.Hostname))
            }
        }

        $QueryPage = 'getobjectstatus.htm'
        $ReturnData = @()
    }

    PROCESS {
        $QueryTable = @{
            "id"   = $ObjectId
            "name" = 'parentid'
        }
        Write-Verbose "Looking up Object $ObjectId"

        try {
            $Response = $global:PrtgServerObject.invokeApiQuery($QueryTable, $QueryPage)
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

        $ReturnData += $Response.prtg.result
    }

    END {
        $ReturnData
    }
}