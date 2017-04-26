$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Celery = Join-path (split-path (get-package Python3).Source -Parent) 'tools\scripts' 
            $Env:Path += ";$Celery"

Describe 'Module basic functions' {
    It 'imports without error' {
        { Import-module psCelery -ErrorAction SilentlyContinue } | Should not throw
    }
}

$proc = Start-Process celery -WorkingDirectory $here\resources -ArgumentList '-A','celery_worker','worker' -WindowStyle Hidden -PassThru
Describe 'Testing Python calling Celery Worker' {
    if ($RabbitMQServer -ne 'localhost')
    {$skipPythonTests = $true}

    It -Skip:$skipPythonTests 'executing the test_pythonWorker_1.py should return 49' {
        python.exe $here\resources\celery_client\test_pythonWorker_1.py  | Should be 49
    }

    It -Pending 'calling the celery app multiplication from PowerShell should yield the same result' {
        
    }

}
$proc.Kill() | out-null