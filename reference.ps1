<#
.SYNOPSIS
    File kept for referencing when writing future additions
.DESCRIPTION
    Useful notes, ideas, attempts or one-lines used while creating the module.

#>

# quit right away as this file shouldn't be run
return 


function Get-GroupMember{
    Param(
        # AD group class name or filter pattern
        [string]
        $Class
    )

    $g = get-adgroup -Filter {(name -like '*CS*') -or (name -like '*it*')} -SearchBase 'OU=Class Groups,OU=Student Groups,OU=Security Groups,OU=BHS,DC=BHS,DC=INTERNAL'

    $g | where name -like $class | foreach {
        $group = $psitem.name
        Get-ADGroupMember $group |
            get-aduser |
            select SamAccountName, GivenName, Surname
    }
}
