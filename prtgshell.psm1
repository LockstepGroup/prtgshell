###############################################################################
## API Functions
###############################################################################

function Get-PrtgServer {
	<#
	.SYNOPSIS
		Establishes initial connection to PRTG API.
		
	.DESCRIPTION
		The Get-PrtgServer cmdlet establishes and validates connection parameters to allow further communications to the PRTG API. The cmdlet needs at least three parameters:
		 - The server name (without the protocol)
		 - An authenticated username
		 - A passhash that can be retrieved from the PRTG user's "My Account" page.
		
		Alias Connect-PrtgServer
		The cmdlet returns an object containing details of the connection, but this can be discarded or saved as desired; the returned object is not necessary to provide to further calls to the API.
	
	.EXAMPLE
		Get-PrtgServer "prtg.company.com" "jsmith" 1234567890
		
		Connects to PRTG using the default port (443) over SSL (HTTPS) using the username "jsmith" and the passhash 1234567890.
		
	.EXAMPLE
		Get-PrtgServer "prtg.company.com" "jsmith" 1234567890 -HttpOnly
		
		Connects to PRTG using the default port (80) over SSL (HTTP) using the username "jsmith" and the passhash 1234567890.
		
	.EXAMPLE
		Get-PrtgServer -Server "monitoring.domain.local" -UserName "prtgadmin" -PassHash 1234567890 -Port 8080 -HttpOnly
		
		Connects to PRTG using port 8080 over HTTP using the username "prtgadmin" and the passhash 1234567890.
		
	.PARAMETER Server
		Fully-qualified domain name for the PRTG server. Don't include the protocol part ("https://" or "http://").
		
	.PARAMETER UserName
		PRTG username to use for authentication to the API.
		
	.PARAMETER PassHash
		PassHash for the PRTG username. This can be retrieved from the PRTG user's "My Account" page.
	
	.PARAMETER Port
		The port that PRTG is running on. This defaults to port 443 over HTTPS, and port 80 over HTTP.
	
	.PARAMETER HttpOnly
		When specified, configures the API connection to run over HTTP rather than the default HTTPS.
	#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern("\d+\.\d+\.\d+\.\d+|(\w\.)+\w")]
		[string]$Server,

		[Parameter(Mandatory=$True,Position=1)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,

		[Parameter(Mandatory=$True,Position=2)]
		[ValidateNotNullOrEmpty()]
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
	END {}
}
Set-Alias Connect-PrtgServer Get-PrtgServer

function Get-PrtgServerStatus {
	<#
	.SYNOPSIS
		Get current system status
		
	.DESCRIPTION
		This a lightweight call to get status data like number of alarms, messages.
	
	.EXAMPLE
		Get-PrtgServerStatus
		
	#>

	[CmdletBinding()]
	Param (
			[Parameter(Mandatory=$False)]
			[switch]$Raw
	)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
	}
	
	PROCESS {
		$url = HelperURLBuilder "getstatus.xml" (
			"&id=0"
		)

		$global:lasturl = $url
		
		if ($Raw) {
			$QueryObject = HelperHTTPQuery $url
			$QueryObject.Data
		}
		Else {
			$QueryObject = HelperHTTPQuery $url -AsXML
			
			Write-Debug $QueryObject.Data.Status
			
			Return $QueryObject.Data.Status
			break
			
			$Data = $QueryObject.Data.status.psobject.properties | ? { $_.TypeNameOfValue -eq "System.Xml.XmlElement" }
		
			$ListOfNames = $Data | ForEach-Object { $_.Name }
			$ListOfValues = $Data | ForEach-Object { $_.Value."#cdata-section" }
			
			Write-Debug $ListOfNames
			Write-Debug $ListOfValues

			$i = 0
			
			while ($i -lt $ListOfNames.Count) {
				$Return += @{$ListOfNames[$i]=$ListOfValues[$i]}
				$i++
			}
			
			if ($Value) {
				$Return.$Value
			} else {
				[Collections.SortedList]$Return
			}
		}
	}
	
}

###############################################################################

function Get-PrtgDeviceByHostname {
	<#
	.SYNOPSIS
		Find PRTG device with hostname
	.DESCRIPTION
		Find PRTG device which matches hostname, IP Address, or FQDN.
	
	.EXAMPLE

	#>

		[CmdletBinding()]
		Param(		
				#  string to search devices
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
				[Alias('IPAddress','FQDN')]
        [String] $hostname,
				
				[Parameter()]
				[Alias('Id','AsId')]
    		[Switch] $AsObjID
		)
    
    # Try to get the PRTG device tree
    try{
        $prtgDeviceTree = Get-PrtgTableData -content "devices"
				Write-Verbose "Device tree count: $prtgDeviceTree.Count"
    }catch{
        Write-Error "Failed to get PRTG Device tree $($_.exception.message)";
        return $false;
    }
    
    $fqdn = $null;
    $ipAddress = $null;

    try{
        $fqdn = [System.Net.Dns]::GetHostByName($hostname).HostName;
    }catch{
        Write-Warning "Unable to get the FQDN for $hostname, match likelihood reduced";
    }
    try{
        $ipAddress = [System.Net.Dns]::GetHostAddresses($fqdn) | ?{$_.addressFamily -eq "InterNetwork"}; # Where IP address is ipv4
    }catch{
        Write-Warning "Unable to get the IP for $hostname, match likelihood reduced";
    }

		Write-Verbose "$hostname - $fqdn - $ipAddress"
    # Search for a PRTG device that matches either the hostname, the IP, or the FQDN
		$nameSearch = $prtgDeviceTree | ?{
        $_.host -like $hostname -or 
        $_.host -eq $ipAddress -or 
        $_.host -eq $fqdn
    }

    if(($nameSearch|Measure-Object).Count -eq 1){
			Write-Verbose "Found PRTG device #$($nameSearch.objid) - $($nameSearch.device)";
			If ($AsObjID) { 
				$nameSearch.objid
			}
			else {
				$nameSearch
			}
    }else{
        Write-Warning "There were $(($nameSearch|Measure-Object).Count) matches for this device in PRTG, use this to narrow it down"
				Write-Output $nameSearch
    }
}

