﻿function Update-User{
<#
.EXAMPLE
    Get-ADGroup -SearchBase '<OU Path>' -Filter * |
        where name -like 7*_cs* |
        select name |
        Update-User -csv "..\DL-Users.csv"

    Get a list of all classes from the AD to then update group memberships of
.EXAMPLE
    Update-DLUser -class 9C_Cs2 -CSV 'N:\Downloads\Dynamic Learning-Users.csv'

    Get warned if users have been found in the AD group but are missing from the Dynamic Learning users list.

    <= In ADGroup, => in DLGroup. Missing for: 9C_Cs2

    InputObject SideIndicator
    ----------- -------------
    00SurnameI   <=
.EXAMPLE
    get-adgroup -SearchBase 'OU=Class Groups,...' -Filter * | where name -match 'cs' | where name -NotLike '11*' | sort | select name |Update-DLUser -CSV 'N:\Dynamic Learning-Users-2018-9-11-15756738.csv' | convertto-csv -NoTypeInformation | out-file n:\DLWithGroups.csv

    Do all computer science groups, but not year 11.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=0)]
    [Alias('Name')]
    [string[]]
    $class

    , # Data file
    [Parameter(Mandatory=$true,
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=1)]
    [string]
    $CSV
)
    Begin{
        $c = Import-Csv $csv
    }
    Process{
        forEach($group in $class){
            Write-Verbose "Start to set members for group: $group"
            $adgroup = $group | Get-ADGroupMember | Select-Object -ExpandProperty samaccountname

            $DLGroup = $c | Where-Object '4 - User name' -in $adgroup

            # Check
            $a = ($adgroup | Measure-Object).Count
            $b = ($DLGroup | Measure-Object).Count
            if($a -ne $b){
                Write-Output "<= In ADGroup, => in DLGroup. Missing for: $group"
                Compare-object $adgroup $DLGroup.'4 - User name'
            } else {
                Write-Verbose "Group has $a members in both AD and DL"
            }

            # Mark the use record as edited for re-upload
            $DLGroup | Foreach-Object {
                if($_.'1 - Action' -ne 'A' ){
                    $_.'1 - Action' = 'E'
                } else {
                    Write-Verbose "Not changing Add action to Edit."
                }
            }

            # Add to correct group
            [switch]$script:added = $False
            $DLGroup | Foreach-Object {
                $_.psobject.properties | Foreach-Object {
                    if($_.Name -Like "*$group*"){
                        Write-Verbose "`tFound property: $($_.Name)"
                        Write-Verbose "`tIs like Value: $group"
                        Write-Verbose "`t`tResults in value: $($_.Name -Like "*$group*")"
                        $_.Value = 'Yes'
                        $script:added = $True
                    } elseif ($_.name -Like "* | *") {
                        $_.Value = "No"
                    }
                }
            }
            if(-not $script:added){
                Write-Warning "$group DL Group not found to add membership"
            }

            # Add to correct Year Group
            [switch]$script:correctYear = $False
            $DLGroup | Foreach-Object {
                $intake = [int]$_.'4 - User name'.Substring(0,2)
                # TODO: handle calculating the intake year, this method below might need -1 appending depending on the current year.
                $yeargroup = @('Year 7','Year 8','Year 9','Year 10','Year 11')[(get-date).year - ($intake + 2000)]
                $_.psobject.properties | Foreach-Object {
                    if($_.Name -Like "$yeargroup |*"){
                        $_.Value = 'Yes'
                        $script:correctYear = $True
                    }
                }
            }
            if($script:correctYear -and -not $added){
                Write-Warning "$group DL Group not found to add membership"
            }

            Write-Output $DLGroup
        }
    }
    End{

    }
}

function Format-ForHumans{
    Param(
        # CSV Datasource
        [Parameter(Position=0)]
        $CSV
    )
    Process{
        import-csv $CSV |
            select-Object @(
                @{n='User Name';e={$_.'4 - User Name'}}
                @{n='Password'; e={$_.'5 - Password'}}
                @{n='Name';     e={$_.'7 - First name'}}
                @{n='Surname';  e={$_.'9 - Last Name'}}
            )
    }
}

