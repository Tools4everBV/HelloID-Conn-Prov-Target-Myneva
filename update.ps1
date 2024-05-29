#################################################
# HelloID-Conn-Prov-Target-Myneva-Update
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }
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
    $correlatedAccount = Get-RegasPerson -PersonID $actionContext.References.Account
    $outputContext.PreviousData = $correlatedAccount


    # Always compare the account against the current account in target system
    if ($null -ne $correlatedAccount) {
        $splatCompareProperties = @{
            ReferenceObject  = @($outputContext.PreviousData.PSObject.Properties)
            DifferenceObject = @(($actionContext.Data | Select-Object * -ExcludeProperty CountryId).PSObject.Properties)
        }
        $propertiesChangedObject = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
        $propertiesChanged = @{}
        $propertiesChangedObject | ForEach-Object { $propertiesChanged[$_.Name] = $_.Value }

        # Additional compare for country(id)
        if ((-not [string]::IsNullOrEmpty($actionContext.Data.CountryID)) -and $actionContext.Data.CountryId -ne $outputContext.PreviousData.country.id) {
            $propertiesChanged['CountryId'] = $actionContext.Data.CountryId
        }

        if ($propertiesChanged.Count -gt 0) {
            $action = 'UpdateAccount'
            $dryRunMessage = "Account property(s) required to update: $($propertiesChanged.Keys -join ', ')"
        } else {
            $action = 'NoChanges'
            $dryRunMessage = 'No changes will be made to the account during enforcement'
        }
    } else {
        $action = 'NotFound'
        $dryRunMessage = "Myneva account for: [$($personContext.Person.DisplayName)] not found. Possibly deleted."
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'UpdateAccount' {
                Write-Information "Updating Myneva account with accountReference: [$($actionContext.References.Account)]"
                $null = Update-RegasPerson -PersonId $actionContext.References.Account -PersonProperties $propertiesChanged

                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged.Keys -join ',')]"
                        IsError = $false
                    })
                break
            }

            'NoChanges' {
                Write-Information "No changes to Myneva account with accountReference: [$($actionContext.References.Account)]"

                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = 'No changes will be made to the account during enforcement'
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $outputContext.Success = $false
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Myneva account with accountReference: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                        IsError = $true
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
        $auditMessage = "Could not update Myneva account. Error: $($errorObject.InnerException)"
    } else {
        $auditMessage = "Could not update Myneva account. Error: $($errorObject.message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