Set-Alias Find-PrtgDevice Get-PrtgDeviceByHostname
###############################################################################
function Get-PrtgObjectDetails {
	<#
	.SYNOPSIS
		Provides details for the specified object.
		
	.DESCRIPTION
		The Get-PrtgObjectDetails provides metadata about a given object in PRTG. This includes the object name and type, information about the parent device and the probe, last status information, and uptime summaries.
		
		For objects other than sensors, this will only report around half of the listed values. Sensor objects will return all of the values.
		
		The Value parameter can be used to return a single named value rather than the complete hash table.
		
	.EXAMPLE
		Get-PrtgObjectDetails 1002
		
		Returns details for object 1002, which is typically the Core Server's Probe Device Core Health sensor.
		
	.EXAMPLE
		Get-PrtgObjectDetails -ObjectId 40 -Value sensortype
		
		Returns the sensortype of object 40, which is typically the Core Server Prove Device.
		
	.PARAMETER ObjectId
		An object ID from PRTG. Objects include probes, groups, devices, and sensors, as well as reports, maps, and todos.
		
	.PARAMETER Value
		If the Value parameter is specified, the cmdlet will return a simple string containing the named value specified. 
	#>

    [CmdletBinding()]
		Param (
				# ID of the object to query
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [Alias('DeviceId')]
				[int]$ObjectId,
		
        # Value to filter on the object
        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
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
		
			$ListOfNames = $Data | ForEach-Object { $_.Name }
			$ListOfValues = $Data | ForEach-Object { $_.Value."#cdata-section" }
			
			$i = 0
			
			while ($i -lt $ListOfNames.Count) {
				$Return += @{$ListOfNames[$i]=$ListOfValues[$i]}
				$i++
			}
			
			if ($Value) {
				$Return.$Value
			} else {
				[Collections.SortedList]$Return
			}
	}
}

