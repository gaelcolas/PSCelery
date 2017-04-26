$here = Split-Path -Parent $MyInvocation.MyCommand.Path


$ClassesInOrder = @(
     'CeleryBroker'
    ,'CeleryBackend'
    ,'CeleryAsyncResult'
    ,'TaskBinding'
    ,'CelerySignature'
    ,'CeleryTask'
    ,'RabbitAMQPBroker'
    ,'RabbitRPCBackend'
    ,'CeleryApp'
    #,'CeleryWorker'
)

Write-verbose 'Importing Classes'
foreach ($className in $ClassesInOrder) {
    $ClassPath = "$here\classes\$className.ps1"
    Write-verbose "`tImporting $ClassPath"
    . $ClassPath
}

Write-verbose "Importing Functions"
#Avoid the op_addition error when Public or Private returns 1 file
Get-ChildItem -include *.ps1 -recurse (Join-Path $here Private) | Foreach-Object {
    Try {
            . $_.fullname
    }
    Catch {
        Write-Error "Failed to import function. $_"
    }
}

Get-ChildItem -include *.ps1 -recurse (Join-Path $here Public) | Foreach-Object {
    Try {
            . $_.fullname
            Export-ModuleMember -Function $_.BaseName
    }
    Catch {
        Write-Error "Failed to import function. $_"
    }
}
