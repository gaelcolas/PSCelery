$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. $here\..\..\..\Public\New-RabbitInterface.ps1
. $here\..\..\..\Public\New-Minion.ps1

#this Test creates an Exchange, and a RabbitInterface
# the Interface is set to reply to PING messages with PONG, 
#  targeted (routed via key) to every queue binded to exchange PINGPONG 
# then waits for a single message on a 

if (!$RabbitMQServer)
{
    $RabbitMQServer = 'localhost'
}
if (!$RabbitMQCredential)
{
    $PlainPassword          = "guest"
    $UserName               = "guest"
    $SecurePassword         = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force
    $RabbitMQCredential = (New-Object System.Management.Automation.PSCredential -ArgumentList $UserName,$SecurePassword)
}

$RMQServer = @{
    'Credential' = $RabbitMQCredential
    'baseuri' = "http://$($RabbitMQServer):15672"
}

$RMQObjectConfiguration = [PSCustomObject]@{
    'exchanges' = @(
        #[PSCustomObject][ordered]@{
        #    'Name' = 'PINGPONG'
        #    'vhost' = '/'
        #    'type' = 'topic' #direct,fanout,headers
        #    'durable' = $true
        #    'AutoDelete' = $false
        #    'internal'=$false
        #}
    )
    'queues' = @(
    )
    'bindings' = @(
    )
}

Describe 'Ensure the RabbitMQ is setup for integration Tests' {
    Import-Module RabbitMQTools,PSRabbitMQ -Force

    Context 'Doing a Ping/Pong interface' {
        $CeleryListenerInterface = [PSCustomObject][ordered]@{
                    'InterfaceName' = 'Celery'
                    'key' = @('celery') #the queuename will be appended if the last char is a . or if empty
                    'exchange' = 'celery'
                    'QueueName' = 'config_data_compilation'
                    'actionfile' = 'C:\src\psMinions\MessageHandlers\Celery.ps1'
                    #'actionScriptBlock' = "ipmo PSRabbitMq; Write-host 'Sending message to PINGPONG: `$_'`
                    #                        Send-RabbitMqMessage -ComputerName $RabbitMQServer -Exchange PINGPONG -Key 'PONG.MULTICAST' -InputObject ('PONG')`
                    #                       "
                    'durable' = $true
                    'RabbitMQCredential' = $RabbitMQCredential
                    'ComputerName' = $RabbitMQServer
                    'IncludeEnvelope' = $true
                } | New-RabbitInterface
        #$CeleryListenerJob = $CeleryListenerInterface.Start()

        $Minion = New-Minion -InterfaceDefinitions @($CeleryListenerInterface) -RequiredModuleName PSRabbitMQ

        #[scriptblock]::create($Minion.MinionWorker).invoke($Minion)

        $Minion.run()
        
        #while ($CeleryListenerJob.State -notin 'failed','running','completed') { Sleep -seconds 1 -Verbose }
        #
        #do {
        #    sleep -Milliseconds 1500
        #    $CeleryListenerJob | Receive-Job
        #}
        #while ($CeleryListenerJob.State -eq 'Running')
        

        

        It -Pending 'The celery job should be completed' {
            $result | Should not beNullOrEmpty
        }

        #$CeleryListenerJob | Remove-job -Force
    }
}
 

