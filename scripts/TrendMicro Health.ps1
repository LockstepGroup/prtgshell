Param (
    [Parameter(mandatory=$True,Position=0)]
    [string]$Computer
)

import-module prtgshell

$ServiceNames = @("ntrtscan"
                  "tmlisten"
                  "tmproxy")

function Get-SpecificServices ($ServiceNames,$Computer) {
    $Query = "select * from win32_service where"
    $i = 0
    foreach ($s in $ServiceNames) {
        if ($i -gt 0) { $Query += " or" }
        $Query += " (name = '$s')"
        $i++
    }
    $Services = gwmi -ComputerName $computer -query $query
    return $Services
}


$XmlOutput  = "<prtg>`n"

$Arch = (gwmi -computername $computer -class win32_computersystem).systemtype.substring(1,2)

if ( $Arch -eq "86" ) {
    $RegKey = "software\trendmicro\pc-cillinntcorp\currentversion\misc."
} elseif ( $Arch -eq "64" ) {
    $RegKey = "software\wow6432node\trendmicro\pc-cillinntcorp\currentversion\misc."
} else {
    return "Cannot determine Architecture"
}

$LimitMaxError   = 4
$LimitMaxWarning = 1

$Name   = "PatternDate"

$XmlOutput  = "<prtg>`n"
try {
    $RemoteReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computer)
    $SubKey    = $RemoteReg.opensubkey($RegKey)
    $Value     = $SubKey.GetValue($Name)

    $LastUpdate = [datetime]::ParseExact($Value,"yyyymmdd",$null)
    $LastUpdate = $LastUpdate.ToShortDateString()
    $LastDay = (Get-Date -date $LastUpdate).DayOfYear

    $Difference = (Get-Date).DayOfYear - $LastDay

    $XmlOutput += Set-PrtgResult "Update Age (Days)" $Difference Days -sc -me $LimitMaxError -mw $LimitMaxWarning
    $XmlOutput += "  <text>Last Update: $LastUpdate</text>`n"
} catch {
    $XmlOutput += Set-PrtgResult "Update Age (Days)" 99 Days -sc -me $LimitMaxError -mw $LimitMaxWarning
    $XmlOutput += "  <text>Registry key not found.</text>`n"
}

$TrendServices = Get-SpecificServices $ServiceNames $Computer

foreach ($t in $ServiceNames) {
    $Lookup = $Trendservices | ? { $_.name -eq $t }
    $State = 0
    if ($Lookup.state -ne "Running") { $State = 1 }
    $XmlOutput += Set-PrtgResult "$($Lookup.DisplayName) (service)" $State state -me 0 -em "Service is not running"
}

$XmlOutput += "</prtg>"

$XmlOutput