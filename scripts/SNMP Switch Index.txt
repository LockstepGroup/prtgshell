Param (
    [Parameter(mandatory=$True,Position=0)]
    [string]$Agent,
    
    [Parameter(mandatory=$True,Position=1)]
    [string]$Community,
    
    [Parameter(mandatory=$True,Position=2)]
    [string]$Version,
    
    [Parameter(mandatory=$True,Position=3)]
    [int]$DeviceId,
    
    [Parameter(mandatory=$True,Position=4)]
    [int]$CloneSensor
)

$PrtgServer  = "prtgserver"
$PrtgUser    = "prtguser"
$PrtgPass    = "1111111111"

$Timer = get-date
Import-Module C:\_strap\prtgshell\prtgshell.psm1
Add-Type -AssemblyName System.Web

$IfNames   = snmpwalk.exe -OqsU -r 3 -v $Version -c $Community $Agent "IF-MIB::ifName"
$IfAliases = snmpwalk.exe -OqsU -r 3 -v $Version -c $Community $Agent "IF-MIB::ifAlias"
$IfAliases = [string]::join("`n",$IfAliases)

$Ports   = @()
$IndexRx = [regex] 'ifName\.(\d+)'
$NameRx  = [regex] '\.\d+\ (\w+\.\d+\.\d+)'

foreach ($i in $IfNames) {
    $Index   = $IndexRx.Match($i).Groups[1].Value
    
    $AliasRx = [regex] "(?msx)ifAlias\.$Index\s([^`$]*? )`$"
    $Alias   = $AliasRx.Match($ifAliases).Groups[1].Value
    $Name    = $NameRx.Match($i).Groups[1].Value
    
    $Port = "" | Select Index,Name,Alias
    $Port.Index = $Index
    $Port.Name  = $Name
    $Port.Alias = $Alias
    $Ports     += $Port
}

$TotalPorts  = $Ports.Count
$ActivePorts = $Ports | where {$_.Alias}

$PrtgConnect   = Get-PrtgServer $PrtgServer $PrtgUser $PrtgPass
$DeviceIp      = Get-PrtgObjectProp $DeviceId host
$DeviceSensors = Get-PrtgDeviceSensors $DeviceId
$CommentRx     = [regex] 'interface\ =\ (\d+)'
$n             = 0
$r             = 0
$d             = 0

foreach ($p in $ActivePorts) {
    $PortName   = $p.Name
    $PortAlias  = $p.Alias
    $SensorName = "$Portname - $PortAlias"
    $Exists     = $DeviceSensors | Where { $_.comments -match $p.Index }
    
    if ($Exists) {
        "Exists: $SensorName"
        if ($Exists.count -gt 1) {
            "Double detected"
        } elseif ($Exists.Sensor -ne $SensorName) {
            $Rename = Rename-PrtgSensor $Exists.objid $SensorName
            $r++
        }
    } else {
        "adding $SensorName"
        $ExeParams = "'%host' '%snmpcommunity' '2c' '$($p.Index)'"
        $NewSensor = Copy-PrtgSensor $CloneSensor $SensorName $DeviceId
        $Resume    = Resume-PrtgObject $NewSensor
        $SetParam  = Set-PrtgObjectProperty $NewSensor exeparams $ExeParams
        $Comment   = [System.Web.HttpUtility]::UrlEncode("interface = $($p.Index)")
        $SetNote   = Set-PrtgObjectProperty $NewSensor comments  $Comment
        if (!($?)) { Throw "error" }
        $n++
    }
}

foreach ($s in $DeviceSensors) {
    $Match = $CommentRx.Match($s.comments)
    if ($Match.Success) {
        $IfIndex = $Match.Groups[1].Value
        $Lookup = $ActivePorts | ? {$_.index -eq $IfIndex}
        if (!($Lookup)) {
            "Removing $($s.objid): $($s.sensor)"
            $Remove = Remove-PrtgObject $s.objid
            $d++
        }
    }
}

$Elapsed    = [math]::round(((Get-Date) - $Timer).TotalSeconds,2)
$XmlOutput  = "<prtg>`n"
$XmlOutput += Set-PrtgResult "Execution Time" $Elapsed secs -sc
$XmlOutput += Set-PrtgResult "Total Ports" $TotalPorts ports
$XmlOutput += Set-PrtgResult "Active Ports" $ActivePorts.Count ports
$XmlOutput += Set-PrtgResult "New Ports" $n ports
$XmlOutput += Set-PrtgResult "Renamed Ports" $r ports
$XmlOutput += Set-PrtgResult "Deleted Ports" $d ports
$XmlOutput += "</prtg>"

$XmlOutput