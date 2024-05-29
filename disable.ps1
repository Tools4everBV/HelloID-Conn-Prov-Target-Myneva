##################################################
# HelloID-Conn-Prov-Target-Myneva-Disable
# PowerShell V2
##################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12



try {
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

    Write-Information "Verifying if a Myneva account for [$($personContext.Person.DisplayName)] exists"
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }
    $correlatedAccount = Get-RegasPerson -PersonID $actionContext.References.Account
    $outputContext.PreviousData = $correlatedAccount

    if ($null -ne $correlatedAccount) {
        $action = 'DisableAccount'
        $dryRunMessage = "Disable Myneva account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] will be executed during enforcement"
    } else {
        $action = 'NotFound'
        $dryRunMessage = "Myneva account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'DisableAccount' {
                Write-Information "Disabling Myneva account with accountReference: [$($actionContext.References.Account)]"

                if ($actionContext.Data.PSObject.Properties.name -contains 'PrefixLastNameDisable') {
                    if (-not $correlatedAccount.lastname.StartsWith("$($actionContext.Data.PrefixLastNameDisable)")) {
                        $actionContext.Data | Add-Member @{
                            lastname = "$($actionContext.Data.PrefixLastNameDisable)$($correlatedAccount.lastname)"
                        } -Force
                    }
                }
                $null = Update-RegasPerson -PersonId $actionContext.References.Account -PersonProperties $actionContext.Data | Select-Object * -ExcludeProperty PrefixLastNameDisable

                $null = Disable-RegasPerson -PersonId $($actionContext.References.Account)

                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Disable (detachUsers) account was successful, Update Lastname with prefix: [$($actionContext.Data.PrefixLastNameDisable)]"
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Myneva account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                        IsError = $false
                    })
                break
            }
        }
    }
} catch {
    $outputContext.success = $false
    $errorObject = Get-ExceptionMessage -Exception $_
    Write-Warning "Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($_.InvocationInfo.Line). Error: [$($errorObject.Message)], InnerException: [$($errorObject.InnerException)], WebException [$($errorObject.WebError)]"
    if (-not [string]::IsNullOrWhiteSpace($($errorObject.InnerException))) {
        $auditMessage = "Could not disable Myneva account. Error: $($errorObject.InnerException)"
    } else {
        $auditMessage = "Could not disable Myneva account. Error: $($errorObject.message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}