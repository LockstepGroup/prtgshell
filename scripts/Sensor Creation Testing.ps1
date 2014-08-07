remove-module prtgshell
import-module C:\dev\prtgshell\prtgshell.psm1 -Verbose

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

New-PrtgSensor $SensorObject