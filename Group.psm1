﻿function Update-User {
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
    00SurnameI  <=
.EXAMPLE
    get-adgroup -SearchBase 'OU=Class Groups,...' -Filter * | where name -match 'cs' | where name -NotLike '11*' | sort | select name |Update-DLUser -CSV 'N:\Dynamic Learning-Users-2018-9-11-15756738.csv' | convertto-csv -NoTypeInformation | out-file n:\DLWithGroups.csv

    Do all computer science groups, but not year 11.
.EXAMPLE
    Update-DLUser -Class 7M6_Cs -CSV 'N:\Dynamic Learning-Users.csv' | convertto-csv -NoTypeInformation | out-file n:\DLWithGroups.csv

    Just update the records for the members of 7m6_Cs.
    Exisitng members won't be removed because they are not found by the class selection.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [Alias('Name')]
        [string[]]
        $class

        , # Data file
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]
        $CSV
    )
    Begin {
        $c = Import-Csv $csv
    }
    Process {
        forEach ($group in $class) {
            Write-Verbose "Start to set members for group: $group"
            $adgroup = $group | Get-ADGroupMember | Select-Object -ExpandProperty samaccountname

            $DLGroup = $c | Where-Object '4 - User name' -in $adgroup

            # Check
            $a = ($adgroup | Measure-Object).Count
            $b = ($DLGroup | Measure-Object).Count
            if ($a -ne $b) {
                Write-Output "<= In ADGroup, => in DLGroup. Missing for: $group"
                Compare-object $adgroup $DLGroup.'4 - User name'
            }
            else {
                Write-Verbose "Group has $a members in both AD and DL"
            }

            # Mark the use record as edited for re-upload
            $DLGroup | Foreach-Object {
                if ($_.'1 - Action' -ne 'A' ) {
                    $_.'1 - Action' = 'E'
                }
                else {
                    Write-Verbose "Not changing Add action to Edit."
                }
            }

            # Add to correct group
            [switch]$script:added = $False
            $DLGroup | Foreach-Object {
                $_.psobject.properties | Foreach-Object {
                    if ($_.Name -Like "*$group*") {
                        $_.Value = 'Yes'
                        $script:added = $True
                    }
                    elseif ($_.name -Like "* | *") {
                        $_.Value = "No"
                    }
                }
            }
            if (-not $script:added) {
                Write-Warning "$group DL Group not found to add membership"
            }

            # Add to correct Year Group
            [switch]$script:correctYear = $False
            $DLGroup | Foreach-Object {
                $intake = [int]$_.'4 - User name'.Substring(0, 2)
                # TODO: handle calculating the intake year, this method below might need -1 appending depending on the current year.
                $yeargroup = @('Year 7', 'Year 8', 'Year 9', 'Year 10', 'Year 11')[(get-date).year - ($intake + 2000)]
                $_.psobject.properties | Foreach-Object {
                    if ($_.Name -Like "$yeargroup |*") {
                        $_.Value = 'Yes'
                        $script:correctYear = $True
                    }
                }
            }
            if ($script:correctYear -and -not $added) {
                Write-Warning "$group DL Group not found to add membership"
            }

            Write-Output $DLGroup
        }
    }
    End {

    }
}