function Add-Group{
    <#
    .SYNOPSIS
        Add a group to Dynamic Learning
    .DESCRIPTION
        DL Group name pattern is generated by Dynamic Learning as "<Name Chosen> | <User Name>" for the
        account logged on to Dynamic Learning.
        For small numbers of groups it may be best to create on LD first to avoid manual errors.

        This Append another column for the user import to Dynamic Learning which can create groups.
        Alternatively it can add the group as a property to piped members for later export to CSV.
    .NOTES
        This may note work as intended because DL will look for "1 - Action" to be "E" for edit on the user entry in order to set the groups
        If so it needs testing if every user in the CSV needs E to add a "No" group, our only "yes" users.

        May just simply have to do all add/remove groups on DL before editing users.
    #>
    param(
        # AD User to add group property to
        [Parameter(Position=0,
                   ParameterSetName="User",
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        $User

        , # AD User to add group property to
        [Parameter(Position=0,
                   ParameterSetName="Dataset",
                   ValueFromPipeline)]
        $CSV

        , # AD Class name
        [string]
        $Class

        , # DL Group name, pattern is generated by DL as "<Name Chosen> | <User Name>". .
        [string]
        $DLUserName = "MR S Moss"
    )
    Process{
        switch($PSCmdlet.ParameterSetName){
            'User' {
                $User | Add-Member -MemberType NoteProperty -Name "$Class | $DLUserName" -Value 'Yes' -PassThru -force
            }
            'Dataset' {
                $Original = Import-CSV $csv
                $Original | Add-Member -NotePropertyName "$Class | $DLUserName" -NotePropertyValue 'No'
                $Original | convertto-csv -NoTypeInformation | Out-File -Encoding utf8 -FilePath $csv -Force
            }
        }
    }
}

function Get-Group{
    <#
    .SYNOPSIS
        Get Dynamic Learning groups
    .DESCRIPTION
        The Dynamic Learning User Export adds a column for each group on the system that the users then have yes/no filled in to assign membership

        This function lists all the groups DL already has created.
    .EXAMPLE
        PS C:\> Get-DLGroup 'N:\Downloads\Dynamic Learning-Users-.csv'
        Show all groups already present from Dynamic Learning export.

        10B_Cs1 | My User Account
        10D_Cs1 | My User Account
        11A_It1 | My User Account
        11B_cs1 | My User Account
        11B_It1 | My User Account
        11C_It1 | My User Account
        ...
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    Param(
        $Path
    )
    $DLHeaders = @(
        "1 - Action",
        "2 - User ID - do not edit (DL use only)",
        "3 - User type",
        "4 - User name",
        "5 - Password",
        "6 - Title",
        "7 - First name",
        "8 - Middle name",
        "9 - Last name",
        "10 - DOB",
        "11 - Sex",
        "12 - Upn",
        "13 - Email"
    )

    (Get-content $path -TotalCount 1).replace('"','') -split ',' | where {$_ -notin $DLHeaders}
}

function New-User
{
    <#
    .Synopsis
        Create a new DL user from and AD user
    .DESCRIPTION
        Pipe AD users into this to create a DL type user object ready to export as a CSV
        Next you will want to assign group membership
    .EXAMPLE
        Get-DLMissingUser -CSV 'N:\Dynamic Learning-Users.csv' -SearchBase 'OU=Students,...' | New-DLUser | ConvertTo-Csv -NoTypeInformation | Out-File n:\NewY7plusStragglers.csv
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
        [ValidateNotNullOrEmpty()]
        [string]
        $EmailAddress

        , # Used as the UPN field
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
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


function Get-MissingUser {
    <#
    .EXAMPLE
        Get-DLMissingUser -CSV 'N:\Dynamic Learning-Users-2018-9-11-144540714.csv' -SearchBase 'OU=Students,...' | New-DLUser | ConvertTo-Csv -NoTypeInformation | Out-File n:\All AD Missing Users.csv

        Create a CSV of users in the AD but not found on dynamic Learning. Upload this CSV then export the users again to create a new user list complete with group coulmn headers.
    #>
    param (
        # Dynamic Learning  Users CSV
        [Parameter(Mandatory)]
        $CSV

        , # AD list of user accounts to check
        [Parameter(Mandatory)]
        [String]
        $SearchBase
    )
    Begin{
        $DL = Import-csv $CSV | Select-Object @{Name='SamAccountName';Expression= {$_.'4 - User Name'}}
    }
    Process{
        $ad = Get-ADUser -Filter {Enabled -eq $true} -Properties EmployeeNumber,EmailAddress -SearchBase $SearchBase

        Compare-Object $DL $AD -PassThru -Property SamAccountName | Where-Object SideIndicator -eq '=>'
    }
}
