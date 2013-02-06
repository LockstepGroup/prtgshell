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
        [string]$PassHash
    )

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient

        $PrtgServer = @{}
        $PrtgServerProps = @("Server","UserName","PassHash")
        foreach ($Value in $PrtgServerProps) {
            $PrtgServer.Add($Value,$null)
        }
    }

    PROCESS {
        $url  = "https://$Server/api/getstatus.xml?"
        $url += "username=$UserName"
        $url += "&passhash=$PassHash"
        $global:lasturl = $url

        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            $Stream  = $Res.GetResponseStream()
            $Reader  = New-Object io.streamreader($stream)
            $webpage = $reader.readtoend()
            $Data    = [xml]$webpage
            $Reader.Close()
            $Stream.Close()
            $Res.Close()
        } else {
            Throw "Error Accessing Page $WebPage"
        }
        
        $CurrentServer = New-Object psobject -Property $PrtgServer
        
        $CurrentServer.Server   = $Server
        $CurrentServer.UserName = $UserName
        $CurrentServer.PassHash = $PassHash

        $global:PrtgServerObject = $CurrentServer
            
        return $Data
        #>
    }
}

function Move-PrtgSensor {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$SensorId,

        [Parameter(Mandatory=$True,Position=1)]
        [ValidateSet("up","down","top","bottom")] 
        [string]$Position
    )

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient
        Add-Type -AssemblyName System.Management.Automation
    }

    PROCESS {
        $Server = $Global:PrtgServerObject.Address
        $User = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "setposition.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$SensorId"
        $url += "&newpos=$Position"

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}

function Rename-PrtgSensor {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$SensorId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$NewName
    )

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient
        Add-Type -AssemblyName System.Management.Automation
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "setobjectproperty.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$SensorId"
        $url += "&name=name"
        $url += "&value=$NewName"        

        $global:lasturl = $url
        
        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            $Stream   = $Res.GetResponseStream()
            $Reader   = New-Object io.streamreader($stream)
            $webpage  = $reader.readtoend()
            $Response = $webpage
            $Reader.Close()
            $Stream.Close()
            $Res.Close()
        } else {
            Throw "Error Accessing Page $WebPage"
        }

        return
    }
}

function Copy-PrtgSensor {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$SensorId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Name,
        
        [Parameter(Mandatory=$True,Position=2)]
        [string]$TargetId
    )

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "duplicateobject.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$SensorId"
        $url += "&name=$Name"
        $url += "&targetid=$TargetId"
        $global:lasturl = $url
        
        $NewIdRx = [regex] '(?<=id%3D)\d+'
        
        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            return $NewIDRx.Match($Res.ResponseUri.PathAndQuery).value
        } else {
            Throw "Error Accessing Page $WebPage"
        }
    }
}

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
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "table.xml?content=sensors"
        $url += "&username=$User"
        $url += "&passhash=$PassHash"
        $url += "&columns=objid,probe,group,device,sensor,status,message,lastvalue,priority,favorite,comments"
        $url += "&id=$DeviceId"
        $Global:LastUrl = $Url
        
        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            $Stream   = $Res.GetResponseStream()
            $Reader   = New-Object io.streamreader($stream)
            $webpage  = $reader.readtoend()
            $Response = [xml]$webpage
            $Global:LastResponse = $Response
            $Reader.Close()
            $Stream.Close()
            $Res.Close()
        } else {
            Throw "Error Accessing Page $WebPage"
        }
        
        $Columns = @("objid","probe","group","device","sensor","status","status_raw","message","message_raw","lastvalue","lastvalue_raw","priority","favorite","favorite_raw","comments")

        $SensorHash = @{}
        $SensorProps = @("objid","probe","group","device","sensor","status","status_raw","message","message_raw","lastvalue","lastvalue_raw","priority","favorite","favorite_raw","comments")
        foreach ($Value in $SensorProps) {
            $SensorHash.Add($Value,$null)
        }

        $Sensors = @()
        foreach ($item in $Response.sensors.item) {
            $Sensor = New-Object psobject -Property $SensorHash
            foreach ($Prop in $SensorProps) {
                $Sensor.$Prop = $item.$Prop
            }
            $Sensors += $Sensor
        }

        return $Sensors
    }
}

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
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "pause.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$ObjectId"
        $url += "&action=1"

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}

function Set-PrtgObjectProperty {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$SensorId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Property,

        [Parameter(Mandatory=$True,Position=2)]
        [string]$Value
    )

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "setobjectproperty.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$SensorId"
        $url += "&name=$Property"
        $url += "&value=$Value"

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}

function Get-PrtgObjectProp {
	<#
	.SYNOPSIS
		
	.DESCRIPTION
		
	.EXAMPLE
		
	#>

    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [int]$DeviceId,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Property
    )

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "getobjectproperty.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$DeviceId"
        $url += "&name=$Property"
        $url += "&show=text"
        $global:lasturl = $url
        
        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            $Stream   = $Res.GetResponseStream()
            $Reader   = New-Object io.streamreader($stream)
            $webpage  = $reader.readtoend()
            $Response = [xml]$webpage
            $Reader.Close()
            $Stream.Close()
            $Res.Close()
        } else {
            Throw "Error Accessing Page $WebPage"
        }

        return $Response.prtg.result
    }
}

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

    BEGIN {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "table.xml?"
        $url += "content=devices"
        $url += "&username=$User"
        $url += "&passhash=$PassHash"
        $url += "&output=xml"
        $url += "&columns=objid,probe"
        $global:lasturl = $url
        
        $Req = [system.net.httpwebrequest]::create($url)
        $Res = $Req.GetResponse()
        if ($Res.StatusCode -eq "OK") {
            $Stream   = $Res.GetResponseStream()
            $Reader   = New-Object io.streamreader($stream)
            $webpage  = $reader.readtoend()
            $Response = [xml]$webpage
            $Reader.Close()
            $Stream.Close()
            $Res.Close()
        } else {
            Throw "Error Accessing Page $WebPage"
        }

        return ($Response.devices.item | where {$_.objid -eq "$DeviceId"}).probe
    }
}

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
    [string]$DecimalMode
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
    if ($MaxError)    { $Result += "    <limitmaxerror>$MaxError</limitmaxerror>`n"; $LimitMode = $true }
    if ($WarnMsg)     { $Result += "    <limitwarningmsg>$WarnMsg</limitwarningmsg>`n"; $LimitMode = $true }
    if ($ErrorMsg)    { $Result += "    <limiterrormsg>$ErrorMsg</limiterrormsg>`n"; $LimitMode = $true }
    if ($LimitMode)   { $Result += "    <limitmode>1</limitmode>`n" }
    if ($SpeedSize)   { $Result += "    <speedsize>$SpeedSize</speedsize>`n" }
    if ($DecimalMode) { $Result += "    <decimalmode>$DecimalMode</decimalmode>`n" }
    
    if (!($ShowChart)) { $Result += "    <showchart>0</showchart>`n" }
    
    $Result += "  </result>`n"
    
    return $Result
}

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
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::Expect100Continue = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3
        $WebClient = New-Object System.Net.WebClient
    }

    PROCESS {
        $Server   = $Global:PrtgServerObject.Server
        $User     = $Global:PrtgServerObject.UserName
        $PassHash = $Global:PrtgServerObject.PassHash

        $url  = "https://$Server/api/"
        $url += "deleteobject.htm?"
        $url += "username=$User"
        $url += "&passhash=$PassHash"
        $url += "&id=$ObjectId"
        $url += "&approve=1"

        $global:lasturl = $url
        $global:Response = $WebClient.DownloadString($url)

        return $global:Response
    }
}
