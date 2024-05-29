#################################################
# HelloID-Conn-Prov-Target-Myneva-Enable
# PowerShell V2
#################################################

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

    $accountUpdate = @{}
    Write-Information 'Checking if account previous was disabled,'
    if ($actionContext.Data.PSObject.Properties.name -contains 'PrefixLastNameDisable' -and $correlatedAccount.lastname.StartsWith("$($actionContext.Data.PrefixLastNameDisable)")) {
        $accountUpdate.Add('lastname', "$($correlatedAccount.lastname -replace "$($actionContext.Data.PrefixLastNameDisable)")")
    }
    if (($actionContext.Data.PSObject.Properties.name -contains 'active') -and ($correlatedAccount.active -ne $actionContext.Data.active)) {
        $accountUpdate.Add('active', $actionContext.Data.active )
    }

    $actionList = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $correlatedAccount) {
        $actionList.Add('EnableAccount')
        if ( $accountUpdate.Count -gt 0 ) {
            $actionList.Add('UpdateAccount')
        }
        $dryRunMessage = "Enable Myneva account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] will be executed during enforcement"
    } else {
        $actionList.Add('NotFound')
        $dryRunMessage = "Myneva account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
        if ( $actionList -contains 'UpdateAccount') {
            Write-Information "[DryRun] Updating account Properties [$( $accountUpdate.Keys)], Possibly the account was previous disabled"
        }
    }

    if ( $actionContext.Data.Services.Count -lt 1) {
        Write-Information 'No Services Mapped'
    }
    if ( $actionContext.Data.DynamicButtons.Count -lt 1) {
        Write-Information 'No DynamicButtons Mapped'
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        foreach ($action in $actionList) {
            switch ($action) {
                'EnableAccount' {
                    Write-Information "Enabling Myneva account with accountReference: [$($actionContext.References.Account)]"
                    Write-Information "Mapped Services: [$($actionContext.Data.Services -join ', ')]"
                    Write-Information "Mapped Dynamic Buttons: [$($actionContext.Data.DynamicButtons -join ', ')]"

                    $splatInvite = @{
                        PersonId       = $($actionContext.References.Account)
                        Services       = $actionContext.Data.Services
                        DynamicButtons = $actionContext.Data.DynamicButtons
                    }
                    $null = Set-RegasInviteOrSubscribeUser @splatInvite

                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Invite account with Services: [$($actionContext.Data.Services -join ", ")], Dynamic Buttons: [$($actionContext.Data.DynamicButtons -join ", ")] was successful"
                            IsError = $false
                        })
                    break
                }

                'UpdateAccount' {
                    Write-Information "Updating Myneva account properties [$($accountUpdate.Keys)]"
                    $null = Update-RegasPerson -PersonId $actionContext.References.Account -PersonProperties $accountUpdate
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Updated account properties [$($accountUpdate.Keys)]"
                            IsError = $false
                        })
                }

                'NotFound' {
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Myneva account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                            IsError = $true
                        })
                    break
                }
            }
        }
        if ( -not ($outputContext.AuditLogs.IsError -contains $true)) {
            $outputContext.Success = $true
        }
    }
} catch {
    $outputContext.success = $false
    $errorObject = Get-ExceptionMessage -Exception $_
    Write-Warning "Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($_.InvocationInfo.Line). Error: [$($errorObject.Message)], InnerException: [$($errorObject.InnerException)], WebException [$($errorObject.WebError)]"
    if (-not [string]::IsNullOrWhiteSpace($($errorObject.InnerException))) {
        $auditMessage = "Could not Invite Myneva account. Error: $($errorObject.InnerException)"
    } else {
        $auditMessage = "Could not Invite Myneva account. Error: $($errorObject.message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}