#require -Modules PSRabbitMQ
Class RabbitRPCBackend : CeleryBackend {


    RabbitRPCBackend($App) : Base ($App)
    {
        $userInfo = [string]::Empty
        if (!$this.App.Value.Conf.Backend.options['Credential'] -and ($userInfo = $this.App.Value.Conf.Backend.url.userInfo)) {
            $username, $clearTextPassword = $userInfo.split(':')
            if (!$clearTextPassword) {
                $Credential = [System.Management.Automation.PSCredential]::new($username,[securestring]::new())
            }
            else {
                $SecurePassword = ConvertTo-SecureString -AsPlainText -Force -String $clearTextPassword
                $Credential = [System.Management.Automation.PSCredential]::new($username,$SecurePassword)
            }
            $this.App.Value.Conf.Backend.options.add('Credential',$Credential)
        }
    }
    
    #Store result in the Backend system
    [void] store_result(
        $Task_id    = $null,
        $result     = $null,
        $state      = 'SUCCESS',
        $request    = $null
    )
    {
        $routingKey = $request.reply_to

        try {
            $correlationId = [guid]$request.correlation_id
        }
        catch {
            $correlationID = $Task_id
        }

        $Payload = [PSCustomObject]@{
            'result' = $result
            'children' = @()
            'status' = $state
            'task_id' = $Task_id
            'traceback' = $null
        }

        $RMQParams = @{
            InputObject           = $Payload
            Exchange              = $this.App.Value.Conf.Backend.Exchange
            Key                   = $routingKey    #.Replace('-','')
            CorrelationID         = $correlationID
        }

        if ($ComputerName = ([uri]$this.App.Value.Conf.Backend.url).DnsSafeHost) {
            $RMQParams.Add('ComputerName',$ComputerName)
        }
        else {
            $RMQParams.Add('ComputerName','localhost')
        }
        
        #if ($port = ([uri]$this.App.Value.Conf.Backend.url).Port) {
        #    $RMQParams.Add('Port',$port)
        #}

        foreach ($OptionKey in $this.App.Value.Conf.Backend.Options.Keys.Where{$_ -in (Get-Command Send-RabbitMQMessage).Parameters.Keys}) {
            if (!$RMQParams.ContainsKey($OptionKey)) {
                $RMQParams.Add($OptionKey,$this.App.Value.Conf.Backend.Options[$OptionKey])
            }
        }

        Write-Debug "Store_result Parameters:"
        Write-Debug  ($RMQParams | Convertto-json)

        Send-RabbitMqMessage @RMQParams
    }

    
    #Retrieve result from task id and request
    [object] get_result(
                         [guid]$task_id
                        ,$request
                       )
    {
        return $this.get_result($task_id,$request,[timespan]::MaxValue)
    }

    #Retrieve result from task id and request, within an allowed time
    [object] get_result(
                         [guid]$task_id
                        ,$request
                        ,[timespan]$Timeout
                       )
    {
        if($null -eq $Timeout -or [int32]::MaxValue -gt $Timeout.TotalSeconds) {
            $totalSecondsTimeout = [int32]::MaxValue
        }
        else {
            $totalSecondsTimeout = $Timeout.TotalSeconds
        }

        $RMQParams = @{
            Key                 = $task_id.ToString() #.Replace('-','')
            Timeout             = $totalSecondsTimeout # System.Int32                                 
            IncludeEnvelope     = $true # System.Management.Automation.SwitchParameter 
        }

        #Extract Computername from Configuration Backend URL, or default to localhost
        if ($ComputerName = ([uri]$this.App.Value.Conf.Backend.url).DnsSafeHost) {
            $RMQParams.Add('ComputerName',$ComputerName)
        }
        else {
            $RMQParams.Add('ComputerName','localhost')
        }
        
        #Extract port if set in Configuration URL
        if ($port = ([uri]$this.App.Value.Conf.Backend.url).Port) {
            $RMQParams.Add('Port',$port)
        }

        foreach ($OptionKey in $this.App.Value.Conf.Backend.Options.Keys) {
            if (!$RMQParams.ContainsKey($OptionKey)) {
                $RMQParams.Add($OptionKey,$this.App.Value.Conf.Backend.Options[$OptionKey])
            }
        }

        $result = Wait-RabbitMqMessage @RMQParams
        
        return $result.Payload
    }
}