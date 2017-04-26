
Class CeleryWorker : Worker {
    [CeleryApp]$App
    [bool]$send_task_events = $false

    Hidden [System.Management.Automation.PSEventJob] InitHandler_on_message_received()
    {
        return $this.App.broker.start_message_Listener($this.ID, $this)
    }

    CeleryWorker ([hahtable]$Config) : base ()
    {
        $this.App = [CeleryApp]::new($Config)

       $this.on_message_received =  $this.InitHandler_on_message_received()

       if ($this.App.Value.conf.Concurrency) {
            $this.MaxConcurrency = $this.App.Value.conf.Concurrency
            Write-Verbose "Concurrency Set up in Config: $($this.MaxConcurrency)"
        }
        elseif ($cores = (Get-CimInstance win32_processor -ErrorAction SilentlyContinue).NumberOfCores) {
            Write-Verbose "Using the Number of Cores as MaxConcurrency: $cores"
            $this.MaxConcurrency = $cores
        }
        else {
            Write-Verbose "Default Concurrency is 1"
            $this.MaxConcurrency =  1
        }


    }


    #Worker - Job - Event calls Object method.

    <#
    #region http://docs.celeryproject.org/en/latest/userguide/monitoring.html#event-reference

    #task-sent(uuid, name, args, kwargs, retries, eta, expires, queue, exchange, routing_key, root_id, parent_id)

    task_sent()
    {
    }

    #task-received(uuid, name, args, kwargs, retries, eta, hostname, timestamp, root_id, parent_id)

    task_received()
    {
    }

    #task-started(uuid, hostname, timestamp, pid)

    task_started()
    {
    }

    #task-succeeded(uuid, result, runtime, hostname, timestamp)

    task_succeeded()
    {
    }

    #task-failed(uuid, exception, traceback, hostname, timestamp)

    task_failed()
    {
    }

    #task-rejected(uuid, requeued)

    task_rejected()
    {
    }
    
    #task-revoked(uuid, terminated, signum, expired)

    task_revoked()
    {
    }
    
    
    #task-retried(uuid, exception, traceback, hostname, timestamp)

    task_retried() 
    {
    }

    #worker-online(hostname, timestamp, freq, sw_ident, sw_ver, sw_sys)

    woker_online()
    {
    }

    #worker-heartbeat(hostname, timestamp, freq, sw_ident, sw_ver, sw_sys, active, processed)

    woker_heartbeat()
    {
    }
    
    #worker-offline(hostname, timestamp, freq, sw_ident, sw_ver, sw_sys)

    woker_offline()
    {
    }

    #endregion
    #>
}
