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
    # The Types and Categories here are generic because I have no idea what subset exist in both core and non-core.
    static [hashtable] $ExceptionDefinitions = @{
        1000 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'No Prtg connection established. Use Get-PrtgServer to connect first.')
        1001 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'Unauthorized, please check your credentials.')
        1002 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'Invalid Column specified for requested Content.')
        1003 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'Cannot find the specified Server. Check the Hostname/Ip and try again.')
        9999 = [HelperProcessError]::newExceptionDefinition('System.ArgumentException', [System.Management.Automation.ErrorCategory]::CloseError, 'Unhandled Exception') # Probably going to mask errors, not sure what else to do at this point.
    }

    # Constructor
    HelperProcessError () {
    }
}