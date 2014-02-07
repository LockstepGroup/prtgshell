[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::Expect100Continue = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::ssl3

import-module C:\_strap\prtgshell\prtgshell.psm1
Add-Type -AssemblyName System.Web
function Execute-HTTPPostCommand() {
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

###############################################################################
# set the values

$NewSensorName       = "My New Sensor"
$NewSensorTags       = "xmlexesensor test" # space-seperated tags
$NewSensorPriority   = 3 # 1-5
$NewSensorParameters = ""
$NewSensorMutex      = ""
$NewSensorParentID   = 2044
$NewSensorScript     = "cyberq - status.ps1"

$Server      = "athena.addicks.us"
$User        = "brian"
$Hash        = "2485307868"
$PrtgConnect = Get-PrtgServer $Server $User $Hash

$SensorObject                 = "" | Select Name,Tags,Priority,Script,ExeParams,Environment,SecurityContext,Mutex,ExeResult,ParentId
$SensorObject.Name            = "testcreate"
$SensorObject.Tags            = "xmlexesensor test" # space seperated tags
$SensorObject.Priority        = 3 # 1-5
$SensorObject.Script          = "cyberq - status.ps1"
$SensorObject.ExeParams       = ""
$SensorObject.Environment     = 1 # 0 for default, 1 for placeholders
$SensorObject.SecurityContext = 1 # 0 for probe service, 1 for windows creds of device
$SensorObject.Mutex           = ""
$SensorObject.ExeResult       = 1 # 0 discard, 1 always write result, 2 write result on error
$SensorObject.ParentId        = 2044

function Create-PrtgSensor {
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [psobject]$PrtgObject
    )

    BEGIN {
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
    $Url

    Execute-HTTPPostCommand $Url $QueryString.ToString() | Out-Null

    }

}
Create-PrtgSensor $SensorObject