function Get-PrtgObjectType {
	<#
	.SYNOPSIS
		Returns the object of a given object ID.
	.DESCRIPTION
		This cmdlet simply returns a string value identifying the object type of the requested object. It can return "group", "probenode", "device", or "sensor", as well as other object types such as reports and maps. If the -Detailed switch is used, it will also report additional details about sensor types.
	.EXAMPLE
		Get-PrtgObjectType 40
		
		Reports "device", as object 40 refers to the Core Server device.
		
	.EXAMPLE
		Get-PrtgObjectType 1002
		
		Reports "sensor", referring to the Core State sensor on the Core Server device.
		
	.EXAMPLE
		Get-PrtgObjectType 1002 -Detailed
		
		Reports "sensor: corestate", referring to the Core State sensor on the Core Server device.
		
	.PARAMETER ObjectId
		An object ID from PRTG. Objects include probes, groups, devices, and sensors, as well as reports, maps, and todos.
		
	.PARAMETER Detailed
		If the Detailed switch is set, the cmdlet will return additional details about sensor types (but not group, device, probenode, or other object types).
	#>

    [CmdletBinding()]
		Param (
				# ID of the object to query
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [Alias('DeviceId')]
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

function Get-PrtgObjectProperty {
	<#
	.SYNOPSIS
		Get object property/setting 
	.DESCRIPTION
		
	.EXAMPLE
		
	#>
		
		[CmdletBinding()]
    Param (
        # ID of the object to query
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [Alias('DeviceId')]
				[int]$ObjectId,
        
        # Name of the object's property to get
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$Property,
				
				[Parameter(Mandatory=$False)]
				[switch]$Raw
		)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
	}

	PROCESS {
		# $url = HelperURLBuilder "getobjectproperty.htm" (
		$url = HelperURLBuilder "getobjectstatus.htm" (
			"&id=$ObjectId",
			"&name=$Property",
			"&show=text"
		)

		$Global:LastUrl = $Url
		
		Write-Verbose $Url
		
		if ($Raw) {
			$QueryObject = HelperHTTPQuery $url
			$QueryObject.Data
		}
		Else {
			$QueryObject = HelperHTTPQuery $url -AsXML
			$Data = $QueryObject.Data
			
			$Data.prtg.result
		}
	}
}

Function Get-PrtgObjectStatus {
	<#
	.SYNOPSIS
		Get object status
	.DESCRIPTION
		
	.EXAMPLE
		
	#>
	
	[CmdletBinding()]
	Param(
			# ID of the object to query
			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			[ValidateScript({$_ -gt 0})]
			[Alias('DeviceId','SensorId')]
			[int]$ObjectId
	)

    $StatusMapping = @{
        1="Unknown"
        2="Scanning"
        3="Up"
        4="Warning"
        5="Down"
        6="No Probe"
        7="Paused by User"
        8="Paused by Dependency"
        9="Paused by Schedule"
        10="Unusual"
        11="Not Licensed" 
        12="Paused Until"
    }

    Try {
        $statusID = (Get-PrtgObjectProperty -ObjectId $ObjectId -Property 'status' -ErrorAction Stop).TrimEnd(' ')
				Write-Verbose "StatusID is [$statusID]"
    }
		Catch {
        Write-Error "Unable to get object status`r`n$($_.exception.message)"
        $false
    }
    # $result = @{'objid'=$ObjectId;"status"=$StatusMapping[[int]$statusID];"status_raw"=$statusID}
    # @{'objid'=$ObjectId;"status"=$StatusMapping[[int]$statusID];"status_raw"=$statusID}

    # $result = [pscustomobject][ordered]@{
    [pscustomobject][ordered]@{
			'objid'				=	$ObjectId
			'status'			=	$statusID
			# 'status'			=	$Fred[[int]$statusID]
			# 'status_raw'	=	$statusID
		}

}

function Set-PrtgObjectProperty {
	<#
		.SYNOPSIS
			Change properties of object			
		.DESCRIPTION
			Change properties of object
			
			If $Property = 'priority', Set priority of an object (valid values are 1 to 5). 
		
		.EXAMPLE
			Set-PrtgObjectProperty 2512 name newname

			.EXAMPLE
			Set-PrtgObjectProperty 2512 -Priority 4

	#>

		[CmdletBinding()]
		Param (
				# ID of the object to query
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [Alias('DeviceId','SensorId')]
				[int]$ObjectId,
        
        # Name of the object's property to get
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name','Priority')]
        [string]$Property,

        # Value to which to set the property of the object
        [Parameter(Mandatory=$True,Position=2)]
        [ValidateNotNullOrEmpty()]
				[string]$Value
    )

    BEGIN {
			$PRTG = $Global:PrtgServerObject
			if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
			# $WebClient = New-Object System.Net.WebClient
    }

		# /api/setpriority.htm?id=objectid&prio=x 

    PROCESS {
			If ($Property -eq 'priority') {
				$url = HelperURLBuilder "setpriority.htm" (
					"&id=$ObjectId",
					"&prio=$Value"
				)
      }
			Else {
				$url = HelperURLBuilder "setobjectproperty.htm" (
					"&id=$ObjectId",
					"&name=$Property",
					"&value=$Value"
				)
			}
			
			$global:lasturl = $url
			$QueryObject = (HelperHTTPQuery $url) -replace "<[^>]*?>|<[^>]*>", ""
			return "" | select @{n='ObjectID';e={$ObjectId}},@{n='Property';e={$Property}},@{n='Value';e={$Value}},@{n='Response';e={$QueryObject}}
			# $global:Response = ($WebClient.DownloadString($url)) -replace "<[^>]*?>|<[^>]*>", ""
			# return "" | select @{n='ObjectID';e={$ObjectId}},@{n='Property';e={$Property}},@{n='Value';e={$Value}},@{n='Response';e={$global:Response}}
    }
}

function Set-PrtgObjectGeo {
	<#
	.SYNOPSIS
		set the geo location of an object			
	.DESCRIPTION
					
	.EXAMPLE
	Set-PrtgObjectGeo -ObjectId 6250 -Geo '-27.465358, 153.029785' -Location 'NextDC B1 Brisbane'
	
	Sets Geo location of this group object to NextDC B1.
	
	#>

		[CmdletBinding()]
		Param (
				# ID of the object to set
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [Alias('DeviceId')]
				[int]$ObjectId,

        # Name of the object's property to get
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$Location,
        
        # Value to which to set the geo location property of the object
        [Parameter(Mandatory=$True,Position=2)]
        [ValidateNotNullOrEmpty()]
        [Alias('lonlat')]
				[string]$Geo
		)

    BEGIN {
			$PRTG = $Global:PrtgServerObject
			if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
			# $WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
			$url = HelperURLBuilder "setlonlat.htm" (
							"&id=$ObjectId",
							"&lonlat=$Geo",
							"&location=$location"
			)
                
			$global:lasturl = $url
			$QueryObject = (HelperHTTPQuery $url) -replace "<[^>]*?>|<[^>]*>", ""
			return "" | select @{n='ObjectID';e={$ObjectId}},@{n='Property';e={$Property}},@{n='Value';e={$Value}},@{n='Response';e={$QueryObject}}
			# $global:Response = ($WebClient.DownloadString($url)) -replace "<[^>]*?>|<[^>]*>", ""
			# return "" | select @{n='ObjectID';e={$ObjectId}},@{n='Property';e={$Property}},@{n='Value';e={$Value}},@{n='Response';e={$global:Response}}
    }
}

Set-Alias Set-PrtgObjectLocation Set-PrtgObjectGeo

###############################################################################

function Get-PrtgTableData {
	<#
		.SYNOPSIS
			Returns a PowerShell object containing data from the specified object in PRTG.
			
		.DESCRIPTION
			The Get-PrtgTableData cmdlet can return data of various different content types using the specified parent object, as well as specify the return columns or filtering options. The input formats generally coincide with the Live Data demo from the PRTG API documentation, but there are some content types that the cmdlet does not yet support, such as "sensortree".
			Valid content types are "devices", "groups", "sensors", "todos", "messages", "values", "channels", and "history". Note that all content types are not valid for all object types; for example, a device object can contain no groups or channels.
			
		.PARAMETER Content
			The type of data for the specified object. Valid values are "devices", "groups", "sensors", "todos", "messages", "values", "channels", and "history". Note that all content types are not valid for all object types; for example, a device object can contain no groups or channels.
			
		.PARAMETER ObjectId
			An object ID from PRTG. Objects include probes, groups, devices, and sensors, as well as reports, maps, and todos.
		
		.PARAMETER Columns
			A string array of named column values to return. In general the default return values for a given content type will return all of the available columns; this parameter can be used to change the order of columns or specify which columns to include or ignore.
			
		.PARAMETER FilterTags
			A string array of sensor tags. This parameter only has any effect if the content type is "sensors". Output will only include sensors with the specified tags. Note that specifying multiple tags performs a logical OR of tags.
			
		.PARAMETER Count
			Number of records to return. PRTG's internal default for this is 500. Valid values are 1-50000.
			
		.PARAMETER Raw
			If this switch is set, the cmdlet will return the raw XML data rather than a PowerShell object.
		
		.EXAMPLE
			Get-PrtgTableData groups 1
			
			Returns the groups under the object ID 1, which is typically the Core Server's Local Probe.
		
		.EXAMPLE
			Get-PrtgTableData sensors -FilterTags corestatesensor,probesensor
			
			Returns a filtered list of sensors tagged with "corestatesensor" or "probesensor".
			
		.EXAMPLE
			Get-PrtgTableData messages 1002
			
			Returns the messages log for device 1002.
			
		.EXAMPLE
			Get-PrtgTableData channels -SensorId 2591
			
			Returns the channel data for object (sensor) 2591.			
	#>

	[CmdletBinding()]
	Param (		
		[Parameter(Mandatory=$True,
				   Position=0,
				   HelpMessage='The type of data for the specified object.')]
		[ValidateSet("devices","groups","sensors","todos","messages","values","channels","history")]
		[string]$Content,
		
		# ID of the object to query
		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({$_ -gt 0})]
		[Alias('DeviceId','SensorId')]
		[int]$ObjectId,
		
		[Parameter(Mandatory=$False)]
		[string[]]$Columns,
		
		[Parameter(Mandatory=$False)]
		[string[]]$FilterTags,

		[Parameter(Mandatory=$False)]
		[int]$Count = 500,
		
		[Parameter(Mandatory=$False)]
		[switch]$Raw
	)
	
	<# things to add
	
		filter_drel (content = messages only) today, yesterday, 7days, 30days, 12months, 6months - filters messages by timespan
		filter_status (content = sensors only) Unknown=1, Collecting=2, Up=3, Warning=4, Down=5, NoProbe=6, PausedbyUser=7, PausedbyDependency=8, PausedbySchedule=9, Unusual=10, PausedbyLicense=11, PausedUntil=12, DownAcknowledged=13, DownPartial=14 - filters messages by status
		sortby = sorts on named column, ascending (or decending with a leading "-")
		filter_xyz - fulltext filtering. this is a feature in its own right
	
	#>

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		
		if ($Count) {
			$CountString = "&count=$Count"
		}
		
		
		if ($Content -eq "sensors" -and $FilterTags) {
			$FilterString = ""
			
			foreach ($tag in $FilterTags) {
				$FilterString += "&filter_tags=" + $tag
			}
		}
		
		if (!$Columns) {
		
			# this was pulled mostly from the API doc, with some minor adjustments
			# this function currently doesn't work with "sensortree" or any of the nonspecific values: "reports","maps","storedreports"
			
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
		
		$HTMLColumns = @("downsens","partialdownsens","downacksens","upsens","warnsens","pausedsens","unusualsens","undefinedsens","message","favorite")
	}

	PROCESS {
	
		$url = HelperURLBuilder "table.xml" (
			"&content=$Content",
			"&columns=$SelectedColumnsString",
			"&id=$ObjectId",
			$FilterString,
			$CountString
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
					# fix a bizarre formatting bug
					$ThisRow.$Prop = HelperFormatHandler $item.$Prop
				} elseif ($HTMLColumns -contains $Prop) {
					# strip HTML, leave bare text
					$ThisRow.$Prop =  $item.$Prop -replace "<[^>]*?>|<[^>]*>", ""
				} else {
					$ThisRow.$Prop = $item.$Prop
				}
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
			
			Write-Warning "No $Content; Object $ObjectId is type $DeterminedObjectType"
			Write-Warning (" Valid query types: " + ($ValidQueriesTable.$DeterminedObjectType -join ", "))
		} else {
			$ReturnData
		}
	}
}

