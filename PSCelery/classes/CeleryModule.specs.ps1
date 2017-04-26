#import classes from Module PSRabbitMQ
Using module PSRabbitMQ

#Create the celery (aka App) instance
$app = [CeleryApp]::New(
        @{
            'AppName'='MyApp'
            #chose the broker to use, can include username/password, host, port
            'broker'='amqp://'
            #chose the Backend to keep track of task state and results
            'backend'='amqp://'
            #list of modules to import when worker starts. You need to add the tasks module here
            #so that the worker is able to find our tasks
            'include' = @('Projet.Tasks.ps1')
        }
        )

$app.conf.update(@{
    Result_expires=3600
})



#if($__name__ -eq '__main__') {
    $app.Start()
#}