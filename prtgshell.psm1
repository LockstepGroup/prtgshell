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
        
		$StoredConfiguration = $Return | Select-Object Server,Port,UserName,Protocol,Version,Clock,IsCluster,IsAdminUser,ReadOnlyUser,PassHash
        $StoredConfiguration.PassHash = $PassHash
		
        $global:PrtgServerObject = $StoredConfiguration

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
        [int]$DeviceId,

        [Parameter(Mandatory=$False,Position=1)]
        [int]$SensorId
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
		$url = HelperURLBuilder "table.xml" (
			"&content=sensors",
			"&columns=objid,probe,group,device,sensor,status,",
			"message,lastvalue,priority,favorite,comments",
			"&id=$DeviceId"
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

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
	}

	PROCESS {
		$url = HelperURLBuilder "table.xml" (
			"&content=channels",
			"&columns=name,lastvalue_",
			"&id=$SensorId"
		)

		$Global:LastUrl = $Url

		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
		
		$ChannelProperties = @("name","lastvalue","lastvalue_raw")
		$Channels = @()

		foreach ($item in $Data.channels.item) {
			$Channel = "" | Select-Object $ChannelProperties
			foreach ($Prop in $ChannelProperties) {
				$Channel.$Prop = $item.$Prop
			}
			$Channels += $Channel
		}

		return $Channels
	}
}

###############################################################################

function Get-PrtgParentProbe {
# can this be expanded out to all objects (devices, sensors, groups)?
# maybe not.
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$DeviceId
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
		$url = HelperURLBuilder "table.xml" (
			"&content=devices",
			"&output=xml",
			"&columns=objid,probe"
		)

        $global:lasturl = $url
        
		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data

        return ($Data.devices.item | where {$_.objid -eq "$DeviceId"}).probe
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
		[Parameter(Mandatory=$True,Position=0)]
		[int]$ObjectId,
		
		[Parameter(Mandatory=$True,Position=1)]
		[string]$Content
	)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		
		$TableValues = "sensortree","devices","groups","sensors","todos","messages","values","channels","reports","maps","storedreports","history"
		$TableColumns = @(""),
			@("objid","probe","group","device","host","downsens","partialdownsens","downacksens","upsens","warnsens","pausedsens","unusualsens","undefinedsens"),
			@("objid","probe","group","name","downsens","partialdownsens","downacksens","upsens","warnsens","pausedsens","unusualsens","undefinedsens"),
			@("objid","probe","group","device","sensor","status","message","lastvalue","priority","favorite"),
			@("objid","datetime","name","status","priority","message"),
			@("objid","datetime","parent","type","name","status","message"),
			@("datetime","value_","coverage"),
			@("name","lastvalue","lastvalue_raw"),
			@("objid","name","template","period","schedule","email","lastrun","nextrun"),
			@("objid","name"),
			@("name","datetime","size"),
			@("dateonly","timeonly","user","message")
		
		$PRTGTableBuilder = @()

		for ($i = 0; $i -le $TableValues.Count; $i++) {
			$ThisRow = "" | Select-Object @{ n='content'; e={ $TableValues[$i] } },@{ n='columns'; e={ $TableColumns[$i] } }
			$PRTGTableBuilder += $ThisRow
		}
	}

	PROCESS {
	
		$SelectedColumns = ($PRTGTableBuilder | ? { $_.content -eq $Content }).columns
		$SelectedColumnsString = $SelectedColumns -join ","
	
		$url = HelperURLBuilder "table.xml" (
			"&content=$Content",
			"&columns=$SelectedColumnsString",
			"&id=$ObjectId"
		)

		$Global:LastUrl = $Url

		$QueryObject = HelperHTTPQuery $url -AsXML
		$Data = $QueryObject.Data
		
		$ReturnData = @()

		foreach ($item in $Data.$Content.item) {
			$ThisRow = "" | Select-Object $SelectedColumns
			foreach ($Prop in $SelectedColumns) {
				$ThisRow.$Prop = $item.$Prop
			}
			$ReturnData += $ThisRow
		}

		return $ReturnData
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


###############################################################################
## PowerShell Module Functions
###############################################################################

Export-ModuleMember *-*
