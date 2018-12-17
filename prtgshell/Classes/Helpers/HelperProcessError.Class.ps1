class HelperProcessError {
    static [hashtable] newExceptionDefinition ([string]$exceptionType, $exceptionCategory, [string]$message) {
        $new = @{}
        $new.Exception = New-Object -TypeName $exceptionType -ArgumentList $message
        $new.Category = $exceptionCategory
        return $new
    }

    static [System.Management.Automation.ErrorRecord] throwCustomError ([int]$errorId, [psobject]$object) {
        $ErrorLookup = [HelperProcessError]::ExceptionDefinitions.$errorId
        return [System.Management.Automation.ErrorRecord]::new(
            $ErrorLookup.Exception,
            $errorId,
            $ErrorLookup.Category,
            $object
        )
    }

    # List of Exceptions
    static [hashtable] $ExceptionDefinitions = @{
        1000 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'No Prtg connection established. Use Get-PrtgServer to connect first.')
        1001 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'Unauthorized, please check your credentials.')
    }

    # Constructor
    HelperProcessError () {
    }
}