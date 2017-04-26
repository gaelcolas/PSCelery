#
# Module manifest for module 'PSCelery'
#
# Generated by: Gael Colas
#
# Generated on: 25/07/2016
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSCelery.psm1'

# Version number of this module.
ModuleVersion = '0.0.1'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = 'cffede51-bbab-40cb-b643-c4762d0aa0a3'

# Author of this module
Author = 'Gael Colas'

# Company or vendor of this module
CompanyName = 'SynEdgy Limited'

# Copyright statement for this module
Copyright = 'SynEdgy Limited (c) 2017 All rights reserved'

# Description of the functionality provided by this module
Description = 'An attempt to support Python Celery from PowerShell using the JSON protocol and RabbitMQ back-end'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = '5.1'

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('PSRabbitMQ')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @(
     './classes/CeleryBroker.ps1'
    ,'./classes/CeleryBackend.ps1'
    ,'./classes/CeleryAsyncResult.ps1'
    ,'./classes/TaskBinding.ps1'
    ,'./classes/CelerySignature.ps1'
    ,'./classes/CeleryTask.ps1'
    ,'./classes/RabbitAMQPBroker.ps1'
    ,'./classes/RabbitRPCBackend.ps1'
    ,'./classes/CeleryApp.ps1'
    #,'./classes/CeleryWorker.ps1'
)

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = '*'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'RabbitMQ','Celery','IPC'

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

