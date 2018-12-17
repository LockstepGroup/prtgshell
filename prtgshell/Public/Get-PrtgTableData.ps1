function Get-PrtgTableData {
    [CmdletBinding(DefaultParameterSetName = 'PassHash')]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateSet("devices", "groups", "sensors", "todos", "messages", "values", "channels", "history")]
        [string]$Content,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$ObjectId = 0,

        [Parameter(Mandatory = $False)]
        [string[]]$Column,

        <#         [Parameter(Mandatory = $False)]
        [string[]]$FilterTag, #>

        [Parameter(Mandatory = $False)]
        [int]$Count
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

        if ($Count) {
            $QueryTable.count = $Count
        }


        <# if ($Content -eq "sensors" -and $FilterTags) {
            $FilterString = ""

            foreach ($tag in $FilterTags) {
                $FilterString += "&filter_tags=" + $tag
            }
        } #>

        $ValidColumns = @{}
        $ValidColumns.devices = @("objid", "probe", "group", "device", "host", "downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens")
        $ValidColumns.groups = @("objid", "probe", "group", "name", "downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens")
        $ValidColumns.sensors = @("objid", "probe", "group", "device", "sensor", "status", "message", "lastvalue", "lastvalue_raw", "priority", "favorite")
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


        <#         if (!$Columns) {

            # this was pulled mostly from the API doc, with some minor adjustments
            # this function currently doesn't work with "sensortree" or any of the nonspecific values: "reports","maps","storedreports"

            $TableValues = "devices", "groups", "sensors", "todos", "messages", "values", "channels", "history"
            $TableColumns =
            @("objid", "probe", "group", "device", "host", "downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens"),
            @("objid", "probe", "group", "name", "downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens"),
            @("objid", "probe", "group", "device", "sensor", "status", "message", "lastvalue", "lastvalue_raw", "priority", "favorite"),
            @("objid", "datetime", "name", "status", "priority", "message"),
            @("objid", "datetime", "parent", "type", "name", "status", "message"),
            @("datetime", "value_", "coverage"),
            @("name", "lastvalue", "lastvalue_raw"),
            @("dateonly", "timeonly", "user", "message")

            $PRTGTableBuilder = @()

            for ($i = 0; $i -le $TableValues.Count; $i++) {
                $ThisRow = "" | Select-Object @{ n = 'content'; e = { $TableValues[$i] } }, @{ n = 'columns'; e = { $TableColumns[$i] } }
                $PRTGTableBuilder += $ThisRow
            }

            $SelectedColumns = ($PRTGTableBuilder | ? { $_.content -eq $Content }).columns
        } else {
            $SelectedColumns = $Columns
        } #>

        $SelectedColumnsString = $SelectedColumns -join ","

        $HTMLColumns = @("downsens", "partialdownsens", "downacksens", "upsens", "warnsens", "pausedsens", "unusualsens", "undefinedsens", "message", "favorite")
        $QueryPage = 'table.xml'
    }

    PROCESS {
        $QueryTable.content = $Content
        $QueryTable.columns = $SelectedColumnsString
        $QueryTable.id = $ObjectId

        try {
            $ReturnData = $global:PrtgServerObject.invokeApiQuery($QueryTable, $QueryPage)
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

        $ReturnData.$Content.item


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