###############################################################################

function Move-PrtgObject {
<#
	.SYNOPSIS
		Moves an object in PRTG tree
	.DESCRIPTION
		if you want positional changes, you give the string nouns ("up","down","top","bottom")
		if you want group changes, you give an integer for the target objectid
		
	.EXAMPLE
		
	#>

	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium', DefaultParameterSetName='SetPosition')]
	Param (
			[Parameter(Mandatory=$True,Position=0,ParameterSetName='SetPosition')]
			[Parameter(Mandatory=$True,Position=0,ParameterSetName='MoveObject')]
			[alias('SensorId')]
			[int]$ObjectId,

			[Parameter(Mandatory=$True,Position=1,ParameterSetName='SetPosition')]
			[ValidateSet("up","down","top","bottom")] 
			[string]$Position,

			[Parameter(Mandatory=$True,Position=1,ParameterSetName='MoveObject')]
			[string]$TargetId
	)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
	}

	PROCESS {
		
	 If ($pscmdlet.ShouldProcess("$ObjectId", "Move object to new location")) {
		Switch ($PSCmdlet.ParameterSetName) {
			
			'SetPosition' {
				Write-Debug "case SetPosition from $PSCmdlet.ParameterSetName"
				Try {
					$url = HelperURLBuilder "setposition.htm" (
						"&id=$ObjectId",
						"&newpos=$Position"
					)
					$global:lasturl = $url
					$QueryObject = HelperHTTPQuery $url
				}
				Catch { Throw "$($Error[0])" }
				Break
			}
			
			'MoveObject' {
				Write-Debug "case MoveObject from $PSCmdlet.ParameterSetName"
				Try {
					$url = HelperURLBuilder "moveobject.htm" (
						"&id=$ObjectId",
						"&targetid=$TargetId"
					)

					$global:lasturl = $url
					$QueryObject = HelperHTTPQuery $url	-UriOnly
					
					$NewIdRx = [regex] '(?<=id%3D)\d+'
					$NewIDRx.Match($QueryObject.ResponseUri).value
				}
				Catch { Throw "$($Error[0])" }
				Break
			}
		default	{Throw ArgumentException('Bad ParameterSet Name') }
		}
	 }	
	}
}

function Copy-PrtgObject {
	<#
	.SYNOPSIS
	Copy source object to target	
	.DESCRIPTION
	Copy source object to destination object, with new name.
	
	.EXAMPLE
	$BackupDeviceId = Find-PrtgDevice srv-veeam-w02
	Copy-PrtgObject -ObjectId 6535 -Name 'New backup job' -TargetId $BackupDevice.objid
	#>
	
		[CmdletBinding()]
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
    }

	PROCESS {
		$url = HelperURLBuilder "duplicateobject.htm" (
			"&id=$ObjectId",
			"&name=$Name",
			"&targetid=$TargetId"
		)

		$global:lasturl = $url
		$CopyObject = HelperHTTPQuery $url -UriOnly
				
		$NewIdRx = [regex] '(?<=id%3D)\d+'

		Write-Debug $CopyObject.ResponseUri
		
		$NewIDRx.Match($CopyObject.ResponseUri).value
	}
}

function Remove-PrtgObject {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='High')]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		$ObjectId
		#TODO: document this; $ObjectID for this cmdlet can either be a single integer or a comma-separated string of integers to handle multiples
	)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
	}

	PROCESS {
		
		If (-not (Get-PrtgObjectStatus -ObjectID $ObjectID).objid ) {
			Write-Error "Object $ObjectID does not exist"
			Exit
		}
		
		If ($pscmdlet.ShouldProcess("ObjectID $ObjectId", "Remove object from PRTG")) {
			$url = HelperURLBuilder "deleteobject.htm" (
				"&id=$ObjectId",
				"&approve=1"
			)
			$global:lasturl = $url
			$RemoveObject = HelperHTTPQuery $url
		}
	}
}

Set-Alias Copy-PrtgSensor Copy-PrtgObject
Set-Alias Rename-PrtgSensor Rename-PrtgObject
Set-Alias Move-PrtgSensor Move-PrtgObject

###############################################################################

function Resume-PrtgObject {
	<#
	.SYNOPSIS
		Resume-PrtgObject
		
	.DESCRIPTION
		
		See also Suspend-PrtgObject
		
		
	.EXAMPLE
		
	#>
		[CmdletBinding()]
    Param (
			# ID of the object to pause/resume
			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			[ValidateScript({$_ -gt 0})]
			[alias('SensorId')]
			[int]$ObjectId
    )

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		# $WebClient = New-Object System.Net.WebClient
	}

	PROCESS {
		$url = HelperURLBuilder "pause.htm" (
			"&id=$ObjectId",
			"&action=1"
		)

		$global:lasturl = $url
		$ResumeObject = HelperHTTPQuery $url
		
		# $global:Response = $WebClient.DownloadString($url)

		###########################################
		# this needs a handler; the output is silly
        # return $global:Response
	}
}