function Add-Group {
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
        [Parameter(Position = 0,
            ParameterSetName = "User",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        $User

        , # AD User to add group property to
        [Parameter(Position = 0,
            ParameterSetName = "Dataset",
            ValueFromPipeline)]
        $CSV

        , # AD Class name
        [string]
        $Class

        , # DL Group name, pattern is generated by DL as "<Name Chosen> | <User Name>". .
        [string]
        $DLUserName = "MR S Moss"
    )
    Process {
        switch ($PSCmdlet.ParameterSetName) {
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

function Get-Group {
    <#
    .SYNOPSIS
        Get Dynamic Learning groups from exported file
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

    (Get-content $path -TotalCount 1).replace('"', '') -split ',' | where {$_ -notin $DLHeaders}
}

function New-User {
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
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateLength(6, 20)]
        [string]
        $SamAccountName

        , # First Name
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('First Name', 'Firstname', 'First')]
        [string]
        $GivenName

        , # Surname Name
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]
        $Surname

        , # Email address
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $EmailAddress

        , # Used as the UPN field
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $EmployeeNumber
    )
    Process {
        # Create a PS custom object to maintain the property order.
        # Important when piped to ConvertTo-CSV as dynamic learning is specific
        # in its column headers to upload.
        # UPN is just the internal number to identify users accounts
        # however SamAccountName is unique anyway.
        [PSCustomObject] @{
            '1 - Action'                              = 'A' # A for Add. E for Edit, D for Delete
            '2 - User ID - do not edit (DL use only)' = ''
            '3 - User Type'                           = $Type
            '4 - User Name'                           = $SamAccountName
            '5 - Password'                            = 'pass' + (Get-Random -Minimum 1000 -Maximum 9999)
            '6 - Title'                               = ''
            '7 - First name'                          = $GivenName
            '8 - Middle name'                         = ''
            '9 - Last name'                           = $Surname
            '10 - DOB'                                = '01/01/1970'
            '11 - Sex'                                = ''
            '12 - UPN'                                = $EmployeeNumber
            '13 - email'                              = $EmailAddress
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
    Begin {
        $DL = Import-csv $CSV | Select-Object @{Name = 'SamAccountName'; Expression = {$_.'4 - User Name'}}
    }
    Process {
        $ad = Get-ADUser -Filter {Enabled -eq $true} -Properties EmployeeNumber, EmailAddress -SearchBase $SearchBase

        Compare-Object $DL $AD -PassThru -Property SamAccountName | Where-Object SideIndicator -eq '=>'
    }
}

class DLUser {
    [string]$Action
    [string]$ID
    [string]$Type
    [string]$UserName
    [string]$Password
    [string]$Title
    [string]$Firstname
    [string]$Middlename
    [string]$Lastname
    [string]$DOB
    [string]$Sex
    [string]$UPN
    [string]$Email
    [boolean]$Enabled
    [System.Collections.Generic.List[String]]$MemberOf = [System.Collections.Generic.List[String]]::new()
    static [System.Collections.Generic.List[String]]$Groups = [System.Collections.Generic.List[String]]::new()
    hidden [string] SamAccountName() { return $this.username }


    # Parameterless Constructor
    DLUser () {
        $this.action = 'A' # A for Add. E for Edit, D for Delete
        $this.type = 'S' # S or TA for Student or Teacher
        $this.password = 'pass' + (Get-Random -Minimum 1000 -Maximum 9999)
        $this.dob = '01/01/1970'
    }

    # CSV Imported Object Parameters
    DLUser([PSCustomObject]$PipedObject) {
        # CSV Version 1 headers looks like this
        if ( [bool]($PipedObject.PSobject.Properties.name -match '1 - Action')) {
            $this.Action = $PipedObject.'1 - Action'
            $this.ID = $PipedObject.'2 - User ID - do not edit (DL use only)'
            $this.Type = $PipedObject.'3 - User Type'
            $this.UserName = $PipedObject.'4 - User Name'
            $this.Password = $PipedObject.'5 - Password'
            $this.Title = $PipedObject.'6 - Title'
            $this.Firstname = $PipedObject.'7 - First name'
            $this.Middlename = $PipedObject.'8 - Middle name'
            $this.Lastname = $PipedObject.'9 - Last name'
            $this.DOB = $PipedObject.'10 - DOB'
            $this.Sex = $PipedObject.'11 - Sex'
            $this.UPN = $PipedObject.'12 - UPN'
            $this.email = $PipedObject.'13 - email'

            Foreach ($prop in $PipedObject.psObject.Properties) {
                if ($prop.name -like '* | *') {
                    if (($prop.value -eq "Yes")) {
                        $this.memberOf.add($prop.name)
                    }
                    if (-not ($this::groups -contains $prop.name)) {
                        $this::groups.add($prop.name)
                    }
                }
            }
            return
        }

        # CSV Version 2 Header looks like this
        if ( [bool]($PipedObject.PSobject.Properties.name -match 'Action \*')) {
            $this.Action = $PipedObject.'Action *'
            $this.ID = $PipedObject.'User ID'
            $this.Type = $PipedObject.'Type *'
            $this.UserName = $PipedObject.'Username/Email *'
            $this.Password = $PipedObject.'Password'
            $this.Firstname = $PipedObject.'First name *'
            $this.Middlename = $PipedObject.'Middle name'
            $this.Lastname = $PipedObject.'Last name *'
            $this.Sex = $PipedObject.'Gender'
            $this.UPN = $PipedObject.'UPN'
            $this.Enabled = $PipedObject.'Access to application (Y/N) *'

            # Version 2 from DL may or may not have groups.
            if ( [bool]($PipedObject.PSobject.Properties.name -like 'Group: *')) {
                Foreach ($prop in $PipedObject.psObject.Properties) {
                    if ($prop.name.StartsWith('Group: ')) {
                        $name = $prop.name.replace('Group: ', '')
                        if (($prop.value -eq "Y")) {
                            $this.memberOf.add($name)
                        }
                        if (-not ($this::groups -contains $name)) {
                            $this::groups.add($name)
                        }
                    }
                }
            }
            return
        }

    }

    [DLUser] Delete() {
        $this.action = 'D'

        return $this
    }

    [PSCustomObject] Export() {return $this.Export(2)}
    [PSCustomObject] Export([string]$Version) {
        switch ($Version) {
            "1" {
                $base = [PSCustomObject]@{
                    '1 - Action'                              = $this.Action
                    '2 - User ID - do not edit (DL use only)' = $this.ID
                    '3 - User Type'                           = $this.Type
                    '4 - User Name'                           = $this.UserName
                    '5 - Password'                            = $this.Password
                    '6 - Title'                               = $this.Title
                    '7 - First name'                          = $this.Firstname
                    '8 - Middle name'                         = $this.Middlename
                    '9 - Last name'                           = $this.Lastname
                    '10 - DOB'                                = $this.DOB
                    '11 - Sex'                                = $this.Sex
                    '12 - UPN'                                = $this.UPN
                    '13 - email'                              = $this.email
                }
                # TODO: Group name needs to be restored as "<DL Creator name> | <group name>". A hidden DL_group_map list needs to hold what group name was created by which user to prefix
                Foreach ($name in $this::groups) {
                    Add-member -inputObject $base -NotePropertyName $name -NotePropertyValue "No"
                }
                Foreach ($membership in $this.memberof) {
                    $base.$membership = "Yes"
                }
                return $base
            }
            "2" {
                $base = [PSCustomObject]@{
                    'Action *'         = $this.Action
                    'User ID'          = $this.ID
                    'Type *'           = $this.Type
                    'Username/Email *' = $this.UserName
                    'Password'         = $this.Password
                    'First name *'     = $this.Firstname
                    'Middle name'      = $this.Middlename
                    'Last name *'      = $this.Lastname
                    'Gender'           = $this.Sex
                    'UPN'              = $this.UPN
                }
                if ($this.Enabled) {
                    $access = "Y"
                }
                else {
                    $access = "N"
                }
                $base | Add-member -NotePropertyName 'Access to application (Y/N) *' -NotePropertyValue $access
                Foreach ($name in $this::groups) {
                    $base | Add-member -NotePropertyName $name -NotePropertyValue $Null
                }
                Foreach ($membership in $this.memberof) {
                    $base.$membership = "Y"
                }
                return $base
            }
            Default {
                Throw "You did not specify a valid version to export"
            }
        }
        return [pscustomobject]
    }

    [DLUser] AddGroup([string]$name) {
        $valid_group = $this::Groups.where( { $_.split('|')[0].trim() -eq $name })
        if (-not $valid_group) {
            Throw "Group $name is not found out of $($this::Groups.count) in ::Groups list"
        }
        # TODO: test if name containes | and switch search cases instead of throwing
        if ($valid_group.count -gt 1) {
            Throw "Multiple matches for group($name) as: $valid_group"
        }

        if ($this.MemberOf -notcontains $valid_group) {
            # If this list actually needs modifing then set the edit attribute.
            $this.action = 'E'
            $this.MemberOf.Add($valid_group)
        }

        return $this
    }

    [DLUser] RemoveGroup([string]$name) {
        $valid_group = $this::Groups.where( { $_.split('|')[0].trim() -eq $name })
        if (-not $valid_group) {
            Throw "Group $name is not found out of $($this::Groups.count) in ::Groups list"
        }
        # TODO: test if name containes | and switch search cases instead of throwing
        if ($valid_group.count -gt 1) {
            Throw "Multiple matches for group($name) as: $valid_group"
        }

        if ($this.MemberOf -contains $valid_group) {
            # If this list actually needs modifing then set the edit attribute.
            $this.action = 'E'
            $this.MemberOf.Remove($valid_group)
        }

        return $this
    }
}

function Import-User {
    <#
    .SYNOPSIS
        Convert CSV data into a useful object in to inspect and modify
    .DESCRIPTION
        Imports users from the csv into a custom class whose objects have a nicely formatted memberOf attribute for
        group memberships. To view all groups from the csv read the ::Groups static property.
    .EXAMPLE
        $AllDLUsers = import-csv 'N:\Downloads\Dynamic Learning-Users-2019-1-7-15713797.csv' | Import-DLUser

        Every user from in the CSV exported from dynamic learning has been made into a DLUser type object.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $User
    )
    process {
        if ($PSBoundParameters.User) {
            [DLUser]::new($User)
        }
        else {
            Write-Warning "No input"
        }
    }
}

function Export-User {
    <#
    .SYNOPSIS
        Transform a user object into properties required for the Dynamic learning CSV
    .DESCRIPTION
        Append a property for every group imported in order to create a full CSV of groups from convertTo-CSV
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DLUser[]]$User
    )
    Process {
        $User.export()
    }
}

