#Function to Add Query membership   
Function Add-CMDeviceCollectionQueryMembershipRuleWithQuery {
    Param(
        [string]$CollectionName,
        [string]$QueryExpression,
        [string]$RuleName
    )
Add-CMDeviceCollectionQueryMembershipRule -CollectionName $CollectionName -QueryExpression $QueryExpression -RuleName $RuleName
}
