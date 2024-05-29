#################################################
# HelloID-Conn-Prov-Target-Myneva-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    Write-Information 'Initializing Myneva configuration'
    Import-Module "$($actionContext.Configuration.PowerShellModulePath)" -Force

    $splatMynevaSession = @{
        Username         = $actionContext.Configuration.UserName
        Password         = ConvertTo-SecureString -String "$($actionContext.Configuration.Password)"  -AsPlainText -Force
        WebServiceUrl    = $actionContext.Configuration.BaseUrl
        FilePathDLL      = $actionContext.Configuration.FilePathDLL
        OrganisationCode = $actionContext.Configuration.OrganizationCode
    }
    $null = New-RegasSession @splatMynevaSession

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        # Verify if a user must be either [created ] or just [correlated]
        $correlatedAccount = Get-RegasPerson -Email $correlationValue
    }

    if ($null -ne $correlatedAccount ) {
        $action = 'CorrelateAccount'
        $outputContext.AccountReference = $correlatedAccount.id
        $outputContext.AccountCorrelated = $true
    } else {
        $action = 'CreateAccount'
    }
    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $action Myneva account for: [$($personContext.Person.DisplayName)], will be executed during enforcement"
        $outputContext.success = $true
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'CreateAccount' {
                Write-Information 'Creating and correlating Myneva account'
                $createdAccount = New-RegasPerson -PersonProperties $actionContext.Data
                $outputContext.AccountReference = $createdAccount.personId
                $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
                break
            }

            'CorrelateAccount' {
                Write-Information 'Correlating Myneva account'
                $outputContext.Data = $correlatedAccount
                $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
                break
            }
        }

        $outputContext.success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = $action
                Message = $auditLogMessage
                IsError = $false
            })
    }
} catch {
    $outputContext.success = $false
    $errorObject = Get-ExceptionMessage -Exception $_
    Write-Warning "Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($_.InvocationInfo.Line). Error: [$($errorObject.Message)], InnerException: [$($errorObject.InnerException)], WebException [$($errorObject.WebError)]"
    if (-not [string]::IsNullOrWhiteSpace($($errorObject.InnerException))) {
        $auditMessage = "Could not create or correlate Myneva account. Error: $($errorObject.InnerException)"
    } else {
        $auditMessage = "Could not create or correlate Myneva account. Error: $($errorObject.message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
