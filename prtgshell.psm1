###############################################################################
## API Functions
###############################################################################

function Get-PrtgServer {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[ValidatePattern("\d+\.\d+\.\d+\.\d+|(\w\.)+\w")]
		[string]$Server,

		[Parameter(Mandatory=$True,Position=1)]
		[string]$UserName,

		[Parameter(Mandatory=$True,Position=2)]
		[string]$PassHash,

		[Parameter(Mandatory=$False,Position=3)]
		[int]$Port = $null,

		[Parameter(Mandatory=$False)]
		[alias('http')]
		[switch]$HttpOnly
	)

    BEGIN {
		if ($HttpOnly) {
			$Protocol = "http"
			if (!$Port) { $Port = 80 }
		} else {
			$Protocol = "https"
			if (!$Port) { $Port = 443 }
			
			HelperSSLConfig
		}
    }

    PROCESS {
		$url = HelperURLBuilder "getstatus.xml" -Protocol $Protocol -Server $Server -Port $Port -UserName $UserName -PassHash $PassHash
		
        $global:lasturl = $url
		
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
				
		$Return = "" | Select-Object Server,Port,UserName,Protocol,Version,Clock,IsCluster,IsAdminUser,ReadOnlyUser
		$Return.Server       = $Server
		$Return.Port         = $Port
		$Return.UserName     = $UserName
		$Return.Protocol     = $Protocol
		$Return.Version      = $Data.status.Version
		$Return.Clock        = $Data.status.Clock
		$Return.IsCluster    = $Data.status.IsCluster
		$Return.IsAdminUser  = $Data.status.IsAdminUser
		$Return.ReadOnlyUser = $Data.status.ReadOnlyUser
        
		$StoredConfiguration = $Return | Select-Object *,PassHash
        $StoredConfiguration.PassHash = $PassHash
		
        $global:PrtgServerObject = $StoredConfiguration
		
		HelperFormatTest

		# this is just to be pretty; doesn't contain the passhash
        return $Return
    }
}

###############################################################################

Set-Alias Move-PrtgSensor Move-PrtgObject
function Move-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
		[alias('SensorId')]
        [int]$ObjectId,

        [Parameter(Mandatory=$True,Position=1)]
        [ValidateSet("up","down","top","bottom")] 
        [string]$Position
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		$WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
		$url = HelperURLBuilder "setposition.htm" (
			"&id=$ObjectId",
			"&newpos=$Position"
		)

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}

###############################################################################

Set-Alias Rename-PrtgSensor Rename-PrtgObject
function Rename-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
		[alias('SensorId')]
        [int]$ObjectId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$NewName
    )

    PROCESS {
		return Set-PrtgObjectProperty $ObjectId "name" $NewName
    }
}

###############################################################################

Set-Alias Copy-PrtgSensor Copy-PrtgObject
function Copy-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
		[alias('SensorId')]
        [int]$ObjectId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Name,
        
        [Parameter(Mandatory=$True,Position=2)]
        [string]$TargetId
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		$WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
		$url = HelperURLBuilder "duplicateobject.htm" (
			"&id=$ObjectId",
			"&name=$Name",
			"&targetid=$TargetId"
		)

        $global:lasturl = $url
        
        $NewIdRx = [regex] '(?<=id%3D)\d+'
        
		###########################################
		# can we let the http function handle this?
		
        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            return $NewIDRx.Match($Res.ResponseUri.PathAndQuery).value
        } else {
            Throw "Error Accessing Page $WebPage"
        }
    }
}

###############################################################################

function Remove-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$ObjectId
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		$WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
		$url = HelperURLBuilder "deleteobject.htm" (
			"&id=$ObjectId",
			"&approve=1"
		)

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}

###############################################################################

function Get-PrtgDeviceSensors {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$DeviceId
    )
	
	Get-PrtgTableData $DeviceId sensors
}

###############################################################################
# need to roll this into get-prtgtabledata

