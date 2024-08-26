
# HelloID-Conn-Prov-Source-Inplanning


| :information_source: Information                                                                                                                                                                                                                                                                                                                                                       |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Source-Inplanning](#HelloID-Conn-Prov-Source-Inplanning)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
    - [Endpoints](#endpoints)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Remarks](#remarks)
      - [Logic in-depth](#logic-in-depth)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-Inplanning_ is a _source_ connector. The purpose of this connector is to import _humanresources_ and their _resourceRoster_. A resourceRoster represents a timetable consisting of days and parts which include work places.

### Endpoints

Currently the following endpoints are being used..

| Endpoint                     |
| ---------------------------- |
| api/token                    |
| api/humanresources           |
| api/roster/resourceRoster    |


- The API documentation can be found at the URLs below. Make sure to replace {customerName} with the customer's name to create a working URL.
>  [Inplanning API documentation Human resources](https://{customerName}.rooster.nl/InPlanningService/openapi/#/default/getHumanResources).
>  [Inplanning API documentation Resource roster](https://{customerName}.rooster.nl/InPlanningService/openapi/#/default/getResourceRoster).

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting    | Description                                                                            | Mandatory |
| ---------- | -------------------------------------------------------------------------------------- | --------- |
| Username     | The Username to connect to the API                                                       | Yes       |
| Password     | The Password to connect to the API                                                       | Yes       |
| BaseUrl    | The URL to the API                                                                     | Yes       |
| HistoricalDays | - The number of days in the past from which the shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __minus__ the number of days specified. | Yes       |
| FutureDays | - The number of days in the future from which the shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __plus__ the number of days specified. | Yes       |

### Remarks

- This is not a complete source connector that creates a person in HelloID with a full dataset of personal data. This is a source connector that creates a small person object with contracts from the shifts in Inplanning. Through aggregation, the Inplanning "person" can be aggregated with the person created by the HR source system. We perform the aggregation based on the externalID.

- We filter out absences to avoid creating contracts and granting permissions in target systems based on shifts that will not take place.

- Diacritical marks do not come through correctly in HelloID when the connector is run on-premises. Therefore, it is preferable not to enable that toggle.
#### Logic in-depth

The purpose of this connector is to import _humanresources_ and their _resourceRoster_. A resource roster consists of days which include parts. each part represents a shift with a start and end time. Each part will result in a contract in HelloID

All workers are imported and then the days will be imported within a specified timeframe, configured by the `HistoricalDays` and `FutureDays` settings in the configuration.

Each _plannedWorker_ typically has multiple shifts (usually one per day, but can be up to three), we selectively import shifts as contracts from within the defined time frame.

Only persons who have active shifts in the timeframe defined by `HistoricalDays` and `FutureDays` will be created in HelloID.

## Getting help

> ℹ️ _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> ℹ️ _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

