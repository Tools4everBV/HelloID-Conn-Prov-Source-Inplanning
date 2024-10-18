##################################################
# HelloID-Conn-Prov-Source-Inplanning-Persons
#
# Version: 1.1.0
##################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json

function Resolve-InplanningError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }

        try {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
            $errorMessage = (($ErrorObject.ErrorDetails.Message | ConvertFrom-Json)).message
            $httpErrorObj.FriendlyMessage = $errorMessage
        } catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}

try {
    $pair = "$($config.Username):$($config.Password)"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)

    $tokenHeaders = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
        Authorization  = "Basic $base64"
    }

    $splatGetToken = @{
        Uri     = "$($config.BaseUrl)/token"
        Headers = $tokenHeaders
        Method  = 'POST'
        Body    = 'grant_type=client_credentials'
    }

    $accessToken = (Invoke-RestMethod @splatGetToken).access_token

    $headers = @{
        Authorization = "Bearer $($accessToken)"
        Accept        = 'application/json; charset=utf-8'
    }

    $splatGetUsers = @{
        Uri     = "$($config.BaseUrl)/users?limit=0"
        Headers = $headers
        Method  = 'GET'
    }

    $personsWebRequest = Invoke-WebRequest @splatGetUsers
    $personsCorrected = [Text.Encoding]::UTF8.GetString([Text.Encoding]::UTF8.GetBytes($personsWebRequest.content))
    $personObjects = $personsCorrected | ConvertFrom-Json
    $persons = $personObjects | Where-Object active -eq "True"
    $persons = $persons | Sort-Object resource -Unique

    $today = Get-Date
    $startDate = $today.AddDays( - $($config.HistoricalDays)).ToString('yyyy-MM-dd')
    $endDate = $today.AddDays($($config.FutureDays)).ToString('yyyy-MM-dd')

    foreach ($person in $persons) {
        try {
            If(($person.resource.Length -gt 0) -Or ($null -ne $person.resource)){
            
            # Create an empty list that will hold all shifts (contracts)
            $contracts = [System.Collections.Generic.List[object]]::new()

            $splatGetUsersShifts = @{
                Uri     = "$($config.BaseUrl)/roster/resourceRoster?resource=$($person.resource)&startDate=$($startDate)&endDate=$($endDate)"
                Headers = $headers
                Method  = 'GET'
            }

            $personShifts = Invoke-RestMethod @splatGetUsersShifts
                        
            If($personshifts.count -gt 0){
            $counter = 0
            foreach ($day in $personShifts.days) {

                # Removes days when person has vacation
                if ((-not($day.parts.count -eq 0)) -and ($null -eq $day.absence)) {

                    $rosterDate = $day.rosterDate
                    foreach ($part in $day.parts) {
                        $counter = ($counter + 1)
                        # Define the pattern for hh:mm-hh:mm
                        $pattern = '^\d{2}:\d{2}-\d{2}:\d{2}'
                        $time = [regex]::Match($part.shift.uname, $pattern)

                        if ($time.Success) {
                            $times = $time.value -split '-'
                            $startTime = $times[0]
                            $endTime = $times[1]
                        } else {
                            $startTime = '00:00'
                            $endTime = '00:00'
                        }

                        if($part.prop){
                            $functioncode = $part.prop.uname
                            $function = $part.prop.name
                        } else {
                            $functioncode = ""
                            $function = ""                           
                        }

                        $ShiftContract = @{
                            externalId      = "$($person.resource)$($rosterDate)$($time)$($counter)$($part.group.externalId)"
                            labourHist      = $part.labourHist
                            labourHistGroup = $part.labourHistGroup
                            shift           = $part.shift
                            group           = $part.group
                            functioncode    = $functioncode
                            functionname    = $function
                            # Add the same fields as for shift. Otherwise, the HelloID mapping will fail
                            # The value of both the 'startAt' and 'endAt' cannot be null. If empty, HelloID is unable
                            # to determine the start/end date, resulting in the contract marked as 'active'.
                            startAt         = "$($rosterDate)T$($startTime):00Z"
                            endAt           = "$($rosterDate)T$($endTime):00Z"
                        }

                        $contracts.Add($ShiftContract)
                    }
                }
            }

            if ($contracts.Count -gt 0) {
                $personObj = [PSCustomObject]@{
                    ExternalId  = $person.resource
                    DisplayName = "$($person.firstName) $($person.lastName)".Trim(' ')
                    FirstName   = $person.firstName
                    LastName    = $person.lastName
                    Email       = $person.email
                    Contracts   = $contracts
                }
                Write-Output $personObj | ConvertTo-Json -Depth 20
            }}
        }} catch {
            $ex = $PSItem
            if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException')) {
                $errorObj = Resolve-InplanningError -ErrorObject $ex
                Write-Verbose "Could not import Inplanning person [$($person.uname)]. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
                Write-Error "Could not import Inplanning person [$($person.uname)]. Error: $($errorObj.FriendlyMessage)"
            } else {
                Write-Verbose "Could not import Inplanning person [$($person.uname)]. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
                Write-Error "Could not import Inplanning person [$($person.uname)]. Error: $($errorObj.FriendlyMessage)"
            }
        }
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException')) {
        $errorObj = Resolve-InplanningError -ErrorObject $ex
        Write-Verbose "Could not import Inplanning persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import Inplanning persons. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import Inplanning persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Inplanning persons. Error: $($errorObj.FriendlyMessage)"
    }
}