function Get-PrtgDeviceSensorsByTag {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [string[]]$FilterTags,

        [Parameter(Mandatory=$False,Position=1)]
        [int]$SensorId
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
	}

    PROCESS {
	
		# "&id=$DeviceId"   # to get all sensors of a device
		# "&filter_tags=$FilterTags" # to get all sensors with a tag
		
		$url = HelperURLBuilder "table.xml" (
			"&content=sensors",
			"&columns=objid,probe,group,device,sensor,status,",
			"message,lastvalue,priority,favorite,comments",
			"&filter_tags=$FilterTags"
		)
		
        $Global:LastUrl = $Url
        
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
        
		$SensorProperties = @("objid","probe","group","device","sensor","status","status_raw","message","message_raw","lastvalue","lastvalue_raw","priority","favorite","favorite_raw","comments")
		$Sensors = @()
		
        foreach ($item in $Data.sensors.item) {
			$Sensor = "" | Select-Object $SensorProperties
			foreach ($Prop in $SensorProperties) {
				$Sensor.$Prop = $item.$Prop
			}
			$Sensors += $Sensor
		}
		
        return $Sensors
    }
}

###############################################################################

function Resume-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$ObjectId
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		$WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
		$url = HelperURLBuilder "pause.htm" (
			"&id=$ObjectId",
			"&action=1"
		)

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

		###########################################
		# this needs a handler; the output is silly
        return $global:Response
    }
}

###############################################################################

function Set-PrtgObjectProperty {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$ObjectId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Property,

        [Parameter(Mandatory=$True,Position=2)]
        [string]$Value
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		$WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
		$url = HelperURLBuilder "setobjectproperty.htm" (
			"&id=$ObjectId",
			"&name=$Property",
			"&value=$Value"
		)
		
        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}

###############################################################################

Set-Alias Get-PrtgObjectProp Get-PrtgObjectProperty
function Get-PrtgObjectProperty {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
		[alias('DeviceId')]
        [int]$ObjectId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Property
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
		$url = HelperURLBuilder "getobjectproperty.htm" (
			"&id=$ObjectId",
			"&name=$Property",
			"&show=text"
		)

        $global:lasturl = $url
        
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
		
        return $Data.prtg.result
    }
}

###############################################################################

function Get-PrtgSensorChannels {
	<#
		.SYNOPSIS
		
		.DESCRIPTION
		
		.EXAMPLE
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[int]$SensorId
	)

	Get-PrtgTableData $SensorId channels
}

###############################################################################

function Get-PrtgParentProbe {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$DeviceId
    )

	Get-PrtgObjectDetails $DeviceId -Value probename
}


###############################################################################

function Get-PrtgObjectType {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$ObjectId,
		
        [Parameter(Mandatory=$False)]
        [switch]$Detailed
    )

	$ObjectDetails = Get-PrtgObjectDetails $ObjectId
		
	if ($ObjectDetails.interval) {
		if ($ObjectDetails.interval -eq "(Object not found)") {
			# well, why didn't you just say so
			return $ObjectDetails.sensortype
		} else {
			# if it reports an interval, it's a sensor
			if ($Detailed) {
				return ("sensor: " + $ObjectDetails.sensortype)
			} else {
				return "sensor"
			}
		}
	} else {
		# if it doesn't, the sensortype says what it is
		return $ObjectDetails.sensortype
	}
}

###############################################################################

function Get-PrtgObjectDetails {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$ObjectId,
		
        [Parameter(Mandatory=$False)]
        [string]$Value
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
		$url = HelperURLBuilder "getsensordetails.xml" (
			"&id=$ObjectId"
		)

        $global:lasturl = $url
        
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data.sensordata.psobject.properties | ? { $_.TypeNameOfValue -eq "System.Xml.XmlElement" }
	
		$ListOfNames = ($Data | select name).name
		$ListOfValues = (($Data | select value).value)."#cdata-section"
		
		$i = 0
		
		while ($i -lt $ListOfNames.Count) {
			$Return += @{$ListOfNames[$i]=$ListOfValues[$i]}
			$i++
		}
		
		if ($Value) {
			$Return.$Value
		} else {
			$Return
		}
    }
}

###############################################################################