function Set-GroupMember {
    <#
    .SYNOPSIS
        From an ADgroup apply the class membership field for the DL User.
    .DESCRIPTION
        Acting upon an array of DL User types, for a given ad group check the membership then update the membership record to Yes.
    #>
    [CmdletBinding()]
    param (
        #Imported user list to set memberships on
        [Parameter(Mandatory)]
        [DLUser[]]$User,

        # AD group to search for members in
        [Parameter(Mandatory)]
        [string[]]$group
    )
    Process {
        foreach ($g in $group) {
            $users_in_AD = get-adgroupmember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force

            $users_in_DL = $User | where-object {
                # Where the user lists a DL group starting with the name of the AD Group, removing whitespace.
                # DL Groups are <Group Name> | <Group Creator> for some reason in the csv.
                $psitem.MemberOf.where( { $psitem.split('|')[0].trim().ToLower().StartsWith($g.ToLower()) })
            }

            if ($users_in_DL.count -eq 0) {
                $users_in_DL = @{username = $null}
            }

            $comparison = Compare-Object $users_in_AD $users_in_DL -property username -PassThru

            # Where left side matches AD, add that group to the DL record.
            $added = $comparison | Where-Object SideIndicator -eq '<=' | foreach-Object {
                $dlUser = $User | Where-Object Username -eq $psitem.Username
                $dlUser.AddGroup($g)
            }
            # Users found only in the DL need to be removed.
            $removed = $comparison | Where-Object SideIndicator -eq '=>' | foreach-Object {
                $psitem.RemoveGroup($g)
            }

            [pscustomObject]@{
                "Group"   = $g
                "Added"   = $added.count
                "Removed" = $removed.count
                "Total"   = $users_in_DL.count + ($added.count - $removed.count)
            }
            # TODO: If users in DL are Yes, check they're in AD, if no set to no
            # TODO: Set usernames from AD to yes in DL.
        }
    }
}
