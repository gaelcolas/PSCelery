function Get-CeleryAppFromRegistry {
    <#
      .SYNOPSIS
      Describe the function here
      .DESCRIPTION
      Describe the function in more detail
      .EXAMPLE
      Give an example of how to use it
      .EXAMPLE
      Give another example of how to use it
      .PARAMETER Param1
      The param1
      .PARAMETER param2
      The second param
      #>
    [cmdletBinding()]
    Param(
        [Guid]
        $CeleryAppOid
    )
    
    begin {

        if (!$script:CeleryAppRegistry) {
            $script:CeleryAppRegistry = @{}
        }

    }

    Process {
        
        if($CeleryAppOid -and $script:CeleryAppRegistry.ContainsKey($CeleryAppOid)) {
            Write-Output $script:CeleryAppRegistry[$CeleryAppOid]
        }
        elseif(!$CeleryAppOid) {
            Write-Verbose "No Celery App OID Specified, returning all instances in registry"
            Write-Output $script:CeleryAppRegistry.Values
        }
        else {
            Write-Warning "Could not find Celery App with oid $($CeleryAppOid)"
        }

    }

}