function Get-PrtgTableData {
	<#
		.SYNOPSIS
		
		.DESCRIPTION
		
		.EXAMPLE
	#>

	Param (
		[Parameter(Mandatory=$false,Position=0)]
		[int]$ObjectId = 0,
		
		[Parameter(Mandatory=$True,Position=1)]
		[ValidateSet("devices","groups","sensors","todos","messages","values","channels","history")]
		[string]$Content,
		
		[Parameter(Mandatory=$False)]
		[string[]]$Columns,
		
		[Parameter(Mandatory=$False)]
		[string[]]$FilterTags,
		
		[Parameter(Mandatory=$False)]
		[switch]$Raw
	)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		
		if ($Content -eq "sensors" -and $FilterTags) {
			$FilterString = ""
			
			foreach ($tag in $FilterTags) {
				$FilterString += "&filter_tags=" + $tag
			}
		}
		
		if (!$Columns) {
		
			# this was pulled mostly from the API doc, with some minor adjustments
			# this function currently doesn't work "sensortree" or any of the nonspecific values: "reports","maps","storedreports"
			
			$TableValues = "devices","groups","sensors","todos","messages","values","channels","history"
			$TableColumns =
				@("objid","probe","group","device","host","downsens","partialdownsens","downacksens","upsens","warnsens","pausedsens","unusualsens","undefinedsens"),
				@("objid","probe","group","name","downsens","partialdownsens","downacksens","upsens","warnsens","pausedsens","unusualsens","undefinedsens"),
				@("objid","probe","group","device","sensor","status","message","lastvalue","lastvalue_raw","priority","favorite"),
				@("objid","datetime","name","status","priority","message"),
				@("objid","datetime","parent","type","name","status","message"),
				@("datetime","value_","coverage"),
				@("name","lastvalue","lastvalue_raw"),
				@("dateonly","timeonly","user","message")
			
			$PRTGTableBuilder = @()
			
			for ($i = 0; $i -le $TableValues.Count; $i++) {
				$ThisRow = "" | Select-Object @{ n='content'; e={ $TableValues[$i] } },@{ n='columns'; e={ $TableColumns[$i] } }
				$PRTGTableBuilder += $ThisRow
			}
			
			$SelectedColumns = ($PRTGTableBuilder | ? { $_.content -eq $Content }).columns
		} else {
			$SelectedColumns = $Columns
		}
		
		$SelectedColumnsString = $SelectedColumns -join ","
	}

	PROCESS {
	
		$url = HelperURLBuilder "table.xml" (
			"&content=$Content",
			"&columns=$SelectedColumnsString",
			"&id=$ObjectId",
			$FilterString
		)

		$Global:LastUrl = $Url

		if ($Raw) {
			$QueryObject = HelperHTTPQuery $url
			return $QueryObject.Data
		}
		
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
		
		$ReturnData = @()
		
		foreach ($item in $Data.$Content.item) {
			$ThisRow = "" | Select-Object $SelectedColumns
			foreach ($Prop in $SelectedColumns) {
				if ($Content -eq "channels" -and $Prop -eq "lastvalue_raw") {
					$ThisRow.$Prop = HelperFormatHandler $item.$Prop
				} else {
					$ThisRow.$Prop = $item.$Prop
				}
				#$ThisRow.$Prop = $item.$Prop
			}
			$ReturnData += $ThisRow
		}

		if ($ReturnData.name -eq "Item" -or (!($ReturnData.ToString()))) {
			$DeterminedObjectType = Get-PrtgObjectType $ObjectId
			
			$ValidQueriesTable = @{
				group=@("devices","groups","sensors","todos","messages","values","history")
				probenode=@("devices","groups","sensors","todos","messages","values","history")
				device=@("sensors","todos","messages","values","history")
				sensor=@("messages","values","channels","history")
				report=@("Currently unsupported")
				map=@("Currently unsupported")
				storedreport=@("Currently unsupported")
			}
			
			Write-Host "No $Content; Object $ObjectId is type $DeterminedObjectType"
			Write-Host (" Valid query types: " + ($ValidQueriesTable.$DeterminedObjectType -join ", "))
		} else {
			return $ReturnData
		}
	}
}

###############################################################################

###############################################################################
# custom exe/xml functions

