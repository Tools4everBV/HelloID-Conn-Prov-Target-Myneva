#Requires -Version 5.0

############################################################
# Name        : myneva
# Application : IAM => HellID
# Version     : 1.0
# Copyright   : (c) Tools4ever, 2024
# Tags        : RCA

# Supported PowerShell Versions: 5.0 5.1
############################################################

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$script:WebserviceUrl
$script:OrganisationCode
$script:PersonService
$script:GroupService
$script:Credentials = @{
    Username = $null
    Password = $null
}

function New-RegasSession {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]
        $Username,

        [parameter(Mandatory)]
        [Securestring]
        $Password,

        [parameter(Mandatory)]
        [string]
        $WebserviceUrl,

        [parameter(Mandatory)]
        [string]
        $FilePathDLL,

        [parameter(Mandatory)]
        [string]
        $OrganisationCode,

        [parameter()]
        $Proxy
    )
    $script:OrganisationCode = $OrganisationCode
    $script:Credentials.Username = $Username
    $script:Credentials.Password = $Password
    $script:WebserviceUrl = $WebserviceUrl
    if (![string]::IsNullOrEmpty($Proxy)) { $script:Proxy = $Proxy }

    try {
        if (-not [System.IO.File]::Exists($FilePathDLL)) {
            throw "The location of the DLL couldn't be founded: '$FilePathDLL'"
        }
        Add-Type -Path $FilePathDLL

        $binding = New-BindingSettings

        $script:PersonService = New-RegasService -ChannelFactory ([System.ServiceModel.ChannelFactory[Regas.PersonServiceChannel]]::new()) -Bindings $binding -WsdlLocation "$webserviceUrl/PersonService?wsdl"
        $script:GroupService = New-RegasService -ChannelFactory ([System.ServiceModel.ChannelFactory[RegasGroup.GroupServiceChannel]]::new()) -Bindings $binding -WsdlLocation "$webserviceUrl/GroupService?wsdl"
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-RegasPerson {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'PersonID')]
        [int]
        $PersonID,

        [Parameter(ParameterSetName = 'Email')]
        [string]
        $Email
    )
    try {
        #Create Filter
        $filterType = [Regas.findPersonsByFilter]::new()
        $filterType.filter = [Regas.filterType]::new()
        $filterType.filter.persontype = "Employee"

        $maxResultsType = [Regas.maxResultsType]::new()
        $maxResultsType.Value = 1
        $filterType.maxresults = $maxResultsType

        $filterValueType = [Regas.filterValueType]::new()

        if ($PSCmdlet.ParameterSetName -eq 'PersonID') {
            $filterValueType.integerValue = $PersonID
        } elseif ($PSCmdlet.ParameterSetName -eq 'Email') {
            $filterValueType.textValue = $Email
        }

        $filterValuePair = [Regas.filterValuePair]::new()
        $filterValuePair.filterOperation = "eq"
        $filterValuePair.filterValues = [Regas.filterValueType[]]::new(1)
        $filterValuePair.filterValues[0] = $filterValueType

        $answerFilterType = [Regas.answerFilterType]::new()
        $answerFilterType.filterValuePair = [Regas.filterValuePair[]]::new(1)
        $answerFilterType.filterValuePair[0] = $filterValuePair


        if ($PSCmdlet.ParameterSetName -eq 'PersonID') {
            $answerFilterType.ruid = 'id'
            $filterValueType.integerValue = $PersonID
        } elseif ($PSCmdlet.ParameterSetName -eq 'Email') {
            $answerFilterType.ruid = 'email'
        }
        $filterType.filter.answers = [Regas.answerFilterType[]] ($answerFilterType)

        $WebResponsePerson = $script:PersonService.findPersonsByFilter(([Regas.findPersonsByFilter1]::new($script:OrganisationCode, $false, $false, $null, $filterType)))
        if ($null -ne $WebResponsePerson.person ) {
            $person = Format-RegasPerson -PersonObject $WebResponsePerson.person
            Write-Output $person
        }

    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function New-RegasPerson {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        $PersonProperties # Hashtable # PScustomObject
    )
    try {
        #Basic Fields Create Persons
        $person = [Regas.createPerson1]::new()
        $person.createMissingCodes = $true
        $person.organisationCode = $script:OrganisationCode

        $person.createPerson = [Regas.createPerson]::new()
        $person.createPerson.type = 'employee'
        $person.createPerson.typeSpecified = $true

        $answerTypes = ConvertTo-RegasAnswerTypes -Properties $PersonProperties
        if ($answerTypes.count -lt 1) {
            throw 'No Person RegasAnswerTypes are set for creating a new Regas Person'
        }

        $person.createPerson.answers = [Regas.answerType[]]  $answerTypes
        $result = $script:PersonService.createPerson($person)
        Write-Output $result
    } catch {
        throw $_
    }
}

