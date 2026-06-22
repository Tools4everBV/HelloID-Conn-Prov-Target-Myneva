#################################################
# HelloID-Conn-Prov-Target-Myneva-Import
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
#endregion

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

    Write-Information 'Starting Myneva account entitlement import'
    $importedAccounts = Get-RegasPersonList

    foreach ($importedAccount in $importedAccounts) {
        # Making sure only fieldMapping fields are imported
        $data = @{}
        foreach ($field in $actionContext.ImportFields) {
            $data[$field] = $importedAccount.$field
        }

        # Additional for country(id)
        if ($data.ContainsKey('CountryId') -and $importedAccount.country.id) {
            $data['CountryId'] = "$($importedAccount.country.id)"
        }

        # Get additional data for the account
        if ($actionContext.Configuration.ImportDynamicButtons -and $data.ContainsKey('DynamicButtons') ) {
            $dynamicButtons = Get-RegasDynamicButtonsList -PersonId $importedAccount.Id
            $data['DynamicButtons'] = $dynamicButtons.name
        }
        if ($actionContext.Configuration.ImportServices -and $data.ContainsKey('Services')) {
            $services = Get-RegasServiceList -PersonId $importedAccount.Id
            $data['Services'] = $services.Name
        }

        # Set Enabled based on importedAccount status
        $isEnabled = $false
        if ($importedAccount.active -eq 'yes') {
            $isEnabled = $true
        }

        # Make sure the displayName has a value
        $displayName = "$($importedAccount.FirstName) $($importedAccount.Lastname)".trim()
        if ([string]::IsNullOrEmpty($displayName)) {
            $displayName = $importedAccount.Id
        }

        # Make sure the userName has a value
        if ([string]::IsNullOrWhiteSpace($importedAccount.Email)) {
            $importedAccount.Email = $importedAccount.Id
        }

        # Return the result
        Write-Output @{
            AccountReference = $importedAccount.Id
            DisplayName      = $displayName
            UserName         = $importedAccount.Email
            Enabled          = $isEnabled
            Data             = $data
        }
    }
    Write-Information 'Myneva account entitlement import completed'
}
catch {
    $ex = $PSItem
    $errorObject = Get-ExceptionMessage -Exception $_
    if (-not [string]::IsNullOrWhiteSpace($($errorObject.InnerException))) {
        Write-Warning "Error message '$($errorObject.message)', InnerException: '$($errorObject.InnerException)'. WebError: $($errorObject.WebError)"
        Write-Error "Could not import Myneva account entitlements. Error: $($errorObject.InnerException)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Myneva account entitlements. Error: $($ex.Exception.Message)"
    }
}
