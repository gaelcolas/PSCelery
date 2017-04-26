function Get-MultiplicationResult {
    [TaskBinding(Name='Mul')]
    [CmdletBinding()]
    Param(
        $a,
        $b
    )
    return $a*$b
}

function Get-AdditionResult {
    [TaskBinding(Name='Add')]
    [CmdletBinding()]
    Param(
        $a,
        $b
    )
    return $a+$b
}
function test-stuff ($a,$b) {

}

function Wait-AdditionResult {
    [TaskBinding(Name='wait_Add')]
    [CmdletBinding()]
    Param(
        $a,
        $b
    )
    Start-Sleep -Seconds 3

    return (Get-AdditionResult -a $a -b $b)
}

function Get-RemoteCimSession {
    [CmdletBinding()]
    [OutputType([CimSession])]
    Param(
        
        [Parameter(
             Mandatory
            ,Position = 0
        )]
        [string[]]
        $ComputerName,

        [Parameter(
             Mandatory
            ,ParameterSetName='FromPlainText'
            ,Position = 1
        )]
        [string]
        $Username,

        [Parameter(
             Mandatory
            ,ParameterSetName='FromPlainText'
            ,Position = 2
        )]
        [String]
        $Password,

        [Parameter(
             Mandatory
            ,ParameterSetName='FromCreds'
            ,Position = 1
        )]
        [PSCredential]
        $Credential
    )
    if ($PsCmdlet.ParameterSetName -eq 'FromPlainText') {
        $pwd = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $cred = [PSCredential]::new($Username,$Password)
    }
    else {
        $cred = $Credential
    }

    Write-Output (New-CimSession -Credential $cred -ComputerName $ComputerName)
}

function Get-RemoteCimSession {
    [CmdletBinding()]
    [OutputType([CimSession])]
    Param(
        
        [Parameter(
             Mandatory
            ,Position = 0
        )]
        [string[]]
        $ComputerName,

        [Parameter(
             Mandatory
            ,ParameterSetName='FromPlainText'
            ,Position = 1
        )]
        [string]
        $Username,

        [Parameter(
             Mandatory
            ,ParameterSetName='FromPlainText'
            ,Position = 2
        )]
        [String]
        $Password,

        [Parameter(
             Mandatory
            ,ParameterSetName='FromCreds'
            ,Position = 1
        )]
        [PSCredential]
        $Credential
    )
    if ($PsCmdlet.ParameterSetName -eq 'FromPlainText') {
        $pwd = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $cred = [PSCredential]::new($Username,$Password)
    }
    else {
        $cred = $Credential
    }

    Write-Output (New-PSSession -Credential $cred -ComputerName $ComputerName)
}

Function Expand-VMDisks {
    [CmdletBinding()]
    Param(
        [Parameter(
             Mandatory
            ,Position = 0
        )]
        [string] #Careful when doing multiple (disabled now) to check disk size/computer
        $ComputerName,

        [ValidateSet()]
        [ValidateNotNullOrEmpty()]
        $DriveLetter,

        [Parameter(
             Mandatory
            ,Position = 1
        )]
        [string]
        $Username,

        [Parameter(
             Mandatory
            ,Position = 2
        )]
        [string]
        $Password
    )
    
    $CimSession = Get-RemoteCimSession -ComputerName $ComputerName -Username $Username -Password $Password
    $MaxSize = (Get-PartitionSupportedSize -DriveLetter $DriveLetter -CimSession $CimSession).sizeMax
    Resize-Partition -DriveLetter $DriveLetter -CimSession $CimSession -Size $MaxSize

}

Function Stop-WinService {
    Param(
        [Parameter(
             Mandatory
            ,Position = 0
        )]
        [string] #Careful when doing multiple (disabled now) to check disk size/computer
        $ComputerName,

        [Parameter(
             Mandatory
            ,Position = 1
        )]
        [string]
        $Username,

        [Parameter(
             Mandatory
            ,Position = 2
        )]
        [string]
        $Password,

        [Parameter(
            ,Position = 3
        )]
        [string[]]
        $ServiceName = 'MSSQLSERVER'
    )

    foreach ($service in $ServiceName) {
        $cimSession = Get-RemoteCimSession -ComputerName $ComputerName -Username $Username -Password $Password
        $cimInstance= Get-CimInstance -ClassName win32_service -Filter "Name = '$Service'" -CimSession $cimSession
        Invoke-CimMethod -InputObject $cimInstance -MethodName StopService
    }
}


Function Start-WinService {
    Param(
        [Parameter(
             Mandatory
            ,Position = 0
        )]
        [string] #Careful when doing multiple (disabled now) to check disk size/computer
        $ComputerName,

        [Parameter(
             Mandatory
            ,Position = 1
        )]
        [string]
        $Username,

        [Parameter(
             Mandatory
            ,Position = 2
        )]
        [string]
        $Password,

        [Parameter(
            ,Position = 3
        )]
        [string[]]
        $ServiceName = 'MSSQLSERVER'
    )
    
    foreach ($service in $ServiceName) {
        $cimSession = Get-RemoteCimSession -ComputerName $ComputerName -Username $Username -Password $Password
        $cimInstance= Get-CimInstance -ClassName win32_service -Filter "Name = '$Service'" -CimSession $cimSession
        Invoke-CimMethod -InputObject $cimInstance -MethodName StartService
    }
}

Function Restart-WinService {
    [CmdletBinding()]
    Param(
        [Parameter(
             Mandatory
            ,Position = 0
        )]
        [string] #Careful when doing multiple (disabled now) to check disk size/computer
        $ComputerName,

        [Parameter(
             Mandatory
            ,Position = 1
        )]
        [string]
        $Username,

        [Parameter(
             Mandatory
            ,Position = 2
        )]
        [string]
        $Password,

        [Parameter(
            ,Position = 3
        )]
        [string[]]
        $ServiceName = 'MSSQLSERVER'
    )

    Stop-SinService @PSBoundParameters
    Start-WinService @PSBoundParameters

}