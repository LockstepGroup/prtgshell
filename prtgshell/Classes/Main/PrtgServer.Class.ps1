class PrtgServer {
    [string]$Hostname

    [ValidateRange(1, 65535)]
    [int]$Port = 443

    [ValidateSet('http', 'https')]
    [string]$Protocol = "https"

    [string]$UserName
    [string]$PassHash

    # Track usage
    hidden [bool]$Connected
    [array]$UrlHistory
    [array]$RawQueryResultHistory
    [array]$QueryHistory
    $LastError
    $LastResult

    # Status Properties
    [int]$NewAlarms
    [int]$Alarms
    [int]$AckAlarms
    [int]$NewToDos
    [string]$Clock
    [datetime]$ClockasDateTime
    [string]$ActivationStatusMessage
    [int]$BackgroundTasks
    [int]$CorrelationTasks
    [int]$AutoDiscoTasks
    [string]$Version
    [bool]$PRTGUpdateAvailable
    [bool]$IsAdminUser
    [bool]$IsCluster
    [bool]$ReadOnlyUser
    [bool]$ReadOnlyAllowAcknowledge

    # Generate Api URL
    [String] getApiUrl([hashtable]$queryHashtable, [string]$queryPage) {
        $formattedQueryString = [HelperWeb]::createQueryString($queryHashtable)
        if ($this.Hostname) {
            $url = $this.Protocol + "://" + $this.Hostname + ':' + $this.Port + "/api/" + $queryPage + $formattedQueryString
            return $url
        } else {
            return $null
        }
    }


    # Test Connection
    [bool] testConnection() {
        $result = $this.invokeApiQuery(@{}, 'getstatus.xml')
        $this.Connected = $true
        $this.NewAlarms = $result.status.NewAlarms
        $this.Alarms = $result.status.Alarms
        $this.AckAlarms = $result.status.AckAlarms
        $this.NewToDos = $result.status.NewToDos
        $this.Clock = $result.status.Clock
        $this.ClockasDateTime = $result.status.Clock
        $this.ActivationStatusMessage = $result.status.ActivationStatusMessage
        $this.BackgroundTasks = $result.status.BackgroundTasks
        $this.CorrelationTasks = $result.status.CorrelationTasks
        $this.AutoDiscoTasks = $result.status.AutoDiscoTasks
        $this.Version = $result.status.Version
        $this.PRTGUpdateAvailable = $result.status.PRTGUpdateAvailable
        $this.IsAdminUser = $result.status.IsAdminUser
        $this.IsCluster = $result.status.IsCluster
        $this.ReadOnlyUser = $result.status.ReadOnlyUser
        $this.ReadOnlyAllowAcknowledge = $result.status.ReadOnlyAllowAcknowledge
        return $true
    }

    #region ApiQueryFunctions
    ###################################################################################################
    #region GetPassHashQuery
    # example: https://prtg.example.com/api/getpasshash.htm?username=JohnDoe&password=TopSecret
    [xml] invokeGetPassHashQuery([PSCredential]$credential) {
        $queryString = @{}
        $queryPage = "getpasshash.htm"
        $queryString.username = $credential.UserName
        $queryString.password = $Credential.getnetworkcredential().password
        $result = $this.invokeApiQuery($queryString, $queryPage)
        $this.UserName = $credential.UserName
        $this.PassHash = $result.objects.object.'#text'
        return $result
    }
    #endregion GetPassHashQuery

    #region invokeApiQuery
    [xml] invokeApiQuery([hashtable]$queryHashtable, [string]$queryPage) {
        # If the query is not a GetPassHash query we need to append the PassHash and UserName to the query string
        if ($queryPage -ne "getpasshash.htm") {
            $queryHashtable.username = $this.UserName
            $queryHashtable.passhash = $this.PassHash
        }

        $url = $this.getApiUrl($queryHashtable, $queryPage)

        #region trackHistory
        # Populate Query/Url History
        # Redact password if it's a keygen query
        if ($queryPage -ne "getpasshash.htm") {
            $this.UrlHistory += $url
        } else {
            $EncodedPassword = [System.Web.HttpUtility]::UrlEncode($queryHashtable.password)
            $queryHashtable.password = 'PASSWORDREDACTED'
            $this.UrlHistory += $url.Replace($EncodedPassword, "PASSWORDREDACTED")
        }

        # add query object to QueryHistory
        $this.QueryHistory += $queryHashtable
        #endregion trackHistory



        # try query
        try {
            $QueryParams = @{}
            $QueryParams.Uri = $url
            $QueryParams.UseBasicParsing = $true

            switch ($global:PSVersionTable.PSEdition) {
                'Core' {
                    $QueryParams.SkipCertificateCheck = $true
                    continue
                }
                default {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    try {
                        add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
                    } catch {

                    }
                    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
                    continue
                }
            }

            $rawResult = Invoke-WebRequest @QueryParams -Verbose:$false # doing this mostly to prevent plaintext password from being displayed by accident.
        } catch {
            Throw $_
        }

        $this.RawQueryResultHistory += $rawResult

        if ($queryPage -eq "getpasshash.htm") {
            $result = @{'passhash' = $rawResult.Content}
            $result = [xml]($result.passhash | ConvertTo-Xml)
        } else {
            $result = [xml]($rawResult.Content)
        }

        $this.LastResult = $result

        return $result

        <#

        $result = [xml]($rawResult.Content)


        $proccessedResult = $this.processQueryResult($result)

        return $proccessedResult #>
    }
    #endregion invokeApiQuery
    ###################################################################################################
    #endregion ApiQueryFunctions

    #region Initiators
    ###################################################################################################
    # Blank Initiator
    PrtgServer() {
    }

    # Initiator with PassHash
    PrtgServer([string]$Hostname, [string]$UserName, [string]$PassHash, [string]$Protocol = "https", [int]$Port = 443) {
        $this.Hostname = $Hostname
        $this.UserName = $UserName
        $this.PassHash = $PassHash
        $this.Protocol = $Protocol
        $this.Port = $Port
    }

    # Initiator with Credential
    PrtgServer([string]$Hostname, [PSCredential]$Credential, [string]$Protocol = "https", [int]$Port = 443) {
        $this.Hostname = $Hostname
        $this.Protocol = $Protocol
        $this.Port = $Port
        $this.invokeGetPassHashQuery($Credential)
    }
    #endregion Initiators

    <#
    ##################################### Main Api Query Function #####################################
    # invokeApiQuery
    [xml] invokeApiQuery([hashtable]$queryString) {
        # If the query is not a keygen query we need to append the apikey to the query string
        if ($queryString.type -ne "keygen") {
            $queryString.key = $this.ApiKey
        }

        # format the query string and general the full url
        $formattedQueryString = [HelperWeb]::createQueryString($queryString)
        $url = $this.getApiUrl($formattedQueryString)

        # Populate Query/Url History
        # Redact password if it's a keygen query
        if ($queryString.type -ne "keygen") {
            $this.UrlHistory += $url
        } else {
            $this.UrlHistory += $url.Replace($queryString.password, "PASSWORDREDACTED")
            $queryString.password = $queryString.password, "PASSWORDREDACTED"
        }

        # add query object to QueryHistory
        $this.QueryHistory += $queryString

        # try query
        try {
            $QueryParams = @{}
            $QueryParams.Uri = $url
            $QueryParams.UseBasicParsing = $true

            switch ($global:PSVersionTable.PSEdition) {
                'Core' {
                    $QueryParams.SkipCertificateCheck = $true
                    continue
                }
                default {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    try {
                        add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
                    } catch {

                    }
                    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
                    continue
                }
            }

            $rawResult = Invoke-WebRequest @QueryParams
        } catch {
            Throw $_
        }

        $result = [xml]($rawResult.Content)
        $this.RawQueryResultHistory += $rawResult
        $this.LastResult = $result

        $proccessedResult = $this.processQueryResult($result)

        return $proccessedResult
    }

    # processQueryResult
    [xml] processQueryResult ([xml]$unprocessedResult) {
        $result = $null

        switch ($unprocessedResult.response.status) {
            'success' {
                $result = $unprocessedResult
            }
            'error' {
                if ($unprocessedResult.response.msg.line) {
                    if ($unprocessedResult.response.msg.line.'#cdata-section') {
                        $Message = $unprocessedResult.response.msg.line.'#cdata-section' -join "`r`n"
                        Write-Verbose "line and #cdata-section detected: $Message"
                    } else {
                        $Message = $unprocessedResult.response.msg.line -join "`r`n"
                        Write-Verbose "line detected: $Message"
                    }
                } else {
                    $Message = $unprocessedResult.response.msg
                    Write-Verbose "line not detected: $Message"
                }
                Throw $Message
            }
            'unauth' {
                $Message = $unprocessedResult.response.msg.line
                Throw $Message
            }
        }

        return $result
    }

    # Keygen API Query
    [xml] invokeKeygenQuery([PSCredential]$credential) {
        $queryString = @{}
        $queryString.type = "keygen"
        $queryString.user = $credential.UserName
        $queryString.password = $Credential.getnetworkcredential().password
        $result = $this.invokeApiQuery($queryString)
        $this.ApiKey = $result.response.result.key
        return $result
    }

    # Commit API Query
    [xml] invokeCommitQuery([string]$cmd) {
        $queryString = @{}
        $queryString.type = "commit"
        $queryString.cmd = $cmd
        $result = $this.invokeApiQuery($queryString)
        return $result
    }

    # Operational API Query
    [xml] invokeOperationalQuery([string]$cmd) {
        $queryString = @{}
        $queryString.type = "op"
        $queryString.cmd = $cmd
        $result = $this.invokeApiQuery($queryString)
        return $result
    }

    # invokeConfigQuery without element
    [Xml] invokeConfigQuery([string]$Action, [string]$XPath) {
        $queryString = @{}
        $queryString.type = "config"
        $queryString.action = $Action
        $queryString.xpath = $xPath

        $result = $this.invokeApiQuery($queryString)
        return $result
    }

    # invokeConfigQuery with element/location
    [Xml] invokeConfigQuery([string]$Action, [string]$XPath, [string]$Element) {
        $queryString = @{}
        $queryString.type = "config"
        $queryString.action = $Action
        $queryString.xpath = $XPath
        switch ($Action) {
            'move' {
                $queryString.where = $Element
                continue
            }
            'set' {
                $queryString.element = $Element
                continue
            }
        }

        $result = $this.invokeApiQuery($queryString)
        return $result
    }

    # invokeReportQuery
    [Xml] invokeReportQuery([string]$ReportType, [string]$ReportName, [string]$Cmd) {
        $queryString = @{}
        $queryString.type = "report"
        $queryString.reporttype = $ReportType
        $queryString.reportname = $ReportName
        $queryString.cmd = $Cmd

        $result = $this.invokeApiQuery($queryString)
        return $result
    }

    # invokeReportGetQuery
    [Xml] invokeReportGetQuery([int]$JobId) {
        $queryString = @{}
        $queryString.type = "report"
        $queryString.action = "get"
        $queryString.'job-id' = $JobId

        $result = $this.invokeApiQuery($queryString)
        return $result
    }

    #  https://<firewall>/api/?type=report&action=get&job-id=jobid

    # Test Connection
    [bool] testConnection() {
        $result = $this.invokeOperationalQuery('<show><system><info></info></system></show>')
        $this.Connected = $true
        $this.Name = $result.response.result.system.devicename
        $this.Hostname = $result.response.result.system.'ip-address'
        $this.Model = $result.response.result.system.model
        $this.Serial = $result.response.result.system.serial
        $this.OsVersion = $result.response.result.system.'sw-version'
        $this.GpAgent = $result.response.result.system.'global-protect-client-package-version'
        $this.AppVersion = $result.response.result.system.'app-version'
        $this.ThreatVersion = $result.response.result.system.'threat-version'
        $this.WildFireVersion = $result.response.result.system.'wildfire-version'
        $this.UrlVersion = $result.response.result.system.'url-filtering-version'
        if ($result.response.result.system.'multi-vsys' -eq 'on') {
            $this.VsysEnabled = $true
        } else {
            $this.VsysEnabled = $false
        }
        return $true
    }

     #>
}