function Suspend-PrtgObject {
	<#
	
	.SYNOPSIS
		Suspend-PrtgObject
		
	.DESCRIPTION
		
		See also Resume-PrtgObject
		
	.EXAMPLE
		
	#>
	
	[CmdletBinding()]
	Param (
			# ID of the object to pause/resume
			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			[ValidateScript({$_ -gt 0})]
			[alias('SensorId')]
			[int]$ObjectId,
				
			# Length of time in minutes to pause the object, $null for indefinite
			[Parameter()]
			[int]$PauseLength=$null,
			
			# Message to associate with the pause event
			[Parameter()]
			[string]$PauseMessage="Paused by PowerShell API"
	)

	BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
		# $WebClient = New-Object System.Net.WebClient
	}

	PROCESS {
		
		if ($PauseLength) {
			$url = HelperURLBuilder "pauseobjectfor.htm" (
				"&id=$ObjectId",
				"&pausemsg=$PauseMessage",
				"$duration=$PauseLength",
				"&action=0"
			)
    }
		else {
			$url = HelperURLBuilder "pause.htm" (
				"&id=$ObjectId",
				"&pausemsg=$PauseMessage",
				"&action=0"
			)
    }
		
		$global:lasturl = $url
		$ResumeObject = HelperHTTPQuery $url
		
		# $global:Response = $WebClient.DownloadString($url)

		###########################################
		# this needs a handler; the output is silly
    # return $global:Response
	}
}

Set-Alias Pause-PrtgObject Suspend-PrtgObject
Set-Alias Pause-PrtgSensor Suspend-PrtgObject

###############################################################################
# This is definitely incomplete but works in extremely limited use cases
# todo:
#   adjust "avg" value, which sets the interval of data returned

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
		
		[Parameter(Mandatory=$false,Position=2)]
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
		
		$ValidData = $Data.histdata.item | ? { $_.coverage_raw -ne '0000000000' }

		$DataPoints = @()

		foreach ($v in $ValidData) {
			$Channels = @()
			foreach ($val in $v.value) {
				$NewChannel          = "" | Select Channel,Value
				$NewChannel.Channel  = $val.channel
				$NewChannel.Value    = $val.'#text'
				$Channels           += $NewChannel
			}

			$ChannelsRaw = @()
			foreach ($vr in $v.value_raw) {
				$NewChannel          = "" | Select Channel,Value
				$NewChannel.Channel  = $vr.channel
				$NewChannel.Value    = [double]$vr.'#text'
				$ChannelsRaw        += $NewChannel
			}

			$New             = "" | Select DateTime,Channels,ChannelsRaw
			$New.Datetime    = [DateTime]::Parse(($v.datetime.split("-"))[0]) # need to do a datetime conversion here
			$New.Channels    = $Channels
			$New.ChannelsRaw = $ChannelsRaw

			$DataPoints += $New
		}

	}
	
	END {
		return $DataPoints
    }
}


function Measure-PRTGStorage {

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$HistorySensorObjectId,

        [Parameter(Mandatory=$False,Position=1)]
        [int]$HistoryInDays = 30
    )
	
	$ObjectDetails = Get-PrtgObjectDetails $HistorySensorObjectId
	
	if ($ObjectDetails.sensortype -ne "exexml") {
		return " Selected sensor object (" + $HistorySensorObjectId + ": " + $ObjectDetails.name + ") is not the proper type."
	}

	$HistorySensorData = Get-PrtgSensorHistoricData $HistorySensorObjectId $HistoryInDays

	$OldestDataPointDate = $HistorySensorData[0].DateTime
	$OldestDataPointSize = ($HistorySensorData[0].ChannelsRaw | ? { $_.Channel -match "History Size$" }).Value

	$NewestDataPointDate = $HistorySensorData[$HistorySensorData.Count-1].DateTime
	$NewestDataPointSize = ($HistorySensorData[$HistorySensorData.Count-1].ChannelsRaw | ? { $_.Channel -match "History Size$" }).Value

	$HistorySizeGain = $NewestDataPointSize - $OldestDataPointSize
	$MeasuredPeriod = $NewestDataPointDate - $OldestDataPointDate

	$DailyGrowthRate = $HistorySizeGain / $MeasuredPeriod.TotalDays
	$RemainingDiskFree = ($HistorySensorData[$HistorySensorData.Count-1].ChannelsRaw | ? { $_.Channel -match "Disk Free$" }).Value
	$MonitorableDaysAtCurrentGrowthRate = $RemainingDiskFree / $DailyGrowthRate

	if ($MonitorableDaysAtCurrentGrowthRate) {
		Write-Host " PRTG has" ("{0:N}" -f $RemainingDiskFree) "GB remaining disk available and" ("{0:N}" -f $NewestDataPointSize) "GB of monitoring data stored."
		Write-Host " The history size monitor reports an average daily growth rate of" ("{0:N}" -f $DailyGrowthRate) "GB over a period of" ("{0:N}" -f $MeasuredPeriod.TotalDays) "days."
		Write-Host " There is enough space available to store monitoring data for" ("{0:N}" -f $MonitorableDaysAtCurrentGrowthRate) "days."
	} else {
		Write-Host " Sensor does not appear to be a history database size monitor sensor."
	}
}

###############################################################################
# custom exe/xml functions

