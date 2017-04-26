#require -Modules PSRabbitMQ
Class RabbitAMQPBroker : CeleryBroker {
    [bool]
    $ShouldDequeue = $false

    [timespan]
    $LoopInterval = [timespan]'0:0:0.500'

    [System.Management.Automation.PSEventJob]
    $AMQP_Handler

    [System.Management.Automation.PSEventJob]
    $ListenerJobStateChangedEventHandler

    #What type? PSJOb?
    $AMQP_Consumer #Job polling RMQ and raising events on Msg received

    [System.Collections.ArrayList]
    $WIP = [System.Collections.ArrayList]::new()

    [int]
    $Concurrency = 1



    RabbitAMQPBroker($App) : base ($App)
    {
        Write-Verbose "RabbitAMQPBroker Constructor"
        $userInfo = $username = $clearTextPassword = [string]::Empty

        if (!$this.App.Value.Conf.broker.options['Credential'] -and ($userInfo = ([uri]$this.App.Value.Conf.Broker.url).userInfo)) {
            $username, $clearTextPassword = $userInfo.split(':')
            if (!$clearTextPassword) {
                $Credential = [System.Management.Automation.PSCredential]::new($username,[securestring]::new())
            }
            else {
                $SecurePassword = ConvertTo-SecureString -AsPlainText -Force -String $clearTextPassword
                $Credential = [System.Management.Automation.PSCredential]::new($username,$SecurePassword)
            }
            $this.App.Value.Conf.broker.options.add('Credential',$Credential)
        }
        
        Write-Verbose "Starting Message Listener"
        $this.start_message_Listener()
    }

    [hashtable] create_task_message(
        [string]$task_id                     = $null,
        [string]$name                        = $null,
        [object[]]$taskArgs                  = $null,
        [PSObject]$kwargs                    = $null
    )
    {
        return $this.create_task_message(
            $task_id,                    #[string]$task_id                     
            $name,                       #[string]$name                        
            $taskArgs,                   #[Object[]]$taskArgs                  
            $kwargs,                     #[hashtable]$kwargs                   
            @{},                         #[hashtable]$kwargsrepr               
            @{},                         #[hashtable]$taskArgsrepr             
            0, #in seconds               #[int]$countdown                      
            $null,                       #[Nullable[datetime]]$eta             
            $true,                       #[bool]$utc                           
            $null,                       #[Nullable[guid]]$group_id            
            $null,                       #$expires                             
            0,                           #[int]$retries                        
            $null,                       #[hashtable]$chord                    
            $null,                       #[hashtable]$Links                    
            $null,                       #[hashtable]$LinksError               
            $null,                       #[string]$reply_to                    
            $null,                       #[Nullable[timespan]]$time_limit      
            $null,                       #[Nullable[timespan]]$soft_time_limit 
            $false,                      #[bool]$SendEvent                     
            $null,                       #[Nullable[guid]]$root_id             
            $null,                       #[Nullable[guid]]$parent_id           
            #$null,                       ##$Shadow                             
            $null                        #$Chain                               
        )
    }

    [hashtable] create_task_message(
        [Nullable[guid]]$task_id                        = $null,
        [string]$name                         = $null,
        [Object[]]$taskArgs                   = $null,
        [PSObject]$kwargs                    = $null,
        [PSObject]$kwargsrepr                = @{},
        [hashtable]$taskArgsrepr              = @{},
        [int]$countdown                       = 0, #in seconds
        [Nullable[datetime]]$eta              = $null,
        [bool]$utc                            = $true,
        [Nullable[guid]]$group_id             = $null,
        [Nullable[datetime]]$expires          = $null,
        [int]$retries                         = 0,
        [hashtable]$chord                     = $null,
        [hashtable]$Links                     = $null,
        [hashtable]$LinksError                = $null,
        [string]$reply_to                     = $null,
        [Nullable[timespan]]$time_limit       = $null,
        [Nullable[timespan]]$soft_time_limit  = $null,
        [bool]$SendEvent                      = $false,
        [Nullable[guid]]$root_id              = $null,
        [Nullable[guid]]$parent_id            = $null,
        #$Shadow                              = $null,
        $Chain                                = $null
    )
    {
        if(!$task_id) {
            $task_id = [Guid]::NewGuid()
        }
        $origin = '{0}@{1}' -f $env:USERNAME,$env:COMPUTERNAME
        $now = [datetime]::Now.ToUniversalTime()
        $nowStr = $now.ToString("yyyy-MM-dd HH:mm:ss:fff")

        if(!$root_id) {
            $root_id = $task_id
        }

        if (!$reply_to) {
            $reply_to = $task_id
        }

        #! Callbacks, Errbacks, chord are signature/dict (hashtable) that needs to have their keys in utf-8
        # https://github.com/celery/celery/blob/master/celery/app/amqp.py#L341

        if (!$SendEvent) {
            $sent_event = $null
        }
        else {
            $sent_event=@{
                    'uuid'= $task_id
                    'root_id'= $root_id
                    'parent_id'= $parent_id
                    'name'= $name
                    'args'= $taskArgsrepr
                    'kwargs'= $kwargsrepr
                    'retries'= $retries
                    'eta'= $eta
                    'expires'= $expires
            }
        }

        if ($this.App.Value.conf.broker.protocol -ne 'v1'){
            return @{ #New Protocol=> Meta in headers
                headers = @{
                    'lang'= 'PS'
                    'task'= $name
                    'id'= [string]$task_id
                    'eta'= $eta
                    'expires'= $expires
                    'group'= $group_id
                    'retries'= $retries
                    'timelimit'= [System.Object[]]@($time_limit, $soft_time_limit)
                    'root_id'= [string]$root_id
                    'parent_id'= [string]$parent_id
                    'argsrepr'= $taskArgsrepr
                    'kwargsrepr'= $kwargsrepr
                    'origin'= $origin
                }
                properties= @{
                    'correlation_id'= $task_id
                    'reply_to'= $reply_to
                }
                body= @(
                        $taskArgs,
                        $kwargs,
                        @{
                            'callbacks'= $Links
                            'errbacks'= $LinksError
                            'chain'= $chain
                            'chord'= $chord
                        }
                )
                sent_event=$sent_event
            }
        }
        else {
            return @{ #old protocol => meta in Body/Payload
                headers = @{}
                properties=@{
                    'correlation_id'= $task_id
                    'reply_to'= $reply_to
                }
                body=@{
                    'callbacks'= $Links
                    'retries'= $retries
                    'task'= $name
                    'utc'= $utc
                    'id'= $task_id
                    'args'= $TaskArgs
                    'kwargs'= $kwargs
                    'group'= $group_id
                    'eta'= $eta
                    'expires'= $expires
                    'errbacks'= $LinksError
                    'timelimit'= @($time_limit, $soft_time_limit)
                    'taskset'= $group_id
                    'chord'= $chord
                }
                sent_event=$sent_event
            }
        }
    }


    [Object] send_task_message($message, [hashtable]$options)
    {
        Write-Debug "Options Set: $($options|convertto-json)"

        #TODO: Have another look at handling options and RMQ parameters
        $RMQParams = @{
            InputObject          = $message.Body
            ReplyTo              = $message.properties.reply_to
            CorrelationID        = $message.properties.correlation_id
        }
        
        #$headers = [hashtable]$message.headers
        if (($headers = [hashtable]$message.headers) -and $message.headers.keys.count -gt 0) {
            $RMQParams.Add('headers',$headers)
        }

        #Add the broker name/ip if present or default to localhost
        if ($ComputerName = ([uri]$this.App.Value.Conf.Broker.url).DnsSafeHost) {
            $RMQParams.Add('ComputerName',$ComputerName)
        }
        else {
            $RMQParams.Add('ComputerName','localhost')
        }

        if ( !($queueName = $Options.queue) -and
             !($queueName = $Options.key) -and
             !($queueName = $options.routing_key)
            )     
        {
            $queueName = $this.app.value.conf.broker.options.queueName
        }
        $RMQParams.Add('key',$queueName)
        
        #if the port is set in the url, add it as param
        if ($port = $this.App.Value.Conf.Broker.url.Port) {
            $RMQParams.Add('Port',$port)
        }

        #Add the Configuration Options
        foreach ($OptionKey in $this.App.Value.Conf.Broker.Options.Keys.where{$_ -in (Get-Command Send-RabbitMqMessage).Parameters.Keys}) {
            if (!$RMQParams.ContainsKey($OptionKey)) {
                $RMQParams.Add($OptionKey,$this.App.Value.Conf.Broker.Options[$OptionKey])
            }
        }

        #Override RMQ configuration with Task specific options
        foreach ($Option in $options.keys.where{$_ -in (Get-Command Send-RabbitMqMessage).Parameters.Keys}) {
            $RMQParams[$Option] = $options[$Option]
        }
        Write-Debug "SEND MESSAGE PARAMS $($RMQParams | ConvertTo-Json -Depth 5)"

        Send-RabbitMqMessage @RMQParams

        return @{'task_id' = $message.task_id} #This should probably be an AsyncResult object
    }

    [object] map_message_to_request ([object]$Message) 
    {
        Write-Verbose "Map_message_to_request"

        if ($Message.headers.task) {
            Write-Debug "Task found in Message Headers: $($Message.headers.task)"
            $MessageMetadata = $Message.headers
            $protocol = 'v2'
            $TaskArgs  = $Message.Payload[0]
            $kwargs    = $Message.Payload[1]
            $callbacks = $Message.Payload[2].callbacks
            $errbacks  = $Message.Payload[2].errbacks
            $chain     = $Message.Payload[2].chain
            $chord     = $Message.Payload[2].chord
        }
        else {
            $MessageMetadata = $Message.Payload
            $protocol = 'v1'
            $callbacks = $Message.Payload.callbacks
            $errbacks  = $Message.Payload.errbacks
            $chain     = $Message.Payload.chain
            $chord     = $Message.Payload.chord
            $TaskArgs  = $Message.Payload.args
            $kwargs    = $Message.Payload.kwargs
        }

        #Extract Request from Message
        $request = $this.App.Value.CreateRequest(
             $MessageMetadata.id            #  $task_id
            ,$MessageMetadata.task          # ,$taskName
            ,$TaskArgs
            ,$kwargs
            ,$MessageMetadata.retries       # ,$retries
            ,$callbacks                     # ,$link
            ,$MessageMetadata               # ,$headers
            ,$chord                         # ,$chord
            ,$chain                         # ,$chain
            ,$message.properties.reply_to   # ,$reply_to
        )
        
        return $request
    }


    start_message_Listener() 
    {
        Write-Verbose "Registering Task Handler"
        $this.AMQP_Handler =  Register-EngineEvent -SourceIdentifier AMQP_Task -Action {
            Param(
                $Message
            )
            Write-Verbose ($Message | ConvertTo-Json)
            (Get-CeleryAppFromRegistry -CeleryAppOid $Message.CeleryAppOid).Broker.on_message_received($Message.Message)

            #"Event: $($event | ConvertTo-json)" | Write-Host
            #"MessageData: $($event.MessageData | ConvertTo-json)" | Write-Host
            #"this: $($this | Convertto-Json)" | Write-host
            ##"Modules: $(Get-Module | FT | Out-String)" | Write-Host
            #"Subscriber $($EVENTSUBSCRIBER | Convertto-Json)" | Write-Host
            #$app | convertto-json | Write-Host
            #$Broker = $event.MessageData
            #$Message = $EventArgs
            #Adding the message being processed
            <#
            $null = $Broker.WIP.Add($Message)
            try {
                #Process the Task
                Write-host "========> MESSAGE RECEIVED"
                $Broker.on_message_received($Message)
            }
            catch {
                Write-Error $_
            }

            #Remove the processed message
            $Broker.WIP.Remove($Message)

            #If the number of message being processed is less than the concurrency, allow dequeue
            if($Broker.WIP.Count -lt $Broker.Concurrency) {
                $Broker.ShouldDequeue = $true
            }
            #>
        }
        

        $ActionData = @{
            LoopInterval = [timespan]$this.LoopInterval
            CeleryAppOid = $this.App.Value.Oid
        }

        $Action = { #PSRabbitMQ is not an Event, but a Pipeline (%) of Delivery
            #ActionData is set in the Parent Scope in Register-RabbitMqEvent
            #This is where to check whether the Message is Task request or Control (different lock/queue)
            
            #While (!$ActionData.Broker.ShouldDequeue) {
            #    #Don't push more until the Worker says he's ok to accept more
            #    Write-Verbose "Waiting for ShouldDequeue to be true"
            #    Start-Sleep -Milliseconds $ActionData.LoopInterval.TotalMilliseconds
            #}
            #Write-Warning "Message Received:`r`n$($Message | Convertto-json)"
            #Block the Dequeuing process until the Worker says it's ok
            #$ActionData.Broker.value.ShouldDequeue = $false

            #Create the Event Forwarder so that the parent thread can receive it
            if (!(Get-EventSubscriber -SourceIdentifier AMQP_Task -ErrorAction SilentlyContinue) ) {
                Register-EngineEvent -SourceIdentifier AMQP_Task -Forward
            }
            #raise an event
            $null = New-Event -SourceIdentifier AMQP_Task -EventArguments @{MESSAGE=$_;CeleryAppOid=$ActionData.CeleryAppOid} -Verbose
        }

        $RMQParams = @{
            IncludeEnvelope = $true
            Action = $Action
            ActionData = $ActionData
        }

        foreach ($optionkey in $this.App.value.Conf.broker.options.keys.Where{$_ -in (Get-Command Register-RabbitMqEvent).Parameters.Keys}) {
            $val = $this.App.value.Conf.broker.options[$optionkey]
            Write-Verbose "Adding $optionkey = $val"
            $RMQParams[$optionkey] = $val
        }

        $this.AMQP_Consumer =  Register-RabbitMqEvent @RMQParams

        $this.ListenerJobStateChangedEventHandler = Register-ObjectEvent -InputObject $this.AMQP_Consumer -EventName StateChanged -Action { Write-Warning $_ }
    }


    on_message_received([object]$Message) {
        $request = $this.map_message_to_request($Message)

        #Use the App dispatcher if not implemented in the broker
        if (!$this.Dispatch_Request) {
            $this.App.Value.Dispatch_request($request)
        }
        else {
            $this.Dispatch_Request($request)
        }
    }

}