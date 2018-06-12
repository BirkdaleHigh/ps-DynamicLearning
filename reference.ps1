<#
.SYNOPSIS
    File kept for referencing when writing future additions
.DESCRIPTION
    Useful notes, ideas, attempts or one-lines used while creating the module.

#>

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

function New-User
{
    <#
    .Synopsis
       Create a new DL user from and AD user
    .DESCRIPTION
       Pipe AD users into this to create a DL type user object ready to export as a CSV
       Next you will want to assign group membership
    #>
    [CmdletBinding()]
    [OutputType([psObject])]
    Param
    (
        # S (for student) or TA (for Teacher)
        [Parameter()]
        [ValidateSet("S", "TA")]
        [string]
        $Type = "S"

        , # User Name
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateLength(6,20)]
        [string]
        $SamAccountName

        , # First Name
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias('First Name', 'Firstname', 'First')]
        [string]
        $GivenName

        , # Surname Name
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string]
        $Surname

        , # Email address
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string]
        $EmailAddress

        , # Used as the UPN field
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string]
        $EmployeeNumber
    )
    Process
    {
        # Create a PS custom object to maintain the property order.
        # Important when piped to ConvertTo-CSV as dynamic learning is specific
        # in its column headers to upload.
        # UPN is just the internal number to identify users accounts
        # however SamAccountName is unique anyway.
        [PSCustomObject] @{
            '1 - Action' = 'A' # A for Add. E for Edit, D for Delete
            '2 - User ID - do not edit (DL use only)' = ''
            '3 - User Type' = $Type
            '4 - User Name' = $SamAccountName
            '5 - Password' = 'pass' + (Get-Random -Minimum 1000 -Maximum 9999)
            '6 - Title' = ''
            '7 - First name' = $GivenName
            '8 - Middle name' = ''
            '9 - Last name' = $Surname
            '10 - DOB' = '01/01/1970'
            '11 - Sex' = ''
            '12 - UPN' = $EmployeeNumber
            '13 - email' = $EmailAddress
        }
    }
}

