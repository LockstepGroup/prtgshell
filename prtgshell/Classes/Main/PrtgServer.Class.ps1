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
}