---
external help file: prtgshell-help.xml
Module Name: prtgshell
online version:
schema: 2.0.0
---

# Get-PrtgServer

## SYNOPSIS
Performs initial connection to Prtg Server.

## SYNTAX

### PassHash (Default)
```
Get-PrtgServer [-Server] <String> [-UserName] <String> [-PassHash] <String> [[-Port] <Int32>] [-HttpOnly]
 [-SkipCertificateCheck] [-Quiet] [<CommonParameters>]
```

### Credential
```
Get-PrtgServer [-Server] <String> [-Credential] <PSCredential> [[-Port] <Int32>] [-HttpOnly]
 [-SkipCertificateCheck] [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
Performs initial connection to Prtg Server. Runs a getstatus query to get some info about the sever and test connectivity. Additionally, if Credential is provided, the user's PassHash is retrieved.

## EXAMPLES

### Example 1
```powershell
PS C:\> Get-PrtgServer -Server 'prtg.example.com' -UserName JohnDoe -PassHash 1234567890
Port                     : 443
Protocol                 : https
Hostname                 : prtg.example.com
UserName                 : JohnDoe
PassHash                 : 1234567890
UrlHistory               : {https://prtg.example.com:443/api/getstatus.xml?passhash=1234567890&username=JohnDoe}
LastError                :
LastResult               : #document
NewAlarms                : 0
Alarms                   : 21
AckAlarms                : 7
NewToDos                 : 0
Clock                    : 12/14/2018 1:40:41 PM
ClockasDateTime          : 12/14/18 1:40:41 PM
ActivationStatusMessage  : (Tag activationstatusalert unknown)
BackgroundTasks          : 0
CorrelationTasks         : 0
AutoDiscoTasks           : 0
Version                  : 18.2.41.1652+
PrtgUpdateAvailable      : True
IsAdminUser              : True
IsCluster                : False
ReadOnlyUser             : False
ReadOnlyAllowAcknowledge : False
```

Initiates connection to Prtg Server with the provided Username and PassHash.

### Example 2
```powershell
PS C:\> Get-PrtgServer -Server 'prtg.example.com' -Credential (Get-Credential) -SkipCertificateCheck
Port                     : 443
Protocol                 : https
Hostname                 : prtg.example.com
UserName                 : JohnDoe
PassHash                 : 1234567890
UrlHistory               : {https://prtg.example.com:443/api/getpasshash.htm?password=PASSWORDREDACTED&username=JohnDoe,
                           https://prtg.example.com:443/api/getstatus.xml?passhash=1234567890&username=JohnDoe}
LastError                :
LastResult               : #document
NewAlarms                : 0
Alarms                   : 21
AckAlarms                : 7
NewToDos                 : 0
Clock                    : 12/14/2018 1:40:41 PM
ClockasDateTime          : 12/14/18 1:40:41 PM
ActivationStatusMessage  : (Tag activationstatusalert unknown)
BackgroundTasks          : 0
CorrelationTasks         : 0
AutoDiscoTasks           : 0
Version                  : 18.2.41.1652+
PrtgUpdateAvailable      : True
IsAdminUser              : True
IsCluster                : False
ReadOnlyUser             : False
ReadOnlyAllowAcknowledge : False
```

Initiates connection to Prtg Server with the provided Credential skipping validation of the provided SSL certificate.

### Example 3
```powershell
PS C:\> Get-PrtgServer -Server 'prtg.example.com' -Credential (Get-Credential) -HttpOnly -Quiet -Port 8080
```

Initiates connection to Prtg Server with the provided Credential using plaintext HTTP on port 8080. No result is returned to the output stream due to the -Quiet switch.

## PARAMETERS

### -Credential
PSCredential object with a valid username/password.

```yaml
Type: PSCredential
Parameter Sets: Credential
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HttpOnly
Specifies to use plaintext HTTP instead of SSL.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: http

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassHash
Specified the PassHash of the provided Username.

```yaml
Type: String
Parameter Sets: PassHash
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Port
Specifies a non-default port.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quiet
Does not return any result to the output stream.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: q

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Server
IP or Hostname of the Prtg server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipCertificateCheck
Disabled validation of Prtg server's SSL certificate.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserName
Specifies the desired Username to connect with.

```yaml
Type: String
Parameter Sets: PassHash
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
## OUTPUTS

### PrtgServer
## NOTES

## RELATED LINKS

[https://github.com/LockstepGroup/prtgshell](https://github.com/LockstepGroup/prtgshell)

[https://www.powershellgallery.com/packages/prtgshell](https://www.powershellgallery.com/packages/prtgshell)