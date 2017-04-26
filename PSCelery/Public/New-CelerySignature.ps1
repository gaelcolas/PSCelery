function New-CelerySignature {
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
    [OutputType('hashtable')]
    Param(
        [parameter(
             Mandatory
            ,ParameterSetName='ByTaskObject'
            ,Position = 0
        )]
        [CeleryTask]
        $Task,

        [parameter(
             Mandatory
            ,ParameterSetName='ByTaskName'
            ,Position = 0
        )]
        [String]
        $TaskName,

        [parameter(
             Mandatory
            ,ParameterSetName='ByTaskSignature'
            ,Position = 0
        )]
        [ValidateScript({(compare-object $_.PSObject.Properties.Name @('task','kwargs','args','options')).SideIndicator -notcontains '=>'})]
        [PSCustomObject]
        $Signature,

        [Alias('TaskArgs','Args')]
        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 1
            )]
        [Object[]]
        $PositionalArguments = @(),

        [Alias('kwargs')]
        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 2
            )]
        [PSObject]
        $NamedArguments = [PSObject]@{},

        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 3
            )]
        [hashtable]
        $Options = @{},

        [Alias('subtask_type')]
        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 4
            )]
        [String]
        $SubtaskType = $null,

        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 5
            )]
        [bool]
        $Immutable= $false,

        [Alias('chord_size')]
        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 6
            )]
        [String]
        $ChordSize = 0,

        [Alias('App')] #Make it mandatory when ByTaskSignature or ByTaskName, as it's detached from the $App
        [Parameter(
             ValueFromPipelineByPropertyName
            ,Position = 7
            )]
        [CeleryApp]
        $CeleryApp = $null

    )

    Process {
        Write-Verbose "Processing New-CelerySignature with ParamSet: $($PSCmdlet.ParameterSetName)"

        switch ($PSCmdlet.ParameterSetName) {
            'ByTaskName'      { $TaskName = $TaskName  }
            'ByTask'          { $TaskName = $Task.Name }
            'ByTaskSignature' { 
                $TaskName = $Signature.task 

                if(!$PSBoundParameters.ContainsKey('ChordSize')) {
                    $ChordSize = $Signature.chord_size
                }

                if(!$PSBoundParameters.ContainsKey('Immutable')) {
                    $Immutable = $Signature.Immutable
                }

                if(!$PositionalArguments) {
                    $PositionalArguments = $Signature.args
                }
                else { #Prepend the Positional Args to the Signature Args if not Immutable
                    if(!$Signature.Immutable -and $PositionalArguments) {
                        $PositionalArguments = $PositionalArguments + $Signature.args
                    }
                }

                if(!$NamedArguments) {
                    $NamedArguments = $Signature.kwargs
                }
                else { #Merge Signature Kwargs with param, with param precendence. if not Immutable
                    #First, transform Signature serialized object into hashtable
                    $TempOptions = @{}
                    foreach ($Option in $Signature.options.PSObject.Properties.Name) {
                        $TempOptions.Add($Option,$Signature.options.($option))
                    }

                    if($Signature.Immutable) { #Signature is Immutable, return Unserialized Signature
                        $Options = $TempOptions
                    }
                    else { #Signature is not immutable, merge with Param options, with Param precedence
                        foreach ($kwargkey in $Options.keys) {
                            $TempOptions[$kwargkey] = $Options[$kwargkey] 
                        }
                        $Options = $TempOptions
                    }
                }

                if(!$SubtaskType) {
                    $SubtaskType = $Signature.subtask_type
                }

                if(!$Options) {
                    $Options = Convert-PSObjectToHashtable -InputObject $Signature.options
                }
                else { #Merge Signature Options with param, giving Param precedence
                    $tempOptions = Convert-PSObjectToHashtable -InputObject $Signature.options
                    foreach ($Optkey in $Options.keys) {
                        $tempOptions[$Optkey] = $Options[$Optkey] 
                    }
                    $options = $tempOptions
                }
            }
        }
        Write-Debug "Creating new Signature"
        $NewSignature = [ordered]@{
            task         = $TaskName
            args         = $PositionalArguments
            kwargs       = $NamedArguments
            options      = $options
            subtask_type = $SubtaskType 
            immutable    = $Immutable
            chord_size   = $ChordSize
        } | 
        Add-Member -MemberType ScriptMethod -Name Finalize -Value {
            Param(
               $id       = [guid]::NewGuid(),
               $group_id = $null,
               $chord    = $null,
               $root_id  = $null,
               $parent_id= $null
            )

            if(!$this.Options['task_id']) {
                $this.options['task_id'] = $id
            }

            foreach ($param in $PSBoundParameters.Keys) {
                switch ($param) {
                    'group_id'  { $this.options['group_id']   = $group_id  }
                    'chord'     { $this.options['chord']      = $chord     }
                    'root_id'   { $this.options['root_id']    = $root_id   }
                    'parent_id' { $this.options['parent_id']  = $parent_id }
                }
            }
        } -PassThru |
        Add-Member -TypeName 'Celery.CallableSignature' -PassThru

        Write-Debug ($NewSignature | convertto-Json)
    #apply_async()
        #$this.App.Send_task()

    #delay()
        #$this.apply_async()
    
        return $NewSignature
    }

}