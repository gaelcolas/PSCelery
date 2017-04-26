Using Module ..\..\..\PSCelery 

$AppConfig = Import-PowerShellDataFile $PSScriptroot\CeleryConfig.psd1

$App = [CeleryApp]::new($AppConfig)
$App.Start()

$App
