#Function to Add Query membership   
Function Add-PCXCMCollectionQueryRule {
    Param(
        [string]$CollectionName,
        [string]$QueryExpression,
        [string]$RuleName
    )
Add-CMDeviceCollectionQueryMembershipRule -CollectionName $CollectionName -QueryExpression $QueryExpression -RuleName $RuleName
}
