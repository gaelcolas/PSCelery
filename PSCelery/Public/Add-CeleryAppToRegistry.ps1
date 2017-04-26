function Add-CeleryAppToRegistry {
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
        [Parameter(
            Mandatory
            )]
        [CeleryApp]
        $CeleryApp
    )

    begin {
        if (!$script:CeleryAppRegistry) {
            $script:CeleryAppRegistry = @{}
        }
    }

    Process {

        if (!$script:CeleryAppRegistry.ContainsKey($CeleryApp.oid)) {
            $script:CeleryAppRegistry[$CeleryApp.oid] = $CeleryApp
        }
        elseif( $script:CeleryAppRegistry[$CeleryApp.oid] -eq $CeleryApp ) {
            Write-Verbose "Celery App $($CeleryApp.oid) already registered in module registry."
        }
        else {
            throw "App registered with id $($CeleryApp.oid) is not the one provided."
        }

    }

}