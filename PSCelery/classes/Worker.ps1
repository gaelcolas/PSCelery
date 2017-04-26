
Class Interface {

    [String]$Name
    [Guid]$id
    [String]$Queue
    [String]$Exchange
    [ScriptBlock]$Action

    [Microsoft.PowerShell.Commands.ModuleSpecification]$MessageBroker
    [hashtable]$BrokerConfiguration
    [Microsoft.PowerShell.Commands.ModuleSpecification]$ResultBackend
    [hashtable]$ResultBackendConfiguration
    [Microsoft.PowerShell.Commands.ModuleSpecification]$TaskModule

    OnMessageReceived()
    {
        
    }

    SendResult()
    {
        
    }

    StartInterface()
    {
    
    }

}

Class CeleryMonitorInterface : Interface {
    
}

Class CeleryTaskHandlerInterface : Interface {
    
}


Class Worker {

    [String]$Name
    [Guid]$ID
    [String]$Status = 'idle'
    [TimeSpan]$TTL = [timespan]'0:0:3' #::MaxValue
    [Interface[]]$Interfaces
    [timeSpan]$LoopInterval
    [bool]$ShouldStop = $false
    [hashtable]$LoopActions
    [hashtable]$StopConditions
    [hashtable]$StopActions
    [hashtable]$InitActions
    [system.diagnostics.stopwatch]$Uptime
    [hashtable]$WorkerData = @{}
    Hidden [System.Management.Automation.PSEventJob]$LoopEventHandler
    Hidden [timers.timer]$LoopTimer
    Hidden [DateTime]$CreatedAt = (Get-Date)
    Hidden [timespan]$MinCleanupDelay
    Hidden [timespan]$LastCleanup


    Hidden [System.Management.Automation.PSEventJob] Init_LoopEventHandler () 
    {
        return (Register-ObjectEvent -InputObject $this.LoopTimer -EventName Elapsed -Action {
            $Worker = $event.MessageData

            foreach ($ActionKey in $Worker.LoopActions.Keys) {
                $Worker.LoopAction($ActionKey)
            }

            if ($StopReasons = $Worker.StopConditions.Keys.Where{$Worker.isStopConditionMet($_)}) {
                foreach ($ActionKey in $Worker.StopActions.Keys) {
                    $Worker.StopAction($ActionKey)
                }
            }
        } -MessageData $this)
    }


    Worker ()
    {
        $this.Name = $this.id = [guid]::NewGuid()
        $this.MinCleanupDelay = [timespan]'0:10:01'
        $this.LoopActions = @{
            Heartbeat = { Write-Verbose "Uptime: $($this.Uptime.Elapsed)" }
            CleanUp   = { 
                if(($this.Uptime.Elapsed-$this.LastCleanup) -gt $this.MinCleanupDelay ) {
                    Write-Verbose "Cleaning Up Object" 
                    $Error.Clear()
                    
                    [System.gc]::Collect()
                    $this.LastCleanup = $this.Uptime.Elapsed
                }
            }
        }

        $this.StopActions = [ordered]@{
            'StopEvent' = {$this.Kill()}
        }
        $this.StopConditions = [ordered]@{
            TTLExpiration   = {$this.Uptime.Elapsed -ge $this.TTL}
            IdleStop        = {$this.ShouldStop -and $this.Status -eq 'idle'}
        }
        $this.Uptime = [system.diagnostics.stopwatch]::StartNew()
        $this.LastCleanup = $this.Uptime.Elapsed
        $this.LoopInterval = [timespan]'0:0:1'
        $this.LoopTimer = [timers.Timer]::new($this.LoopInterval.TotalMilliseconds)
        $this.LoopTimer.AutoReset = $true
        $this.LoopEventHandler = $this.Init_LoopEventHandler()
        $this.LoopTimer.Start()

        foreach ($initActionKey in $this.InitActions.Keys) {
            $this.InitAction($initActionKey)
        }
    }

    [void] SetWorkerData ([string]$Key,$Value) {
        if ($this.WorkerData.ContainsKey($key)) {
            $this.WorkerData[$key] = $Value
        }
        else {
            $this.WorkerData.Add($key,$Value)
        }
    }

    Hidden [void] LoopAction ([string] $ActionKey) {
        Write-Debug "Loop Action $ActionKey"
        &$this.LoopActions[$ActionKey]
    }

    Hidden [bool] isStopConditionMet ([string] $StopConditionKey) {
        $result = &$this.StopConditions[$StopConditionKey]
        Write-Debug "$StopConditionKey = $result"
        return $result
    }

    Hidden [void] StopAction ([string] $ActionKey) {
        Write-Verbose "Stopping Action: $ActionKey"
        &$this.StopActions[$ActionKey]
    }

    Hidden [void] InitAction ([string] $InitActionKey) {
        Write-Verbose "Initializing: $InitActionKey"
        &$this.InitActions[$InitActionKey]
    }


    [void] Kill () {
        Write-Verbose "KILL SIGNAL"
        $this.LoopTimer.Stop()
        $this.Uptime.Stop()
        $this.Interfaces.Clear()
        $this.LoopActions.Clear()
        $this.StopActions.Clear()
        (Get-EventSubscriber).Where{$_.Action.InstanceID -eq $this.LoopEventHandler.InstanceId} | Unregister-Event
        Remove-Job -id ($this.LoopEventHandler.Id) -Force
        [System.GC]::Collect()
    }

}

#$obj = [Worker]::New()
#Start-Sleep -Seconds 10