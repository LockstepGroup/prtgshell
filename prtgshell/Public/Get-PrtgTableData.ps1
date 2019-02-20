function Get-PrtgTableData {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateSet('probes', "devices", "groups", "sensors", "todos", "messages", "values", "channels", "history")]
        [string]$Content,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$ObjectId = 0,

        [Parameter(Mandatory = $False)]
        [string[]]$Column,

        <#         [Parameter(Mandatory = $False)]
        [string[]]$FilterTag, #>

        [Parameter(Mandatory = $False)]
        [int]$Count = 500,

        [Parameter(Mandatory = $False)]
        [int]$StartNumber
    )

    BEGIN {
        $VerbosePrefix = "Get-PrtgTableData:"
        if (!($global:PrtgServerObject.Connected)) {
            try {
                Throw
            } catch {
                $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1000, $global:PrtgServerObject.Hostname))
            }
        }

        $QueryTable = @{}
        $Batching = $false

        $global:PrtgServerObject.ReturnCount = $Count
        $global:PrtgServerObject.CurrentStartPosition = $StartNumber

        <# if ($Content -eq "sensors" -and $FilterTags) {
            $FilterString = ""

            foreach ($tag in $FilterTags) {
                $FilterString += "&filter_tags=" + $tag
            }
        } #>

        $ValidColumns = @{}
        $ValidColumns.probes = @("objid", "type", "name", "tags", "active", "probe", "notifiesx", "intervalx", "access", "dependency", "probegroupdevice", "status", "message", "priority", "upsens", "downsens", "downacksens", "partialdownsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens", "totalsens", "favorite", "schedule", "comments", "condition", "basetype", "baselink", "parentid", "fold", "groupnum", "devicenum")
        $ValidColumns.devices = @("objid", "probe", "group", "device", "host", "downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens")
        $ValidColumns.groups = @("objid", "probe", "group", "name", "downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens")
        $ValidColumns.sensors = @("parentid", "objid", "probe", "group", "device", "sensor", "status", "message", "lastvalue", "lastvalue_raw", "priority", "favorite")
        $ValidColumns.todos = @("objid", "datetime", "name", "status", "priority", "message")
        $ValidColumns.messages = @("objid", "datetime", "parent", "type", "name", "status", "message")
        $ValidColumns.values = @("datetime", "value_", "coverage")
        $ValidColumns.channels = @("name", "lastvalue", "lastvalue_raw")
        $ValidColumns.history = @("dateonly", "timeonly", "user", "message")

        $ValidColumnsForContent = $ValidColumns.$Content

        if ($Column) {
            foreach ($col in $Column) {
                if ($ValidColumnsForContent -notcontains $col) {
                    try {
                        throw
                    } catch {
                        $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1002, $col))
                    }
                }
            }
            $SelectedColumns = $Column
        } else {
            $SelectedColumns = $ValidColumnsForContent
        }

        $SelectedColumnsString = $SelectedColumns -join ","

        $HTMLColumns = @("downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens", "message", "favorite")
        $QueryPage = 'table.xml'
        $ReturnData = @()
    }

    PROCESS {
        $QueryTable.content = $Content
        $QueryTable.columns = $SelectedColumnsString
        $QueryTable.id = $ObjectId

        if ($Batching) {

        } else {
            try {
                $Response = $global:PrtgServerObject.invokeApiQuery($QueryTable, $QueryPage, $Content)
            } catch {
                # originally I was catching specific types of exceptions, but apparently they're different between core and non-core, which is stupid
                switch -Regex ($_.Exception.Message) {
                    '401\ \(Unauthorized\)' {
                        $PSCmdlet.ThrowTerminatingError([HelperProcessError]::throwCustomError(1001, $Server))
                    }
                    default {
                        Throw $_
                        #$PSCmdlet.ThrowTerminatingError($PSItem)
                    }
                }
            }

            foreach ($obj in $Response) {
                switch ($Content) {
                    'devices' {
                        $ReturnData += [PrtgDevice]::new($obj)
                        continue
                    }
                    'groups' {
                        $ReturnData += [PrtgGroup]::new($obj)
                        continue
                    }
                    'probes' {
                        if ($obj.type -ne 'Probe') {
                            continue
                        }
                        $ReturnData += [PrtgProbe]::new($obj)
                        continue
                    }
                    default {
                        $ReturnData = $Response
                    }
                }
            }
        }

        $ReturnData


        <#         $url = HelperURLBuilder "table.xml" (
            "&content=$Content",
            "&columns=$SelectedColumnsString",
            "&id=$ObjectId",
            $FilterString,
            $CountString
        ) #>

        #$Global:LastUrl = $Url

        <#         if ($Raw) {
            $QueryObject = HelperHTTPQuery $url
            return $QueryObject.Data
        } #>
        <#
        $QueryObject = HelperHTTPQuery $url -AsXML
        $Data = $QueryObject.Data

        $ReturnData = @()

        foreach ($item in $Data.$Content.item) {
            $ThisRow = "" | Select-Object $SelectedColumns
            foreach ($Prop in $SelectedColumns) {
                if ($Content -eq "channels" -and $Prop -eq "lastvalue_raw") {
                    # fix a bizarre formatting bug
                    $ThisRow.$Prop = HelperFormatHandler $item.$Prop
                } elseif ($HTMLColumns -contains $Prop) {
                    # strip HTML, leave bare text
                    $ThisRow.$Prop = $item.$Prop -replace "<[^>]*?>|<[^>]*>", ""
                } else {
                    $ThisRow.$Prop = $item.$Prop
                }
            }
            $ReturnData += $ThisRow
        }

        if ($ReturnData.name -eq "Item" -or (!($ReturnData.ToString()))) {
            $DeterminedObjectType = Get-PrtgObjectType $ObjectId

            $ValidQueriesTable = @{
                group        = @("devices", "groups", "sensors", "todos", "messages", "values", "history")
                probenode    = @("devices", "groups", "sensors", "todos", "messages", "values", "history")
                device       = @("sensors", "todos", "messages", "values", "history")
                sensor       = @("messages", "values", "channels", "history")
                report       = @("Currently unsupported")
                map          = @("Currently unsupported")
                storedreport = @("Currently unsupported")
            }

            Write-Host "No $Content; Object $ObjectId is type $DeterminedObjectType"
            Write-Host (" Valid query types: " + ($ValidQueriesTable.$DeterminedObjectType -join ", "))
        } else {
            return $ReturnData
        } #>
    }
}