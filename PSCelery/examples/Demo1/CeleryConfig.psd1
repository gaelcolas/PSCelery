@{
    Name = 'App'
    include = @('C:\src\PSCelery\PSCelery\examples\Demo1\App.psm1')
    LoadTasksOnly = $true
    <#
    ExportedCommands = @(
        'Add'
        'Mul'
        
    )

    #>

    Broker = @{
        url = 'amqp://guest:guest@localhost/'
        Protocol = 'v1'
        options = @{
            SerializeAs = 'application/json'
            Priority = 0
            DeliveryMode = 2
            Depth = 5
            Persistent = $true
            durable = $true
            QueueName = 'celery'
            Exchange = 'celery'
            ExchangeType = 'Direct'
            Key = 'celery'
        }
    }

    Backend = @{
        url = 'rpc://localhost/'
        options = @{
            Exchange = 'celeryresults'
            QueueName = 'celeryresults'
            SerializeAs = 'application/json'
            Priority = 0
            DeliveryMode = 2
            Depth = 5
            Persistent = $true
            Durable = $true
        }
    }

    BackendAliases = @{
        'rpc' = 'PSCelery:RabbitRPCBackend'
    }

    BrokerAliases = @{
        'amqp' = 'PSCelery:RabbitAMQPBroker'
    }

}