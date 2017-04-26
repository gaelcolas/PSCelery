Class CeleryAsyncResult {
    [Ref]$App
    [guid]$task_id
    [PSCustomObject]$Request


    CeleryAsyncResult(
                         [guid]$Task_id
                        ,[ref]$App
                        ,$request
                     )
    {
        $this.task_id = $Task_id
        $this.App = $App
        $this.Request = $request

        <#
        $request = @{
            'id'            = $task_id
            'retries'       = $retries
            'is_eager'      = $True
            'logfile'       = $logfile
            'loglevel'      = $loglevel #or 0
            'hostname'      = $Env:Computername
            'callbacks'     = $link
            'errbacks'      = $link_error
            'headers'       = $headers
            'delivery_info' = @{'is_eager': $True}
        }

        $this.App.value.AsyncResult(task_id, $task_name=$this.name, $kwargs)
        #>

    }

    [Object] Wait()
    {
        return $this.App.Value.Backend.get_result($this.Task_id,$this.request)
    }

    [Object] Get()
    {
        # Attempt to retrieve result,
        # return result if avail, $null (or $this) if not
        return $null
    }



}