function Set-PrtgResult {
    Param (
    [Parameter(Mandatory=$True,Position=0)]
    [string]$Channel,
    
    [Parameter(mandatory=$True,Position=1)]
    $Value,
    
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
    [ValidateSet("One","Kilo","Mega","Giga","Tera","Byte","KiloByte","MegaByte","GigaByte","TeraByte","Bit","KiloBit","MegaBit","GigaBit","TeraBit")]
    [string]$VolumeSize,
    
    [Parameter(mandatory=$False)]
    [alias('dm')]
    [ValidateSet("Auto","All")]
    [string]$DecimalMode,
    
    [Parameter(mandatory=$False)]
    [alias('w')]
    [switch]$Warning,
    
    [Parameter(mandatory=$False)]
    [string]$ValueLookup
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
    
	if (!($Value -is [int])) { $Result += "    <float>1</float>`n" }
    if ($Mode)        { $Result += "    <mode>$Mode</mode>`n" }
    if ($MaxWarn)     { $Result += "    <limitmaxwarning>$MaxWarn</limitmaxwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitminwarning>$MinWarn</limitminwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitmaxerror>$MaxError</limitmaxerror>`n"; $LimitMode = $true }
    if ($WarnMsg)     { $Result += "    <limitwarningmsg>$WarnMsg</limitwarningmsg>`n"; $LimitMode = $true }
    if ($ErrorMsg)    { $Result += "    <limiterrormsg>$ErrorMsg</limiterrormsg>`n"; $LimitMode = $true }
    if ($LimitMode)   { $Result += "    <limitmode>1</limitmode>`n" }
    if ($SpeedSize)   { $Result += "    <speedsize>$SpeedSize</speedsize>`n" }
    if ($VolumeSize)  { $Result += "    <volumesize>$VolumeSize</volumesize>`n" }
    if ($DecimalMode) { $Result += "    <decimalmode>$DecimalMode</decimalmode>`n" }
    if ($Warning)     { $Result += "    <warning>1</warning>`n" }
    if ($ValueLookup) { $Result += "    <ValueLookup>$ValueLookup</ValueLookup>`n" }
    
    if (!($ShowChart)) { $Result += "    <showchart>0</showchart>`n" }
    
    $Result += "  </result>`n"
    
    return $Result
}



function Set-PrtgError {
	Param (
		[Parameter(Position=0)]
		[string]$PrtgErrorText
	)
	
	@"
<prtg>
  <error>1</error>
  <text>$PrtgErrorText</text>
</prtg>
"@

exit
}

function New-PrtgSnmpTrafficSensor {
    Param (
        [Parameter(Mandatory=$True)]
        [string]$Name,

        [Parameter(Mandatory=$True)]
        [int]$InterfaceNumber,

        [Parameter(Mandatory=$True)]
        [int]$ParentId,

        [Parameter(Mandatory=$False)]
        [string]$Tags,

        [Parameter(Mandatory=$False)]
        [ValidateRange(1,5)] 
        [int]$Priority = 3,

        [Parameter(Mandatory=$False)]
        [int]$Interval = 60,

        [Parameter(Mandatory=$False)]
        [ValidateSet("Independent","Stacked","PosNeg")]
        [String]$ChartType = "Independent",

        [Parameter(Mandatory=$False)]
        [switch]$ErrorOnDown = $True,

        [Parameter(Mandatory=$False)]
        [switch]$ShowErrors,

        [Parameter(Mandatory=$False)]
        [switch]$ShowDiscards,

        [Parameter(Mandatory=$False)]
        [switch]$ShowUnicast,

        [Parameter(Mandatory=$False)]
        [switch]$ShowNonUnicast,

        [Parameter(Mandatory=$False)]
        [switch]$ShowMulticast,

        [Parameter(Mandatory=$False)]
        [switch]$ShowBroadcast,

        [Parameter(Mandatory=$False)]
        [switch]$ShowUnknown
    )

    BEGIN {
        Add-Type -AssemblyName System.Web # Needed for System.Web.HttpUtility
        $PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {

    
        ###############################################################################
        # build the post data payload/query string
        # note that "$QueryString.ToString()" actually builds this

        $QueryStringTable = @{
	        "name_"                  = $Name
	        "tags_"                  = "prtgshell snmptrafficsensor bandwidthsensor $Tags"
	        "priority_"              = $Priority
            "interfacenumber_"       = 1
            "interfacenumber__check" = "$InterfaceNumber`:$Name|$Name|Connected|1 GBit/s|Ethernet|1|$Name|1000000000|3|2|" # don't know what the 3|2 are, or if the other bits matter
            "namein_"                = "Traffic In"
            "nameout_"               = "Traffic Out"
            "namesum_"               = "Traffic Total"
            "stack_"                 = 0
	        "intervalgroup"          = 1
	        "interval_"              = "$Interval|$Interval seconds"
	        "inherittriggers"        = 1
	        "id"                     = $ParentId
	        "sensortype"             = "snmptraffic"
        }

        # create a blank, writable HttpValueCollection object
        $QueryString = [System.Web.httputility]::ParseQueryString("")

        # iterate through the hashtable and add the values to the HttpValueCollection
        foreach ($Pair in $QueryStringTable.GetEnumerator()) {
	        $QueryString[$($Pair.Name)] = $($Pair.Value)
        }

        ###############################################################################
        # Add TrafficMode

        $TrafficMode = @()
        if ($ShowErrors)     { $TrafficMode += "errors"     }
        if ($ShowDiscards)   { $TrafficMode += "discards"   }
        if ($ShowUnicast)    { $TrafficMode += "unicast"    }
        if ($ShowNonUnicast) { $TrafficMode += "nonunicast" }
        if ($ShowMulticast)  { $TrafficMode += "multicast"  }
        if ($ShowBroadcast)  { $TrafficMode += "broadcast"  }
        if ($ShowUnknown)    { $TrafficMode += "unknown"    }

        foreach ($t in $TrafficMode) {
            $QueryString.Add("trafficmode_",$t)
        }

        ###############################################################################
        # fire the api call

        $Url  = "https://$($PRTG.Server)"
        $Url += "/addsensor5.htm?"
        $Url += "username=$($PRTG.UserName)&"
        $Url += "passhash=$($PRTG.PassHash)"
   
        HelperHTTPPostCommand $Url $QueryString.ToString() | Out-Null
    }
}

function Get-PrtgSensorChannels {
	<#
		.SYNOPSIS
			Show parent probe of device
		.DESCRIPTION
		
		.EXAMPLE
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[int]$SensorId
	)

	Get-PrtgTableData channels $SensorId
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
	
	Get-PrtgTableData sensors $DeviceId
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

    Get-PrtgTableData sensors -FilterTags $FilterTags
}

###############################################################################

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
# these have also not been extensively tested



function Get-PrtgSensorTree {
    Param (
        [Parameter(Mandatory=$False,Position=0)]
        [int]$ObjectId,
		
        [Parameter(Mandatory=$False,Position=1)]
        [string]$Value
    )

    BEGIN {
		$PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
		$url = HelperURLBuilder "table.xml" (
			"&content=sensortree"
		)

        $global:lasturl = $url
        
		$QueryObject = HelperHTTPQuery $url -AsXML
		
		return $QueryObject
    }
}


function Get-PRTGProbes {
	$data = Get-PrtgSensorTree
	foreach ($node in $data.data.prtg.sensortree.nodes.group.probenode) {
		$node | Select-Object @{n='objid';e={ $_.id[0] }},name
	}
}


function Get-PrtgGroups{
    
		Get-PrtgTableData -content "groups" 
		
    # -columns "objid,probe,group,name,downsens,partialdownsens,downacksens,upsens,warnsens,pausedsens,unusualsens"
}
function Remove-PrtgSensorNumbers {

	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[int]$ObjectId
	)
	
	Begin { }

	Process {
		$ObjectType = (Get-PrtgObjectDetails $ObjectId).sensortype
		
		if ($ObjectType -eq "device") {

			$ObjectSensors = Get-PrtgTableData sensors $ObjectId | select objid,sensor
			$regex = [regex]"\s\d+$"

			foreach ($Sensor in $ObjectSensors) {
				If ($pscmdlet.ShouldProcess("SensorID $Sensor", "Remove numbers from end of sensor name")) {
					$SensorName = $Sensor.sensor -replace $regex
					
					$ReturnName = $Sensor.sensor + " -> " + $SensorName
					$ReturnValue = $(Set-PrtgObjectProperty -ObjectId $Sensor.objid -Property name -Value $SensorName) -replace "<[^>]*?>|<[^>]*>", ""
					
					"" | Select @{n='Name Change';e={$ReturnName}},@{n='Return Code';e={$ReturnValue}}
				}
			}
		} else {
			Write-Error "Object must be a device; provided object is type $ObjectType."
		}
	}
	End {}
}


