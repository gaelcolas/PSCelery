Class CeleryBackend {
    [ref]$App
    [hashtable]$Conf = @{
        Backend = @{}
    }

    [bool]$Persistent = $true

    [hashtable]$ReadyStates = @{}
    [hashtable]$UnreadyStates = @{}
    [hashtable]$ExceptionStates = @{}
    
    [hashtable]$Retry_Policy = @{
        'max_retries'    = 20
        'interval_start' = 0
        'interval_step'  = 1
        'interval_max'   = 1
    }

    CeleryBackend($App)
    {
        if ($this.GetType() -eq [CeleryBackend])
        {
            throw("The CeleryBackend Class must be inherited")
        }
        
        $this.App = $App
        if ($this.App.Conf.Backend) {
            $this.Conf['Backend'] = $this.App.Conf.Backend
        }

    }

    store_result()
    {
        throw "This method needs to be implemented"
    }

    [object] get_result(
                         [guid]$task_id
                        ,$request
                       )
    {
        throw "This method needs to be implemented"
    }

    <#
    wait_for() {}
    get() {}
    as_uri([bool]$includePassword = $false) {}
    #>

}