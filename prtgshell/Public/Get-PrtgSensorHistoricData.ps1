Function Get-PrtgSensorHistoricData {
	[CmdletBinding()]
    Param (
    [Parameter(Mandatory=$True,Position=0)]
    [int] $SensorId,

		[Parameter(Mandatory=$True,Position=1)]
		[datetime] $RangeStart,

		[Parameter(Mandatory=$True,Position=2)]
		[datetime] $RangeEnd,

		[Parameter(Mandatory=$True,Position=3)]
		[int] $IntervalInSeconds = 3600
    )

    BEGIN {
			$PrtgServerObject = $global:PrtgServerObject
			$QueryTable = @{}
    }

    PROCESS {
			$QueryPage = 'historicdata.xml'
			$QueryTable.id = $SensorId
			$QueryTable.sdate = $RangeStart.ToString("yyyy-MM-dd-HH-mm-ss")
			$QueryTable.edate = $RangeEnd.ToString("yyyy-MM-dd-HH-mm-ss")
			$QueryTable.avg = $IntervalInSeconds
			$Response = $global:PrtgServerObject.invokeApiQuery($QueryTable, $QueryPage)
			$DataPoints = $Response.HistData.Item | ? { $_.'Date Time' -ne 'Averages' }
		}

	END {
		return $DataPoints
    }
}