function Invoke-PrtgObjectScan {
	<#
		.SYNOPSIS
			Scan a sensor now     
		.DESCRIPTION
						
		.EXAMPLE
					
	#>

		[CmdletBinding()]
    Param (
				# ID of the object to scan
				[Parameter(Mandatory=$true)]
				[ValidateNotNullOrEmpty()]
				[ValidateScript({$_ -gt 0})]
				[alias('SensorId')]
				[int]$ObjectId
    )

    BEGIN {
			$PRTG = $Global:PrtgServerObject
			if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
			$url = HelperURLBuilder "scannow.htm" (
							"&id=$ObjectId"
			)

			$global:lasturl = $url
			$QueryObject = HelperHTTPQuery $url

			return $QueryObject.Data -replace "<[^>]*?>|<[^>]*>", ""
    }
}

function Invoke-PrtgObjectDiscovery {
	<#
	.SYNOPSIS

		Run Auto Discovery for an object     
	.DESCRIPTION
					
	.EXAMPLE
					
	#>

	[CmdletBinding()]
	Param (
			# ID of the object to scan
			[Parameter(Mandatory=$true)]
			[ValidateNotNullOrEmpty()]
			[ValidateScript({$_ -gt 0})]
			[Alias('DeviceId')]
			[int]$ObjectId
	)

    BEGIN {
			$PRTG = $Global:PrtgServerObject
			if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {
			$url = HelperURLBuilder "discovernow.htm" (
							"&id=$ObjectId"
		)

			$global:lasturl = $url
			$QueryObject = HelperHTTPQuery $url

			return $QueryObject.Data -replace "<[^>]*?>|<[^>]*>", ""
    }
}

function New-PrtgSensor {
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [psobject]$PrtgObject
    )

    BEGIN {
			Add-Type -AssemblyName System.Web # Needed for System.Web.HttpUtility
			$PRTG = $Global:PrtgServerObject
			if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {

    ###############################################################################
    # Tediously inspect the Object, needs more c#, maybe?

    $PropertyTypes = @{Name            = "String"
                       Tags            = "String"
                       Priority        = "Int32"
                       Script          = "String"
                       ExeParams       = "String"
                       Environment     = "Int32"
                       SecurityContext = "Int32"
                       Mutex           = "String"
                       ExeResult       = "Int32"
                       ParentId        = "Int32"}

    foreach ($p in $PropertyTypes.GetEnumerator()) {
        $PropName  = $p.Name
        $PropValue = $PrtgObject."$PropName"
        $Type      = $PrtgObject."$PropName".GetType().Name
        
        if ($Type -eq $p.Value) {
            switch ($PropName) {
                priority {
                    if (($PropValue -lt 1) -or ($PropValue -gt 5)) {
                        $ErrorMessage = "Error creating Sensor $($Prtgobject.Name). $PropName is $PropValue, must be a integer from 1 to 5."
                    }
                }
                { ($_ -eq "environment") -or ($_ -eq "securitycontext") } {
                    if (($PropValue -lt 0) -or ($PropValue -gt 1)) {
                        $ErrorMessage = "Error creating Sensor $($Prtgobject.Name). $PropName is $PropValue, must be a integer from 0 to 1."
                    }
                }
                exeresult {
                    if (($PropValue -lt 0) -or ($PropValue -gt 2)) {
                        $ErrorMessage = "Error creating Sensor $($Prtgobject.Name). $PropName is $PropValue, must be a integer from 0 to 1."
                    }
                }
            }
        } else {
            $ErrorMessage = "Error creating Sensor $($Prtgobject.Name), $($p.Name) is $Type, should be $($p.Value)"
        }
        if ($ErrorMessage) { return $ErrorMessage }
    }

    ###############################################################################
    # build the post data payload/query string
    # note that "$QueryString.ToString()" actually builds this
    
    $QueryStringTable = @{
	    "name_" = $PrtgObject.Name
	    "tags_" = $PrtgObject.Tags
	    "priority_" = $PrtgObject.Priority
	    "exefile_" = "$($PrtgObject.Script)|$$(PrtgObject.Script)||" # WHAT THE FUCK
	    "exefilelabel" = ""
	    "exeparams_" = $PrtgObject.ExeParams
	    "environment_" = $PrtgObject.Environment
	    "usewindowsauthentication_" = $PrtgObject.SecurityContext
	    "mutexname_" = $PrtgObject.Mutex
	    "timeout_" = 60
	    "writeresult_" = $PrtgObject.ExeResult
	    "intervalgroup" = 1
	    "interval_" = "60|60 seconds"
	    "inherittriggers" = 1
	    "id" = $PrtgObject.ParentId
	    "sensortype" = "exexml"
    }

    # create a blank, writable HttpValueCollection object
    $QueryString = [System.Web.httputility]::ParseQueryString("")

    # iterate through the hashtable and add the values to the HttpValueCollection
    foreach ($Pair in $QueryStringTable.GetEnumerator()) {
	    $QueryString[$($Pair.Name)] = $($Pair.Value)
    }

    ###############################################################################
    # fire the api call

    $Url  = "https://$($PRTG.Server)"
    $Url += "/addsensor5.htm?"
    $Url += "username=$($PRTG.UserName)&"
    $Url += "passhash=$($PRTG.PassHash)"
    #$Url

    HelperHTTPPostCommand $Url $QueryString.ToString() | Out-Null

    }
}

###############################################################################

function New-PrtgSnmpCpuLoadSensor {
    Param (
        [Parameter(Mandatory=$True)]
        [string]$Name,

        [Parameter(Mandatory=$True)]
        [int]$ParentId,

        [Parameter(Mandatory=$False)]
        [string]$Tags,

        [Parameter(Mandatory=$False)]
        [ValidateRange(1,5)] 
        [int]$Priority = 3,

        [Parameter(Mandatory=$False)]
        [int]$Interval = 60
    )

    BEGIN {
        Add-Type -AssemblyName System.Web # Needed for System.Web.HttpUtility
        $PRTG = $Global:PrtgServerObject
		if ($PRTG.Protocol -eq "https") { HelperSSLConfig }
    }

    PROCESS {

    
        ###############################################################################
        # build the post data payload/query string
        # note that "$QueryString.ToString()" actually builds this

        if ($Tags) { $Tags = "$Tags snmp cpu cpuloadsensor" } `
              else { $Tags = "snmp cpu cpuloadsensor"       }

        $QueryStringTable = @{
	        "name_"                  = $Name
	        "tags_"                  = $Tags
	        "priority_"              = $Priority
	        "intervalgroup"          = 1
	        "interval_"              = "$Interval|$Interval seconds"
	        "inherittriggers"        = 1
	        "id"                     = $ParentId
	        "sensortype"             = "snmpcpu"
        }

        # create a blank, writable HttpValueCollection object
        $QueryString = [System.Web.httputility]::ParseQueryString("")

        # iterate through the hashtable and add the values to the HttpValueCollection
        foreach ($Pair in $QueryStringTable.GetEnumerator()) {
	        $QueryString[$($Pair.Name)] = $($Pair.Value)
        }

        ###############################################################################
        # fire the api call

        $Url  = "https://$($PRTG.Server)"
        $Url += "/addsensor5.htm?"
        $Url += "username=$($PRTG.UserName)&"
        $Url += "passhash=$($PRTG.PassHash)"
   
        HelperHTTPPostCommand $Url $QueryString.ToString() | Out-Null
    }
}



#region helperfunctions
###############################################################################
## Helper Functions
###############################################################################
# http://stackoverflow.com/questions/6032344/how-to-hide-helper-functions-in-powershell-modules
# make sure none of these have a dash in their name

function HelperSSLConfig {
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
	[System.Net.ServicePointManager]::Expect100Continue = {$true}
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
}

function HelperHTTPQuery {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[string]$URL,
		
		[Parameter(Mandatory=$False)]
		[alias('xml')]
		[switch]$AsXML,
		
		[Parameter(Mandatory=$False)]
		[alias('ReponseUri')]
		[switch]$UriOnly
	)
	
	try {
		$Response = $null
		Write-Debug "HelperHTTPQuery: Create: $($URL)"
		$Request = [System.Net.HttpWebRequest]::Create($URL)
		Write-Debug "HelperHTTPQuery: Request: $($Request)"
		$Response = $Request.GetResponse()
		Write-Debug "HelperHTTPQuery: Response: $($Response)"
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
		#Only want the URI string	
		If ($UriOnly) {
			$ResponseUri = $Response.ResponseUri.PathAndQuery
			
			Write-Debug "HelperHTTPQuery: ResponseUri: $($ResponseUri)"
			$Global:LastResponse = $ResponseUri

		#Return the data
		} Else {
			$Stream    = $Response.GetResponseStream()
			$Reader    = New-Object IO.StreamReader($Stream)
			$FullPage  = $Reader.ReadToEnd()
			
			if ($AsXML) {
				$Data = [xml]$FullPage
			} else {
				$Data = $FullPage
			}
			
			Write-Debug "HelperHTTPQuery: Data: $($Data)"
			$Global:LastResponse = $Data
			
			$Reader.Close()
			$Stream.Close()
		}
	} else {
		Throw "Error Accessing Page $($URL)"
	}
	$Response.Close()
	
	#Define response object properties
	$ReturnObject = [pscustomobject][ordered]@{
		'StatusCode' = if ($StatusCode) { $StatusCode } Else { "" -as [int] }
		'DetailedError' = if ($DetailedError) { $DetailedError } Else { "" -as [String] }
		'ResponseUri' = if ($ResponseUri) { $ResponseUri } Else { "" -as [String] }
		'Data' = if ($Data) { $Data } Else { "" -as [String] }
	}
	
	$ReturnObject
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
	
	$URL =
		$Protocol, "://", $Server, $PortString,
		"/api/",$Action,"?",
		"username=$UserName",
		"&passhash=$PassHash" -join ""
	
	$URL += $QueryParameters -join ""
	
	return $URL
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

function HelperHTTPPostCommand() {
	[CmdletBinding()]
	param(
		[string] $url = $null,
		[string] $data = $null,
		[System.Net.NetworkCredential]$credentials = $null,
		[string] $contentType = "application/x-www-form-urlencoded",
		[string] $codePageName = "UTF-8",
		[string] $userAgent = $null
	);

	if ( $url -and $data ) {
		[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create($url);
		$webRequest.ServicePoint.Expect100Continue = $false;
		if ( $credentials ) {
			$webRequest.Credentials = $credentials;
			$webRequest.PreAuthenticate = $true;
		}
		$webRequest.ContentType = $contentType;
		$webRequest.Method = "POST";
		if ( $userAgent ) {
			$webRequest.UserAgent = $userAgent;
		}

		$enc = [System.Text.Encoding]::GetEncoding($codePageName);
		[byte[]]$bytes = $enc.GetBytes($data);
		$webRequest.ContentLength = $bytes.Length;
		[System.IO.Stream]$reqStream = $webRequest.GetRequestStream();
		$reqStream.Write($bytes, 0, $bytes.Length);
		$reqStream.Flush();

		$resp = $webRequest.GetResponse();
		$rs = $resp.GetResponseStream();
		[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs;
		$sr.ReadToEnd();
	}
}

#endregion

###############################################################################
## PowerShell Module Functions
###############################################################################

Export-ModuleMember -function *-* -alias *-*
