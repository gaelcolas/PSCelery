function Test-stuff {
    [CeleryTask(
        Name = 'test_stuff'
    )]
    Param (
        $param1
    )
}


function Restart-SqlService {
    [CeleryTask(
        Name='Restart_SqlService'
    )]
    param (
        $vmip
    )
    invoke-command -ComputerName $vmip -ScriptBlock {Restart-service -Name MSSQLSERVER -Force}
}
#(get-command).ScriptBlock.Attributes.where{$_.'TypeId' -eq [CeleryTask]}