function Set-PrtgResult {
    Param (
    [Parameter(mandatory=$True,Position=0)]
    [string]$Channel,
    
    [Parameter(mandatory=$True,Position=1)]
    [string]$Value,
    
    [Parameter(mandatory=$True,Position=2)]
    [string]$Unit,

    [Parameter(mandatory=$False)]
    [alias('mw')]
    [string]$MaxWarn,

    [Parameter(mandatory=$False)]
    [alias('minw')]
    [string]$MinWarn,
    
    [Parameter(mandatory=$False)]
    [alias('me')]
    [string]$MaxError,
    
    [Parameter(mandatory=$False)]
    [alias('wm')]
    [string]$WarnMsg,
    
    [Parameter(mandatory=$False)]
    [alias('em')]
    [string]$ErrorMsg,
    
    [Parameter(mandatory=$False)]
    [alias('mo')]
    [string]$Mode,
    
    [Parameter(mandatory=$False)]
    [alias('sc')]
    [switch]$ShowChart,
    
    [Parameter(mandatory=$False)]
    [alias('ss')]
    [ValidateSet("One","Kilo","Mega","Giga","Tera","Byte","KiloByte","MegaByte","GigaByte","TeraByte","Bit","KiloBit","MegaBit","GigaBit","TeraBit")]
    [string]$SpeedSize,
    
    [Parameter(mandatory=$False)]
    [alias('dm')]
    [ValidateSet("Auto","All")]
    [string]$DecimalMode,
    
    [Parameter(mandatory=$False)]
    [alias('w')]
    [switch]$Warning
    )
    
    $StandardUnits = @("BytesBandwidth","BytesMemory","BytesDisk","Temperature","Percent","TimeResponse","TimeSeconds","Custom","Count","CPU","BytesFile","SpeedDisk","SpeedNet","TimeHours")
    $LimitMode = $false
    
    $Result  = "  <result>`n"
    $Result += "    <channel>$Channel</channel>`n"
    $Result += "    <value>$Value</value>`n"
    
    if ($StandardUnits -contains $Unit) {
        $Result += "    <unit>$Unit</unit>`n"
    } elseif ($Unit) {
        $Result += "    <unit>custom</unit>`n"
        $Result += "    <customunit>$Unit</customunit>`n"
    }
    
    #<SpeedSize>
	if (!($Value -is [int])) { $Result += "    <float>1</float>`n" }
    if ($Mode)        { $Result += "    <mode>$Mode</mode>`n" }
    if ($MaxWarn)     { $Result += "    <limitmaxwarning>$MaxWarn</limitmaxwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitminwarning>$MinWarn</limitminwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitmaxerror>$MaxError</limitmaxerror>`n"; $LimitMode = $true }
    if ($WarnMsg)     { $Result += "    <limitwarningmsg>$WarnMsg</limitwarningmsg>`n"; $LimitMode = $true }
    if ($ErrorMsg)    { $Result += "    <limiterrormsg>$ErrorMsg</limiterrormsg>`n"; $LimitMode = $true }
    if ($LimitMode)   { $Result += "    <limitmode>1</limitmode>`n" }
    if ($SpeedSize)   { $Result += "    <speedsize>$SpeedSize</speedsize>`n" }
    if ($DecimalMode) { $Result += "    <decimalmode>$DecimalMode</decimalmode>`n" }
    if ($Warning)     { $Result += "    <warning>1</warning>`n" }
    
    if (!($ShowChart)) { $Result += "    <showchart>0</showchart>`n" }
    
    $Result += "  </result>`n"
    
    return $Result
}

###############################################################################
# This is definitely incomplete but works in extremely limited use cases
# todo:
#   adjust "avg" value, which sets the interval of data returned
#   included timestamp on each line of returned data

function Get-PrtgSensorHistoricData {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$SensorId,

		# really, this should be a (negative) timespan
        [Parameter(Mandatory=$True,Position=1)]
        [int]$HistoryInDays,
		
		[Parameter(Mandatory=$True,Position=2)]
        [string]$ChannelName
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		
		$HistoryTimeStart = ((Get-Date).AddDays([System.Math]::Abs($HistoryInDays) * (-1))).ToString("yyyy-MM-dd-HH-mm-ss")
		$HistoryTimeEnd = (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")
		
		# /api/historicdata.xml?id=objectid&avg=0&sdate=2009-01-20-00-00-00&edate=2009-01-21-00-00-00
    }

    PROCESS {
		$url = HelperURLBuilder "historicdata.xml" (
			"&id=$SensorId",
			"&sdate=$HistoryTimeStart",
			"&edate=$HistoryTimeEnd"
		)
		
        $Global:LastUrl = $Url
        
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
		
		# get all channel names returned from history
		$AllChannels = $Data.SelectNodes("/histdata/item[1]//@*") | Select -ExpandProperty "#text" -Unique
		
		# get date from each item node
		$AllDates = $Data.SelectNodes("/histdata/item/datetime")
		
		
		# foreach ($allchannels) { select each channel (as below), add to object }
		
		#return ($Response.SelectNodes("/histdata/item/value_raw[@channel='$ChannelName']") | Measure-Object -Property "#text" -Average).Average
		return $Data.SelectNodes("/histdata/item/value_raw[@channel='$ChannelName']") | Select @{
			n = $ChannelName;
			e = { $_."#text" }
		}
    }
}



