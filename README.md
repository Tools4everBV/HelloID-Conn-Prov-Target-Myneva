
# HelloID-Conn-Prov-Target-Myneva

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Myneva](#helloid-conn-prov-target-myneva)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
      - [PSModule](#psmodule)
      - [DLL](#dll)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Myneva_ is a _target_ connector. _Myneva_ provides a set of REST API's that allow you to programmatically interact with its data. This connector manages persons in Myneva (previously Regas), including inviting persons with mapped services and dynamic buttons, and managing groups as permissions.

The following lifecycle actions are available:

| Action                                  | Description                                                                                               |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| create.ps1                              | Default PowerShell _create_ lifecycle action                                                              |
| delete.ps1                              | Default PowerShell _delete_ lifecycle action                                                              |
| disable.ps1                             | Detach the user, Update the `LastName` with a prefix and set `active` to false                            |
| enable.ps1                              | Invite the user with the mapped `Dynamic buttons` and `Services`. If required remove prefix from LastName |
| update.ps1                              | DefaultPowerShell _update_ lifecycle action                                                               |
| permissions/groups/grantPermission.ps1  | Default PowerShell _grant_ lifecycle action                                                               |
| permissions/groups/revokePermission.ps1 | Default PowerShell _revoke_ lifecycle action                                                              |
| permissions/groups/permissions.ps1      | DefaultPowerShell _permissions_ lifecycle action                                                          |
| configuration.json                      | Default _configuration.json_                                                                              |
| fieldMapping.json                       | Default _fieldMapping.json_                                                                               |

## Getting started

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Myneva_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value   |
    | ------------------------- | ------- |
    | Enable correlation        | `True`  |
    | Person correlation field  | `n/a`   |
    | Account correlation field | `email` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

> [!IMPORTANT]
> Note, that the field mapping cannot be dynamically expanded because some answer types are specific, requiring additional mapping in the code. This is handled in the module within the function: ConvertTo-RegasAnswerTypes. The supported properties are: 'firstname', 'insertion', 'initials', 'lastname', 'callname', 'email', 'active', 'owner', 'sexe' , 'systemrole', 'countryid'. Additional properties can be added, but this will require changes in the module as well.

### Connection settings

The following settings are required to connect to the API.

| Setting                | Description                                                          | Mandatory |
| ---------------------- | -------------------------------------------------------------------- | --------- |
| UserName               | The UserName to connect to the API                                   | Yes       |
| Password               | The Password to connect to the API                                   | Yes       |
| BaseUrl                | The URL to the API   Example: 'https://ws.regas.nl/regasamnis'       | Yes       |
| OrganizationCode       | The OrganizationCode to connect to the API                           | Yes       |
| PowerShellModulePath * | The path of the Powershell Module, Example: 'C:\install\Myneva.psm1' | Yes       |
| FilePathDLL  *         | The path of the Low level DLL, Example: 'C:\install\Regas.dll'       | Yes       |
 `* Can be found in the asset folder.

### Prerequisites
- [ ] Myneva.psm1 PowerShell module
- [ ] Regas.dll

  The Myneva.psm1 PowerShell module must be installed locally. The module and the dll can be downloaded directly from the Github repository in the asset folder. Make sure you unblock the DLL in Windows.


### Remarks
- A person in Myneva requires an owner. If there is no default owner set within Myneva, you should add an owner during the creation of a new person as an answer type. This is already included in the example field mapping.
- The connector is based on an earlier IAM3 implementation. We used the previous module as a starting point and modified the code to integrate with HelloID. As a result, there are some slight differences in the approach taken in the connector, such as creating a "session."
- The shipped DLL and the function names in the PowerShell module are named Regas instead of Myneva. This name difference exists because the previous name of Myneva was Regas, and the current web service is still called Regas. Since the calls have not been updated to the new name, the Myneva connector also uses the old names.
- The enable action sends a new invite to a user to create an account in Myneva. Within this invite, you can add Dynamic Buttons and Services. These are both statically added in the field mapping, assuming that everyone requires the same services and Dynamic Buttons. In the API it's not mandatory to add Dynamic Buttons and Service within the invite.



#### PSModule
The connector uses a PowerShell module that must be installed locally. Make sure the entire 'assets' folder, that contains the module, is copied to a directory accessible by the HelloId agent.

In the configuration parameters of the target system in HelloId, you must specify the full path to the module definition file (myneva.psm1) and the DLL (Regas.dll), so the HelloId agent can load the module.

#### DLL

The MyNeva PSModule uses an additional *.DLL that includes the WSDL. Reason for this is that certain methods were not available when the WSDL's were loaded directly into PowerShell using the: <New-WebServiceProxy> cmdlet.

*Note* make sure to check that this file is not "blocked" by windows when copying from the internet and "unblock" this file in windows if this is the case.

The easiest way to do this is by using PowerShell from the directory in which the files are downloaded.

```powershell
  Get-ChildItem | Unblock-File
```



## Setup the connector

> _How to setup the connector in HelloID._ Are special settings required. Like the _primary manager_ settings for a source connector.

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5100-helloid-conn-prov-target-myneva).

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

