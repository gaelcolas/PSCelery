function Convert-PSObjectToHashtable
{
    [cmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [PSCustomObject]
        $InputObject = @{}
    )

    process
    {
        if ($null -eq $InputObject -or 
            $null -eq $InputObject.PSObject.Properties.name -or
            !(Compare-Object ([PSObject]@{}).PSObject.Properties.Name $InputObject.PSObject.Properties.name)
        ) 
        { return @{} }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { Convert-PSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = Convert-PSObjectToHashtable $property.Value
            }
            
            $hash
        }
        else
        {
            $InputObject
        }
    }
}