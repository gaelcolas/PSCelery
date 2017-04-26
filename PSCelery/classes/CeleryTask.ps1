Class CeleryTask {
    [string]$Name
    [ref]$App
    [TaskBinding]$TaskAttribute = $Null
    [System.Management.Automation.FunctionInfo]$Command
    [char]$NameElementSeparator = '.'

    CeleryTask(
                [System.Management.Automation.CommandInfo]$Command,
                $App
              )
    {
        if ($TaskAttributes = [TaskBinding]$Command.ScriptBlock.Attributes.Where{$_.TypeID -eq [TaskBinding]}[0]) {
            $this.TaskAttribute = $TaskAttributes
        }

        $this.App     = $App
        $this.Command = $Command
        
        
        #Allow a composable override for task name ($prefixes[0].$prefixes[n].$name)
        # or use the default $cmdModule.$cmdModuleVersion.$CmdName
        $NameElements = @()
        $NameElements += switch ($this.TaskAttribute) {
            { $_.prefixes                   }  {  $this.TaskAttribute.prefixes }
            { $_.AddModuleNameToTaskName    }  {  $Command.ModuleName }
            { $_.AddModuleVersionToTaskName }  {  $Command.Version }
            { $_.Name                       }  {  $this.TaskAttribute.Name; break }
            { !$_.Name                      }  {  $Command.Name }
        }

        $this.Name = $NameElements -join $this.NameElementSeparator

    }

    [PSCustomObject] Signature(
                         [object]$taskArgs
                        ,[PSObject]$kwargs
    )
    {
        return $this.Signature(
                         [object]$taskArgs
                        ,[PSObject]$kwargs
                        ,@{}       #[hashtable]$options
                        ,$null     #$subtask_type
                        ,$false    #[bool]$immutable
                        ,0         #[Nullable[int]]$chord_size
        )
    }


    [PSCustomObject] Signature(
                         [object[]]$taskArgs
                        ,[PSObject]$kwargs
                        ,[hashtable]$options
                        ,$subtask_type
                        ,[bool]$immutable
                        ,[Nullable[int]]$chord_size
    )
    {
        $CelerySigParams = @{
            TaskName            = $this.Name
            PositionalArguments = $taskArgs
            NamedArguments      = $kwargs
            Options             = $options
            SubtaskType         = $subtask_type
            Immutable           = $immutable
            ChordSize           = $chord_size
            CeleryApp           = $this.App.Value
        }

        #Add Delay(), Apply_Async()
        
        Return (New-CelerySignature @CelerySigParams)
    }

    [PSCustomObject] Si(
                         [object]$taskArgs
                        ,[PSObject]$kwargs
                        ,[hashtable]$options
                        ,$subtask_type
                        ,[Nullable[int]]$chord_size
                     )
    {
        Return $this.Signature([object]$taskArgs, [PSObject]$kwargs,[hashtable]$options,$subtask_type,$False,[Nullable[int]]$chord_size)
    }

    [Object] Apply ([Nullable[guid]]$task_id, [object[]]$TaskArgs, [PSObject]$kwargs)
    {
        if (!$task_id) { $task_id = [guid]::NewGuid() }

        return $this.Apply( 
                     $TaskArgs
                    ,$kwargs
                    ,[guid]$task_id
                    ,[bool]$true
                    ,$null
                    ,$null
                    ,$null
                    ,$null
        )
    }

    [Object] Apply ( 
                     $TaskArgs
                    ,$kwargs
                    ,[guid]$task_id
                    ,[bool]$throw
                    ,$logfile
                    ,$loglevel
                    ,$options
                    ,$request
    )
    {
        Write-Verbose "Applying $($this.Name) Task locally"

        #set TaskArgs and kwargs to empty collections if $null to allow splatting
        if ( !$TaskArgs ) { $TaskArgs = @() }
        if ( !$kwargs   ) { $kwargs = @{}   }
        if ( !$task_id  ) { $task_id = [Guid]::NewGuid() }
        if ( $null -ne $throw ) { #if Throw not set
            #Use Attribute value if set
            if ($null -ne $this.TaskAttribute.task_eager_propagates) {
                $throw = $this.TaskAttribute.task_eager_propagates
            }
            elseif ($null -ne $this.App.Value.config.tasks.task_eager_propagates) { #use Configuration if set
                $throw = $this.App.Value.config.tasks.task_eager_propagates
            }
            else {
                #or default to true
                $throw = $true
            }
        }

        #execute command & capture Result
        try {
            Write-Debug "Converting kwargs PSObject to Hashtable."
            $kwargsAsHt = $kwargs
            if ( $kwargs -eq @{} -or !($kwargsAsHt = Convert-PSObjectToHashtable -inputObject $kwargs)) { #convert PSObject to Hashtable
                $kwargsAsHt = @{}  #or return empty hashtable for splatting
            }

            Write-Verbose "Attempting to run the command $($this.Command.Name)"
            $Error.Clear()
            $result = &$this.Command @TaskArgs @kwargsAsHt
            Write-Debug 'Command SUCCESS'
            $state = 'SUCCESS'
        }
        catch {
            #TODO: if $retry -gt 0 $_.GetType().ToString() -in $ErrorToRetry, retry
            # elseif ErrBack, call with Task_id
            if ($throw) {
                throw $_
            }
            $result = @{
                            Error          = $_
                            Message        = $_.Exception.Message
                            traceback      = $_.Exception.StackTrace
                            InvocationInfo = $Error[0].InvocationInfo
                            request        = $request
                       }
            $state = 'FAILURE'
        }

        if ($Error.Count -gt 0) {
            Write-Warning "$($Error.Count) error(s) occured while executing this task"
        }

        Write-Debug "The result is $($result|Convertto-json)."

        return @{
                        task_id   = $task_id
                        result    = $result
                        state     = $state
                        traceback = $null
                        request   = $request
                    }|
                    Add-Member -MemberType ScriptMethod -Name get -Value {
                        $this.result
                    } -PassThru -TypeName 'Celery.EagerResult'
        
    }

    [void] delay ([object[]]$TaskArgs)
    {
        #Call $this.Apply_async()+
        $this.apply_async($TaskArgs,@{})
    }

    [Object] apply_async ([object[]]$TaskArgs = @(), [PSObject]$kwargs = @{} )
    {
        return $this.apply_async(
            [object[]]$TaskArgs,
            [PSObject]$kwargs,
            $null,                #$link
            @{}                   #$options
        )
    }

    [Object] apply_async ([object[]]$TaskArgs = @(), [PSObject]$kwargs = @{}, $link = $null, $options = @{})
    {
        Write-Verbose "Creating Signature for task $($this.Name)"
        $MySig = $this.Signature(
                         [object[]]$taskArgs
                        ,[PSObject]$kwargs
                        ,[hashtable]$options
                        ,$null
                        ,$false #immutable
                        ,0      #Chord size
                     )
        #Make the signature finalized by adding task_id and value
        $MySig.finalize()
        Write-Verbose -Message "Sending Signature to App.send_task(`$s)"
        Write-Debug ($MySig | ConvertTo-Json -Depth 4)
        $this.app.Value.send_task($MySig)

        return [CeleryAsyncResult]::new($MySig.options.task_id,$this.App.Value,$MySig)
    }


    <#
    [CelerySignature]signature()
    {
        return [CelerySignature]::new()
    }

    #>
    

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