Class CeleryApp {
    [String]$Name = 'CeleryApp'
    [guid]$oid

    [Bool]$IsStarted = $false
    [CeleryBroker]$broker
    [CeleryBackend]$backend
    [Microsoft.PowerShell.Commands.ModuleSpecification[]]$include
    [hashtable]$conf = @{}
    [hashtable]$TaskRegistry = @{}



    CeleryApp()
    {
        #Find caller script from callstack
        #Look for an App.psm1 or CeleryApp.psm1
        #load default Config from $moduleroot\Examples\demo1\CeleryConfig.psd1
        #replace $this.Conf.Include with the found App
        #init the App
    }


    CeleryApp([hashtable]$Config)
    {
        <#
        Write-Verbose ((Get-PSCallStack)[1] | FL * | Out-String)
        #    Command          : App.ps1
        #    Location         : App.ps1: line 5
        #    Arguments        : {}
        #    ScriptName       : C:\src\PSCelery\PSCelery\examples\Demo1\App.ps1
        #    ScriptLineNumber : 5
        #    InvocationInfo   : System.Management.Automation.InvocationInfo
        #    Position         : $App = [CeleryApp]::new($AppConfig)
        #    FunctionName     : <ScriptBlock>
        #>
        $this.oid = [Guid]::NewGuid()
        $this.conf = $Config

        $this.App_Initialize()
        Add-CeleryAppToRegistry -CeleryApp $this
    }

    Hidden [Void] App_Initialize()
    {
        #Load specified modules, such as Tasks module
        $this.load_modules($this.Conf.include)

        #Load Broker
        if ( $ConfBroker = $this.conf['Broker'] ) {
            if ($ConfBroker.Options) {
                $options = $ConfBroker.options
            }
            else {
                Write-Verbose "No Options to pass to Broker"
                $options = $null
            }
            Write-Verbose "URL = $($confBroker['Url'])"
            $this.ResolveBroker($confBroker['Url'],$options)
        }
        
        #Load Backend if present
        if ( $ConfBackend = $this.conf['Backend'] ) {
            if ($ConfBackend.Options) {
                $options = $ConfBackend.options
            }
            else {
                Write-Verbose "No Options to pass to Backend"
                $options = $null
            }
            Write-Verbose "URL = $($confBackend['Url'])"
            $this.ResolveBackend($confBackend['Url'],$options)
        }

        #Load tasks from imported modules
        $This.Load_tasks()
    }


    ResolveBackend([uri]$Url,[hashtable]$options)
    {
        $FullyQualifiedBackend = $BackendModule = $BackendClass = [string]::Empty

        Write-Verbose "Backend Scheme $($Url.scheme)"
        if ($Url.scheme -in $this.conf.BackendAliases.keys) {
            $FullyQualifiedBackend = $this.conf.BackendAliases[$url.Scheme]
        }
        
        #Override the BackendModule if set in Backend Option
        if ($options.Backend) {
            $FullyQualifiedBackend = $options.Backend
        }
        
        Write-Verbose "Fully Qualified Broker= $FullyQualifiedBackend"
        $BackendModule, $BackendClass = $FullyQualifiedBackend.split(':')
        if ( !($BackendClass -as [type])) {
            Write-Verbose "Importing Class $BackendClass from module $BackendModule"
            [scriptblock]::Create("Using module $BackendModule").Invoke() #is it in diff scope?
        }
        else {
            Write-Verbose "Backend Class $BackendClass already Loaded"
        }

        #Return object in $this.Backend
        $this.backend = New-Object $BackendClass -ArgumentList ($this)

    }


    ResolveBroker([uri]$Url,[hashtable]$options)
    {

        $FullyQualifiedBroker = $BrokerModule = $BrokerClass = [string]::Empty

        if ($Url.scheme -in $this.conf.BrokerAliases.keys) {
            Write-Verbose "Broker Alias = $Url"
            $FullyQualifiedBroker = $this.conf.BrokerAliases[$url.Scheme]
        }
        
        #Override the BrokerModule if set in Broker Option
        if ($options.Broker) {
            $FullyQualifiedBroker = $options.Broker
        }
        
        Write-Verbose "Fully Qualified Broker= $FullyQualifiedBroker"
        $BrokerModule, $BrokerClass = $FullyQualifiedBroker.split(':')
        if ( !($BrokerClass -as [type])) {
            Write-Verbose "Importing Class $BrokerClass from module $BrokerModule"
            [scriptblock]::Create("Using module $BrokerModule").Invoke() #is it in diff scope?
        }
        else {
            Write-Debug "Broker Class $BrokerClass already Loaded"
        }

        #Return object in $this.Broker
        $this.Broker = New-Object $BrokerClass -ArgumentList $this
    }


    load_modules([Microsoft.PowerShell.Commands.ModuleSpecification[]]$Modules)
    {
        foreach ($module in $Modules) {
            Import-Module $module -Force
        }
    }
    

    Load_tasks()
    {
        #Find imported Functions
        $ExportedCommands = [System.Management.Automation.CommandInfo[]](
            $this.conf.include | Foreach-object {
                #Extract only the BaseName if the Module Name is a path (UNC, file win or nix*)
                if ($_ -match '\\|/') {
                    $ModuleName = ($_ -as [io.fileInfo]).basename
                }
                else {
                    $ModuleName = $_
                }
                Write-Verbose "Listing Exported commands for module $ModuleName"
                Get-Command -Module $ModuleName
            }
        )
        Write-Verbose "Exported Command Count: $($ExportedCommands.Count)"
        
        #Filter those with [TaskBinding()] attribute
        if ($this.conf.LoadTasksOnly) { #Will probably throw on non-function such as Cmdlets
            Write-Verbose "Filtering by Functions showing a [TaskBinding()] Attribute in their scriptblock"
            $TaskFunctions = $ExportedCommands.where{$_.ScriptBlock.Attributes.TypeId -eq [TaskBinding]}
        }
        elseif ($this.conf.ExportedCommands) {
            $TaskFunctions = $ExportedCommands.where{$_.Name -in $this.conf.ExportedCommands}
        }
        else {
            $TaskFunctions = $ExportedCommands
        }

        #Create the [CeleryTask] object and add to the Task Registry of this App. 
        #   Also reference this App in the Tasks
        foreach ($TaskCmd in $TaskFunctions) {
            Write-Debug "Creating Celery Task from $($TaskCmd)"
            $Task = [CeleryTask]::new($TaskCmd,$this)
            Write-Verbose "Adding Task $TaskCmd to Task Registry as $($Task.Name)"
            $this.TaskRegistry.Add($Task.Name,$Task)
        }
    }

    
    Start()
    {
        $this.IsStarted = $true
    }
    
    Send_Task($Signature)
    {
        if (!($taskid = $Signature.options.task_id)) {
            $taskid = [Guid]::NewGuid()
        }
        Write-Debug ($Signature.options | convertto-json)
        if ($Signature.Options.GetType() -eq [PSObject]) {
            $options = Convert-PSObjectToHashtable -inputObject ($Signature.options)
        }
        else {
            $options = $Signature.options
        }
        Write-Debug "WITH OPTIONS: $($options | ConvertTo-Json)"

        $Message = $this.broker.create_task_message(
             [string]$taskid
            ,[string]$Signature.task
            ,[Object[]]$Signature.args
            ,[hashtable]$Signature.kwargs
            ,$null #[PSObject]$kwargsrepr
            ,$null #[hashtable]$taskArgsrepr
            ,0 #[int]$countdown 
            ,[Nullable[datetime]]$Signature.eta
            ,$true
            ,[Nullable[guid]]$Signature.group_id
            ,$null #[Nullable[datetime]]$expires
            ,0 #[int]$retries
            ,[hashtable]$Signature.chord
            ,[hashtable]$Signature.Links
            ,[hashtable]$Signature.LinksError
            ,[string]$this.oid
            ,[Nullable[timespan]]$null
            ,[Nullable[timespan]]$null
            ,$false #[bool]$SendEvent
            ,[Nullable[guid]]$null
            ,[Nullable[guid]]$null
            #,$null
            ,$null
        )
        Write-Debug "CREATED MESSAGE: $($Message | ConvertTo-Json -Depth 5)"
        
        $this.broker.send_task_message($Message,$options)
    }

    Send_Task(    #Send task by Name
         $TaskName
        ,[Object[]]$TaskArgs
        ,[PSObject]$kwargs
        ,[Nullable[int]]$countdown
        ,$eta
        ,$taskId
        ,$router
        ,$links
        ,$linksError
        ,$addToParent
        ,$group_id
        ,$retries
        ,$chord
        ,$reply_to
        ,$time_limit
        ,$soft_time_limit
        ,$root_id
        ,$parent_id
        ,$route_name
        #,$shadow
        ,$chain
        ,$task_type
        ,[hashtable]$options
    )
    {
        if(!$taskId) {
            $taskId = [guid]::NewGuid().ToString()
        }

        if(!$reply_to) {
            $reply_to = $this.oid
        }

        $Message = $this.broker.create_task_message(
             [string]$taskid
            ,[string]$TaskName                       
            ,[Object[]]$taskArgs                 
            ,[PSObject]$kwargs                  
            ,$null #[PSObject]$kwargsrepr              
            ,$null #[hashtable]$taskArgsrepr            
            ,0 #[int]$countdown                     
            ,[Nullable[datetime]]$eta            
            ,$true                         
            ,[Nullable[guid]]$group_id           
            ,$null #[Nullable[datetime]]$expires        
            ,0 #[int]$retries                       
            ,[hashtable]$chord                   
            ,[hashtable]$Links                   
            ,[hashtable]$LinksError              
            ,[string]$reply_to                   
            ,[Nullable[timespan]]$time_limit     
            ,[Nullable[timespan]]$soft_time_limit
            ,$false #[bool]$SendEvent
            ,[Nullable[guid]]$root_id            
            ,[Nullable[guid]]$parent_id          
            #,$Shadow                            
            ,$Chain                              
        )

        #Send Task to Broker
        $this.broker.send_task_message(
             $TaskName
            ,$Message
            ,$options
        )
    }

    [hashtable] CreateRequest(
         $task_id
        ,$taskName
        ,$TaskArgs
        ,$kwargs
        ,$retries
        ,$link
        ,$headers
        ,$chord
        ,$chain
        ,$reply_to
    )
    {
        return $this.CreateRequest(
             $task_id
            ,$taskName
            ,$TaskArgs
            ,$kwargs
            ,0
            ,$null
            ,$null
            ,$link
            ,$null
            ,$headers
            ,$null
            ,$null
            ,$null
            ,$chord
            ,$chain
            ,$null
            ,$null
            ,$null
            ,$reply_to
            ,"$env:computername.$env:userdnsdomain"
        )
    }

    [hashtable] CreateRequest(
         $task_id
        ,$taskName
        ,$TaskArgs
        ,$kwargs
        ,$retries
        ,$logfile
        ,$loglevel
        ,$link
        ,$link_error
        ,$headers
        ,$root_id
        ,$parent_id
        ,$group_id
        ,$chord
        ,$chain
        ,$expires
        ,$soft_time_limit
        ,$time_limit
        ,$reply_to
        ,$origin
    )
    {
        "Building Task $taskName Request" | Write-Debug
        $request = @{
                id              = $task_id
                task_name       = $taskName
                taskArgs        = $taskArgs
                kwargs          = $kwargs
                retries         = $retries
                is_eager        = $True
                logfile         = $logfile
                loglevel        = $loglevel
                hostname        = "$env:computername.$env:userdnsdomain"
                callbacks       = $link
                errbacks        = $link_error
                headers         = $headers
                delivery_info   = @{'is_eager'=$True}

                root_id         = $root_id
                parent_id       = $parent_id
                group_id        = $group_id
                chord           = $chord
                chain           = $chain
                expires         = $expires
                soft_time_limit = $soft_time_limit
                time_limit      = $time_limit
                reply_to        = $reply_to
                origin          = $origin
            }

        return $request
    }


    Dispatch_Request($Request)
    {
        if ( !($taskObject = $this.TaskRegistry.($Request.task_name)) ) { #if the requested task is not registered
            Write-Warning "$($Request.task_name) is not found in Task registry"
            return #could be wise to re-post the message if an option is avail?
        }
        Write-Debug "Request ID: $($request.id)"
        Write-Debug "TaskArgs  : @($($request.taskArgs -join ', '))"
        Write-Debug "kwargs    : $($request.kwargs | convertto-json -compress)"

        $result = $taskObject.Apply([guid]$request.id, [object[]]$request.taskArgs, $request.kwargs)

        #TODO: if $_.GetType().ToString() -in $ErrorToRetry, retry
        if( $result.state -eq 'SUCCESS' -and $Request.callbacks ) {
            
            foreach ($callback in $Request.callbacks) {
                Write-Debug "CALLBACK: $($callback|Convertto-json)"
                Write-Debug ($callback.PSObject.Properties.Name -join ', ')
                $NewSig = New-CelerySignature -Signature $callback -PositionalArguments @($result.result) -CeleryApp $this
                $null = $this.Send_Task($NewSig)
            }
        }  #TODO: Add support for Chain/Groups
        elseif ( #If there's a result, a backend, and we should not ignore result, store it.
                 $result.result -and 
                 $this.conf.backend -and
                 !$this.TaskAttribute.ignore_result -and
                 !$request.options.ignore_result
               )
        {
            Write-Debug "Sending $($request.id) to Store Result via $($request.reply_to): $($result.result)"
            $this.Backend.store_result(
                  $request.id    #Task_id
                 ,$result.result #result 
                 ,$result.State  #state  
                 ,$request       #request
            )
        }
        else {
            Write-Warning "Task executed but no post-processing requested"
            $out = [string]::Empty
            switch ($result.GetType().Name) {
                'PSCustomObject' { $out = $result | ConvertTo-Json -Depth 5; break}
                default          { $out = $result.toString(); break }
            }
            Write-verbose "Result:`r`n$($out)"
        }
    }
}

# Celery App:
#  Load included modules
#  Initialize App
#  Instantiate Tasks, create task registry
#  