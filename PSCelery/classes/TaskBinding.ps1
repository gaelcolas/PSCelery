Class TaskBinding : attribute {
    [string]$Name = $null
    [string[]]$prefixes = @()
    [bool]$AddModuleNameToTaskName = $true
    [bool]$AddModuleVersionToTaskName = $false
    [int]$Max_Retries = 0
    [array]$throws
    [float]$Default_Retry_Delay = 180
    [string]$Rate_Limit = 0 # 1/s, 1/m, 1/h: enforce min delay between tasks
    [int]$time_limit = $null
    [int]$soft_time_limit = $null
    [bool]$ignore_result = $false
    [bool]$store_errors_even_if_ignored = $false
    [string]$Serializer = 'json'
    [string]$compression = $null
    $backend
    [bool]$acks_late = $false
    [bool]$track_started = $false

}