###############################################################################
## Helper Functions
###############################################################################
# http://stackoverflow.com/questions/6032344/how-to-hide-helper-functions-in-powershell-modules
# make sure none of these have a dash in their name

function HelperSSLConfig {
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
	[System.Net.ServicePointManager]::Expect100Continue = {$true}
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
}

function HelperHTTPQuery {
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[string]$URL,
		
		[Parameter(Mandatory=$False)]
		[alias('xml')]
		[switch]$AsXML
	)
	
	try {
		$Response = $null
		$Request = [System.Net.HttpWebRequest]::Create($URL)
		$Response = $Request.GetResponse()
		if ($Response) {
			$StatusCode = $Response.StatusCode.value__
			$DetailedError = $Response.GetResponseHeader("X-Detailed-Error")
		}
	}
	catch {
		$ErrorMessage = $Error[0].Exception.ErrorRecord.Exception.Message
		$Matched = ($ErrorMessage -match '[0-9]{3}')
		if ($Matched) {
			throw ('HTTP status code was {0} ({1})' -f $HttpStatusCode, $matches[0])
		}
		else {
			throw $ErrorMessage
		}

		#$Response = $Error[0].Exception.InnerException.Response
		#$Response.GetResponseHeader("X-Detailed-Error")
	}
	
	if ($Response.StatusCode -eq "OK") {
		$Stream    = $Response.GetResponseStream()
		$Reader    = New-Object IO.StreamReader($Stream)
		$FullPage  = $Reader.ReadToEnd()
		
		if ($AsXML) {
			$Data = [xml]$FullPage
		} else {
			$Data = $FullPage
		}
		
		$Global:LastResponse = $Data
		
		$Reader.Close()
		$Stream.Close()
		$Response.Close()
	} else {
		Throw "Error Accessing Page $FullPage"
	}
	
	$ReturnObject = "" | Select-Object StatusCode,DetailedError,Data
	$ReturnObject.StatusCode = $StatusCode
	$ReturnObject.DetailedError = $DetailedError
	$ReturnObject.Data = $Data
	
	return $ReturnObject
}

function HelperURLBuilder {
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[string]$Action,
		
		[Parameter(Mandatory=$false,Position=1)]
		[string[]]$QueryParameters,
		
		[Parameter(Mandatory=$false,Position=2)]
		[string]$Protocol = $Global:PrtgServerObject.Protocol,

		[Parameter(Mandatory=$false,Position=3)]
		[string]$Server = $Global:PrtgServerObject.Server,
		
		[Parameter(Mandatory=$false,Position=4)]
		[int]$Port = $Global:PrtgServerObject.Port,
		
		[Parameter(Mandatory=$false,Position=5)]
		[string]$UserName = $Global:PrtgServerObject.UserName,
		
		[Parameter(Mandatory=$false,Position=6)]
		[string]$PassHash = $Global:PrtgServerObject.PassHash
	)

	$PortString = (":" + ($Port))
	
	$Return =
		$Protocol, "://", $Server, $PortString,
		"/api/",$Action,"?",
		"username=$UserName",
		"&passhash=$PassHash" -join ""
	
	$Return += $QueryParameters -join ""
	
	return $Return
}

function HelperFormatTest {
	$URLKeeper = $global:lasturl
	
	$CoreHealthChannels = Get-PrtgSensorChannels 1002
	$HealthPercentage = $CoreHealthChannels | ? {$_.name -eq "Health" }
	$ValuePretty = [int]$HealthPercentage.lastvalue.Replace("%","")
	$ValueRaw = [int]$HealthPercentage.lastvalue_raw
	
	if ($ValueRaw -eq $ValuePretty) {
		$RawFormatError = $false
	} else {
		$RawFormatError = $true
	}
	
	$global:lasturl = $URLKeeper
	
	$StoredConfiguration = $Global:PrtgServerObject | Select-Object *,RawFormatError
	$StoredConfiguration.RawFormatError = $RawFormatError

	$global:PrtgServerObject = $StoredConfiguration
}

function HelperFormatHandler {
    Param (
        [Parameter(Mandatory=$False,Position=0)]
        $InputData
	)
	
	if (!$InputData) { return }
	
	if ($Global:PrtgServerObject.RawFormatError) {
		# format includes the quirk
		return [double]$InputData.Replace("0.",".")
	} else {
		# format doesn't include the quirk, pass it back
		return [double]$InputData
	}
}

###############################################################################
## PowerShell Module Functions
###############################################################################

Export-ModuleMember *-*
