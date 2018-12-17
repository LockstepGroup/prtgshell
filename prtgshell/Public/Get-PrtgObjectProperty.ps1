function Get-PrtgObjectProperty {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [int[]]$ObjectId,

        [Parameter(Mandatory = $True, Position = 1)]
        [string]$Property
    )

    BEGIN {
        $VerbosePrefix = "Get-PrtgObjectProperty:"
        if (!($global:PrtgServerObject.Connected)) {
            try {
                Throw
            } catch {
                $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1000, $global:PrtgServerObject.Hostname))
            }
        }

        $QueryTable = @{}
        $QueryTable.name = $Property

        $QueryPage = 'getobjectproperty.htm'
        $ReturnData = @()
    }

    PROCESS {
        $QueryTable.id = $ObjectId
        Write-Verbose "Looking up $Property for Object $ObjectId"

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