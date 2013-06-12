

$Returner = @()

foreach ($Object in (Get-PrtgDeviceSensorsByTag diskspacesensor)) {
  $ThisData = Get-PrtgSensorChannels $Object.objid
	foreach ($Channel in $ThisData) {
		$Channels = "" | Select-Object @{n='device';e={$Object.device}},
			@{n='objid';e={$Object.objid}},
			@{n='sensor';e={$Object.sensor}},
			@{n='status';e={$Object.status}},
			@{n='group';e={$Object.group}},
			@{n='name';e={$Channel.name}},
			@{n='lastvalue';e={$Channel.lastvalue}},
			@{n='raw';e={[double]$Channel.lastvalue_raw}}
		
		$Returner += $Channels
	}
}
