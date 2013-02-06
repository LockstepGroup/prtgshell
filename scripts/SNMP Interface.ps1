Param (
    [Parameter(mandatory=$True,Position=0)]
    [string]$Agent,
    
    [Parameter(mandatory=$True,Position=1)]
    [string]$Community,
    
    [Parameter(mandatory=$True,Position=2)]
    [string]$Version,
    
    [Parameter(mandatory=$True,Position=3)]
    [string]$Port
)

$Timer = Get-Date
Import-Module C:\_strap\prtgshell\prtgshell.psm1

$Admin         = snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifAdminStatus.$Port"
$Oper          = snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifOperStatus.$Port"
$IfInOctets    = [int64](snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifInOctets.$Port")
$IfOutOctets   = [int64](snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifOutOctets.$Port")
$IfInErrors    = snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifInErrors.$Port"
$IfOutErrors   = snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifOutErrors.$Port"
$IfInDiscards  = snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifInDiscards.$Port"
$IfOutDiscards = snmpget.exe -Ovq -r 3 -v $Version -c $Community $Agent "IF-MIB::ifOutDiscards.$Port"

if (($Oper -eq "dormant") -or ($Oper -eq "up")) { $Oper = 0 } `
    elseif ($Oper -eq "down")                   { $Oper = 1 } `
    elseif ($Oper -eq "notPresent")             { $Oper = 2 } `
    else                                        { $Oper = 3 }

if ($Admin -eq "up") { $Admin = 0 } `
    else             { $Admin = 1 }

$Elapsed = [math]::round(((Get-Date) - $Timer).TotalMilliSeconds,2)

$XmlOutput  = "<prtg>`n"

$XmlOutput += Set-PrtgResult "Total Traffic" ($IfInOctets + $IfOutOctets) BytesBandwidth -ss KiloBit -mo Difference -sc -dm Auto

$XmlOutput += Set-PrtgResult "Inbound Traffic"  $IfInOctets  BytesBandwidth -ss KiloBit -mo Difference -sc -dm Auto
$XmlOutput += Set-PrtgResult "Outbound Traffic" $IfOutOctets BytesBandwidth -ss KiloBit -mo Difference -sc -dm Auto

$XmlOutput += Set-PrtgResult "Inbound Errors"    $IfInErrors    Count -mo Difference
$XmlOutput += Set-PrtgResult "Outbound Errors"   $IfOutErrors   Count -mo Difference
$XmlOutput += Set-PrtgResult "Inbound Discards"  $IfInDiscards  Count -mo Difference
$XmlOutput += Set-PrtgResult "Outbound Discards" $IfOutDiscards Count -mo Difference

$XmlOutput += Set-PrtgResult "Admin Status"       $Admin admin -me 0 -em "Port is administratively down"
$XmlOutput += Set-PrtgResult "Operational Status" $Oper  oper  -me 0 -em "Operational: 1 = down, 2 = not present, 3 = other"

$XmlOutput += Set-PrtgResult "Execution Time" $Elapsed msecs
$XmlOutput += "</prtg>"

$XmlOutput