function Update-RegasPerson {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        $PersonId,

        [parameter(Mandatory)]
        $PersonProperties # Hashtable # PScustomObject
    )
    try {
        #Basic Fields Create Persons
        $person = [Regas.editPerson1]::new()
        $person.createMissingCodes = $true
        $person.organisationCode = $script:OrganisationCode

        $person.editPerson = [Regas.editPerson]::new()
        $person.editPerson.personid = $PersonID

        $answerTypes = ConvertTo-RegasAnswerTypes -Properties $PersonProperties
        $person.editPerson.answers = [Regas.answerType[]]  $answerTypes
        $result = $script:PersonService.editPerson($person)

        Write-Output $result
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Set-RegasInviteOrSubscribeUser {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [int]
        $PersonId,

        [string[]]
        $Services,

        [int[]]
        $DynamicButtons
    )
    try {
        $invOrSubRequest = [Regas.inviteOrSubscribeUsers1]::new()
        $invOrSubRequest.organisationCode = $script:OrganisationCode

        $user = [Regas.inviteOrSubscribeUsers]::new()
        $user.personIds = $PersonID
        $user.services = $Services
        $user.dynamicButtons = $DynamicButtons
        $invOrSubRequest.inviteOrSubscribeUsers = $user

        $result = $script:PersonService.inviteOrSubscribeUsers($invOrSubRequest)

        Write-Output $result
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-RegasPersonList {
    [CmdletBinding()]
    param ()
    try {
        $filterType = [Regas.findPersonsByFilter]::new()
        $filterType.filter = [Regas.filterType]::new()
        $filterType.filter.persontype = "employee"

        $take = 20  #Take a value up to 20, otherwise the response will be to large.
        $offset = 0
        $personListRaw = [System.Collections.Generic.List[object]]::new()
        do {
            $maxResultsType = [Regas.maxResultsType]::new()
            $maxResultsType.Value = $take
            $maxResultsType.offset = $offset
            $filterType.maxresults = $maxResultsType

            $partialRaw = $script:PersonService.findPersonsByFilter([Regas.findPersonsByFilter1]::new($script:OrganisationCode, $false, $false, $null, $filterType))
            if ($partialRaw.person.Count -gt 0   ) {
                $personListRaw.AddRange($partialRaw.person)
            }
            $offset = $offset + $take

        }until($partialRaw.person.Count -lt $take )
        Write-Verbose "The PersonList Total: '$($personListRaw.count)'" -Verbose

        $personList = [System.Collections.Generic.List[object]]::new()
        foreach ($personRaw in $personListRaw) {
            $person = Format-RegasPerson -PersonObject $personRaw
            $personList.Add([PSCustomObject]$person)
        }
        Write-Output $personList
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-RegasServiceList {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string[]]
        $PersonIds
    )
    try {
        #Didn't use the wsdl for this request, because it's very complex to add the HttpHeader (Runas) to the request
        [xml]$servicesCurUserRequest = '
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
            <s:Header>
                <h:organisationCode xmlns:h="http://amnis.regas.nl" xmlns="http://amnis.regas.nl">0</h:organisationCode>
            </s:Header>
            <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
                <findWorldServicesByCurrentUser xmlns="http://amnis.regas.nl"/>
            </s:Body>
        </s:Envelope>'
        $servicesCurUserRequest.Envelope.Header.organisationCode."#text" = $script:OrganisationCode

        $Base64Auth = New-BasicBase64 -UserName $script:Credentials.Username -PlainPassword (Convert-SecurePassword $script:Credentials.Password)

        [System.Collections.Generic.List[PSCustomObject]]$worldServices = @()
        foreach ($person in $PersonIds) {
            try {
                $Headers = @{
                    Authorization = $Base64Auth
                    runAs         = $person
                }
                [xml]$responseWSXml = Invoke-RestMethod -Uri "$($script:WebserviceUrl)/PersonService" -Body  $servicesCurUserRequest.InnerXml -Method Post -Headers $Headers  -Proxy:$script:Proxy -ContentType "text/plain"
                $services = $responseWSXml.Envelope.Body.findWorldServicesByCurrentUserResponse.service
                if ($services -eq 0) { continue } # Continue to the next person. This persons does not have services

                foreach ($service in $services) {
                    $serviceObject = [PSCustomObject]@{
                        Code        = $service.code
                        Name        = ($service.name | Where-Object { $_.languagecode -eq "en" })."#text"
                        Url         = $service.url
                        Description = ($service.description | Where-Object { $_.languagecode -eq "en" })."#text"
                    }
                    $worldServices.Add($serviceObject)
                }
            } catch {
                #For some reason the Webreservice returns an InternalServerError if the users does not have services.
                if ($_.exception.response.statuscode -eq 500) { continue } # Continue to the next person. This persons does not have services}

                throw "Could not get services for PersonId $person, message: $($_.Exception.Message)"
            }
        }
        Write-Output ($worldServices | Select-Object  -Unique -Property *)
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-RegasDynamicButtonsList {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string[]]
        $PersonIds
    )
    try {
        [xml]$servicesCurUserRequest = '
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
            <s:Header>
                <h:organisationCode xmlns:h="http://amnis.regas.nl" xmlns="http://amnis.regas.nl">0</h:organisationCode>
            </s:Header>
            <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
                <findDynamicButtonsByCurrentUser xmlns="http://amnis.regas.nl"/>
            </s:Body>
        </s:Envelope>'
        $servicesCurUserRequest.Envelope.Header.organisationCode."#text" = $script:OrganisationCode

        $Base64Auth = New-BasicBase64 -UserName $script:Credentials.Username -PlainPassword (Convert-SecurePassword $script:Credentials.Password)
        [System.Collections.Generic.List[PSObject]]$dynamicButtonsList = @()
        foreach ($personId in $PersonIds) {
            try {
                $Headers = @{
                    Authorization = $Base64Auth
                    runAs         = $personId
                }

                [xml]$responseDButtonsXML = Invoke-RestMethod -Uri "$($script:WebserviceUrl)/PersonService" -Body  $servicesCurUserRequest.InnerXml -Method Post -Headers $Headers  -Proxy:$script:Proxy -ContentType "text/plain"
                $dynamicButtons = $responseDButtonsXML.Envelope.Body.findDynamicButtonsByCurrentUserResponse.dynamicButton
                if ( $dynamicButtons -eq 0 -or $null -eq $dynamicButtons) { continue }

                foreach ($dynamicButton in  $dynamicButtons) {
                    $dynamicButtonObject = [PSCustomObject]@{
                        buttonId         = $dynamicButton.buttonId
                        organisationCode = $dynamicButton.organisationCode
                        parentMenu       = $dynamicButton.parentMenu
                        name             = if ($dynamicButton.name -is [Object[]]) { $dynamicButton.name."#text" | Select-Object -Unique } else { $dynamicButton.name }; ## Fix inconsistency in result from the web service
                        url              = $dynamicButton.url
                        includeTicket    = $dynamicButton.includeTicket
                        orderId          = $dynamicButton.orderId
                    }
                    $dynamicButtonsList.Add($dynamicButtonObject)
                }
            } catch {
                #For some reason the Webreservice returns an InternalServerError if the users does not have Dynamic Buttons.
                if ($_.exception.response.statuscode -eq 500) { continue } # Continue to the next person. This persons does not have dynamic buttons}
                throw "Could not get Dynamic Buttons for PersonId $personId, message: $($_.Exception.Message)"
            }
        }
        Write-Output ( $dynamicButtonsList | Select-Object  -Unique -Property *)
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Disable-RegasPerson {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [int]
        $PersonId
    )
    try {
        $participantIdType = [Regas.participantIdType]::new()
        $participantIdType.Value = $PersonId

        $user = [Regas.detachUsers]::new()
        $user.personIds = [Regas.participantIdType[]] ( $participantIdType)

        $disableRequest = [Regas.detachUsers1]::new()
        $disableRequest.organisationCode = $script:OrganisationCode
        $disableRequest.detachUsers = $user

        $WebResponsePerson = $script:PersonService.detachUsers($disableRequest)

        Write-Output $WebResponsePerson
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Remove-RegasPerson {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [int]
        $PersonId
    )
    try {
        $user = [Regas.deletePerson]::new()
        $user.personid = $PersonId

        $deleteRequest = [Regas.deletePerson1]::new()
        $deleteRequest.organisationCode = $script:OrganisationCode
        $deleteRequest.deletePerson = $user

        $WebResponsePerson = $script:PersonService.deletePerson($deleteRequest)

        Write-Output $WebResponsePerson
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-RegasGroupList {
    [CmdletBinding()]
    param ()
    try {
        $groupsRequest = [RegasGroup.findUserGroupsByFilter1]::new()
        $groupsRequest.organisationCode = $script:OrganisationCode

        $groupsFilter = [RegasGroup.findUserGroupsByFilter]::new()
        $groupsFilter.filter = [RegasGroup.filterType]::new()
        $groupsRequest.findUserGroupsByFilter = $groupsFilter

        $take = 25
        $offset = 0
        $groupListRaw = [System.Collections.Generic.List[object]]::new()
        do {
            $maxResult = [RegasGroup.maxResultsType]::new()
            $maxResult.Value = $take
            $maxResult.offset = $offset
            $groupsFilter.maxresults = $maxResult

            $partialWebResponse = $script:GroupService.findUserGroupsByFilter($groupsRequest)

            if ($partialWebResponse.userGroup.Count -gt 0   ) {
                $groupListRaw.AddRange($partialWebResponse.userGroup)
            }

            $offset = $offset + $take

        }until($partialWebResponse.userGroup.Count -lt $take )


        $groupList = [System.Collections.Generic.List[object]]::new()
        foreach ($groupRaw in  $groupListRaw) {
            $group = [ordered]@{ }
            foreach ($answer in $groupRaw.answers) {
                $answerValue = switch ($answer.ruid) {
                    "systemroles" { $answer.setValue.choiceValue.code }
                    "id" { $answer.integerValue }
                    "description" { $answer.textValue }
                    "name" { $answer.textValue }
                    "fullname" { $answer.textValue }
                    "active" { $answer.activeValue }
                    "members" { $answer.personIds }
                }
                $Group.Add($answer.ruid , $answerValue)
            }
            $groupList.add([pscustomObject]$group)
        }

        $assignmentGroupList = [System.Collections.Generic.List[object]]::new()
        foreach ($groupRow in $groupList) {
            foreach ($member in $groupRow.members) {
                $assignment = [ordered]@{ }
                $assignment.Add("group_id", $GroupRow.id)
                $assignment.Add("person_id", $member.value)
                $null = $assignmentGroupList.add([pscustomObject]$assignment)
            }
        }
        Write-Output @{
            Data = @{
                Groups           = $groupList
                GroupAssignments = $assignmentGroupList
            }
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Set-RegasGroupAssignment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]
        $PersonId,

        [parameter(Mandatory = $true)]
        [string]
        $UserGroupId
    )
    try {
        $participantIdType = New-Object  Regasgroup.participantIdType
        $participantIdType.Value = $PersonId

        $participantIdTypeArray = New-Object Regasgroup.participantIdType[] (1)
        $participantIdTypeArray[0] = $participantIdType

        $assigment = New-Object RegasGroup.subscribeMembers
        $assigment.usergroupid = $userGroupId
        $assigment.personids = $participantIdTypeArray

        $assigmentRequest = New-Object RegasGroup.subscribeMembers1
        $assigmentRequest.organisationCode = $script:OrganisationCode
        $assigmentRequest.subscribeMembers = $assigment

        $result = $script:GroupService.subscribeMembers( $assigmentRequest)
        Write-Output $result
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Revoke-RegasGroupAssignment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]
        $PersonId,

        [parameter(Mandatory = $true)]
        [string]
        $UserGroupId
    )
    try {
        $participantIdType = New-Object  Regasgroup.participantIdType
        $participantIdType.Value = $PersonId

        $participantIdTypeArray = New-Object Regasgroup.participantIdType[] (1)
        $participantIdTypeArray[0] = $participantIdType

        $assigment = New-Object RegasGroup.unSubscribeMembers
        $assigment.usergroupid = $userGroupId
        $assigment.personids = $participantIdTypeArray

        $assigmentRequest = New-Object RegasGroup.unSubscribeMembers1
        $assigmentRequest.organisationCode = $script:OrganisationCode
        $assigmentRequest.unSubscribeMembers = $assigment

        $result = $script:GroupService.unSubscribeMembers( $assigmentRequest )
        Write-Output $result
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}



function Format-RegasPerson {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        $PersonObject
    )
    try {
        $person = [PSCustomObject]@{
            # personId = $PersonObject.personId
            personType = $PersonObject.personType
        }
        foreach ($a in $PersonObject.answers) {
            if ($value) { Clear-Variable value }
            if ($name) { Clear-Variable name }
            $value = switch ($a) {
                { -not [string]::IsNullOrEmpty($_.textValue) } { $_.textValue          ; break }
                { -not [string]::IsNullOrEmpty($_.integerValue) } { $_.integerValue       ; break }
                { -not [string]::IsNullOrEmpty($_.activeValue) } { $_.activeValue        ; break }
                { -not [string]::IsNullOrEmpty($_.personSelectValue) } { $_.personSelectValue  ; break }
                { -not [string]::IsNullOrEmpty($_.setValue.choiceValue) } {
                    [PSCustomObject]@{
                        choiceValue             = $_.setValue.choiceValue
                        organisationSelectValue = $_.setValue.organisationSelectValue
                        personSelectValue       = $_.setValue.personSelectValue
                    }
                    break
                }
                { -not [string]::IsNullOrEmpty($_.personIds.roleId) } {
                    [PSCustomObject]@{
                        roleId = $_.personIds.roleId
                        Value  = $_.personIds.Value

                    }
                    break
                }
                { $_.logicalValue -eq "true" } { $_.logicalValue }
                { -not [string]::IsNullOrEmpty($_.choiceValue.code) -and -not [string]::IsNullOrEmpty($_.logicalValue) } { $_.choiceValue.code  ; break }
                { -not [string]::IsNullOrEmpty($_.choiceValue.id) -and -not [string]::IsNullOrEmpty($_.logicalValue) } {
                    [PSCustomObject]@{
                        id          = $_.choiceValue.id
                        internalId  = $_.choiceValue.internalId
                        description = $_.choiceValue.description
                    }
                    break
                }
                { $_.dateValueSpecified -eq $true } { $_.dateValue ; break }
                { $_.dateTimeValueSpecified -eq $true } { $_.dateTimeValue      ; break }
                { $a.personIds.count -gt 0 } { $_.managers.personIds ; break }
                default {
                    break
                }
            }
            $name = $a.Ruid
            if ([string]::IsNullOrWhiteSpace($a.Ruid)) {
                $name = "questionId_$($a.questionId)"
            }
            $person | Add-Member @{
                $name = $value
            }
        }
        return $person
    } catch {
        throw "Could not Format-RegasPerson, message : $($_.Exception.Message)"
    }
}

#endregion
function Get-ListOfSubArray {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        $ParentList,

        [parameter(Mandatory = $true)]
        [string]
        $SubListPropertyName,

        [parameter(Mandatory = $true)]
        [string]
        $UniqueParentPropertyName
    )
    [System.Collections.Generic.List[object]]$returnList = @()
    try {
        foreach ($listItem in $ParentList) {
            if ($listItem.$SubListPropertyName.count -gt 0) {
                foreach ($mail in $listItem.$SubListPropertyName) {
                    $Object = [ordered]@{
                        $UniqueParentPropertyName = $listItem.$UniqueParentPropertyName
                    }
                    foreach ($prop in $mail.psobject.Properties) {
                        if ($prop.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject") {
                            foreach ($sProp in $prop.value.psobject.Properties ) {
                                $Object.Add("$($prop.Name).$($sProp.name)", $sProp.Value)
                            }
                        } else {
                            $Object.Add($prop.Name , $prop.Value)
                        }

                    }
                    $null = $returnList.Add([PSCustomObject]$Object)
                }
            }
        }
    } catch {
        throw   "Could not Get-ListOfSubArray, message: $($_.Exception.Message)"
    }
    return $returnList
}

<#
.Synopsis
   Sets the Regas Answer Types
.DESCRIPTION
    Sets the Regas Answer Types foreach giver property. Note! that the names in the switch need to match with the input paramterList
    Possible Name:
        FirstName
        Insertion
        Lastname
        Callname
        Initials
        Sexe
        CountryId
        Email
        active
        systemrole
.EXAMPLE
    $answerTypes = ConvertTo-RegasAnswerTypes -Properties $paramaterListHashTable
.EXAMPLE
    $parameterObject = @{
        FirstName   = "TestHash"
        Insertion   = $Insertion
        Lastname    = $Lastname
    }
    $answerTypes = ConvertTo-RegasAnswerTypes -Properties $parameterObject
#>
function ConvertTo-RegasAnswerTypes {
    [CmdletBinding()]
    param(
        [parameter(HelpMessage = 'Example object (Get-Command -Name $MyInvocation.InvocationName).Parameters')]
        $Properties
    )
    try {
        if ($Properties -is [PSCustomObject]) {
            $ParameterList = @{ }
            $Properties.PSObject.Properties | ForEach-Object { $ParameterList[$_.Name] = $_.Value }
        } else {
            $ParameterList = $Properties
        }
        [System.Collections.Generic.List[object]]$answerArray = @()
        foreach ($key in $ParameterList.Keys) {
            $value = $ParameterList.$key
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $answer = [Regas.answerType]::new()
                $answer.ruid = $key.ToLower()
                switch ($key) {
                    'firstname' { $answer.textValue = $value ; break }
                    'insertion' { $answer.textValue = $value ; break }
                    'initials' { $answer.textValue = $value ; break }
                    'lastname' { $answer.textValue = $value ; break }
                    'callname' { $answer.textValue = $value ; break }
                    'email' { $answer.textValue = $value ; break }
                    'active' { $answer.activeValue = $value.ToLower() ; break }
                    'owner' { $answer.personSelectValue = $value ; break }
                    'sexe' {
                        $choiceValue = [Regas.choiceValueType]::new()
                        $choiceValue.code = $value
                        $answer.choiceValue = $choiceValue
                        break
                    }
                    'systemrole' {
                        $choiceValue = [Regas.choiceValueType]::new()
                        $choiceValue.code = $value
                        $answer.choiceValue = $choiceValue
                        break
                    }
                    'countryid' {
                        $answer.ruid = 'country'
                        $answer.choiceValue = [Regas.choiceValueType]::new()
                        $answer.choiceValue.id = $value
                        break
                    }
                    default {
                        Write-Verbose "Parameter '$key' Not Found" -Verbose
                        $answer = $null
                        break
                    }
                }
                if ($answer) {
                    $null = $answerArray.add($answer)
                }

            }
        }
        return $answerArray
    } catch {
        throw "Could not set answerTypes, message: $($_.Exception.message)"
    }
}

function Convert-SecurePassword {
    [CmdletBinding()]
    param(
        [System.Security.SecureString]
        $SecurePassword
    )
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    Write-Output ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)    )
}

function New-BasicBase64 {
    [CmdletBinding()]
    param(
        [string]
        $PlainPassword,

        [string]
        $UserName
    )
    $pair = "$($UserName):$($plainPassword)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    return ("Basic $encodedCreds")
}

function New-RegasService {
    param(
        $ChannelFactory,

        [System.ServiceModel.BasicHttpBinding]
        $Bindings,

        [string]
        $WsdlLocation
    )
    $ChannelFactory.Credentials.UserName.UserName = $script:Credentials.Username
    $ChannelFactory.Credentials.UserName.Password = Convert-SecurePassword ($script:Credentials.Password)
    $ChannelFactory.Endpoint.Address = [System.ServiceModel.EndpointAddress]::new($WsdlLocation)
    $ChannelFactory.Endpoint.Binding = $Bindings
    return $ChannelFactory.CreateChannel()
}

function New-BindingSettings {
    #BindingSettings
    $bindingSettings = [System.ServiceModel.BasicHttpBinding]::new([System.ServiceModel.BasicHttpSecurityMode]::Transport)
    $bindingSettings.Security.Transport.ClientCredentialType = [System.ServiceModel.HttpClientCredentialType]::Basic
    $bindingSettings.Security.Transport.ClientCredentialType = [System.ServiceModel.HttpProxyCredentialType]::Basic
    $bindingSettings.MaxReceivedMessageSize = [int]::MaxValue  # Is needed to get just 15 account each webreqeust

    if ($null -ne $script:Proxy) {
        $bindingSettings.ProxyAddress = [System.Uri]::new($script:Proxy)
        $bindingSettings.UseDefaultWebProxy = $false
    }
    return $bindingSettings
}


function Get-ExceptionMessage {
    [CmdletBinding()]
    Param(
        [parameter(mandatory)]
        $Exception
    )
    $innerExceptionList = @()
    $innerExceptionList += Get-InnerExceptionRecursive -Exception  $Exception.Exception
    if ($Exception.ErrorDetails) {
        $errorExceptionDetails = $Exception.ErrorDetails
    } elseif ($Exception.Exception.Response) {
        $result = $Exception.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $responseReader = $reader.ReadToEnd()
        $reader.Dispose()
    }

    Write-Output @{
        message        = $_.Exception.Message
        InnerException = $innerExceptionList | Select-Object -First 1
        WebError       = "$errorExceptionDetails  $responseReader".Trim(" ")
    }
}


function Get-InnerExceptionRecursive {
    [CmdletBinding()]
    Param(
        [parameter(mandatory)]
        $Exception
    )
    if ($Exception.InnerException) {
        Write-Output $Exception.InnerException.message
        Get-InnerExceptionRecursive -Exception $Exception.InnerException
    }
}