function Get-PrtgObject {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [int[]]$ObjectId
    )

    BEGIN {
        $VerbosePrefix = "Get-PrtgObject:"
        if (!($global:PrtgServerObject.Connected)) {
            try {
                Throw
            } catch {
                $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1000, $global:PrtgServerObject.Hostname))
            }
        }

        $QueryPage = 'table.xml'
        $ReturnData = @()
    }

    PROCESS {
        $QueryTable = @{
            "content" = "sensortree"
            "id"      = $ObjectId
            "columns" = 'objid,probe,group,device,host,downsens,partialdownsens,downacksens,upsens,warnsens,pausedsens,unusualsens,undefinedsens'
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

        $Nodes = $Response.prtg.sensortree.nodes
        $global:Nodes = $Nodes

        if ($Nodes.device) {
            $Object = [PrtgDevice]::new()
            $Object.Name = $Nodes.device.name
            $Object.ObjectId = $Nodes.device.id[0]
            $Object.Hostname = $Nodes.device.host

            $ReturnData += $Object
        } else {
            Throw "Only works on devices right now"
        }
    }

    END {
        $ReturnData
    }
}