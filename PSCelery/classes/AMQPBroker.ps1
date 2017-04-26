Class AMQPBroker : CeleryBroker {

    $App

    AMQPBroker() : Base ()
    {
    }

    create_task_message()
    {
    }

    send_task_message()
    {
        #$this.Producer.publish()
    }

    TaskConsumer()
    {
    }
}

