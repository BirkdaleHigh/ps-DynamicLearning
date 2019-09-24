function Get-MissingUser {
    <#
    .EXAMPLE
        Get-DLMissingUser -CSV 'N:\Dynamic Learning-Users-2018-9-11-144540714.csv' -SearchBase 'OU=Students,...' | New-DLUser | ConvertTo-Csv -NoTypeInformation | Out-File n:\All AD Missing Users.csv

        Create a CSV of users in the AD but not found on dynamic Learning. Upload this CSV then export the users again to create a new user list complete with group coulmn headers.
    #>
    param (
        # Dynamic Learning Users
        [Parameter(Mandatory)]
        [DLUser]$User

        , # AD list of user accounts to check
        [Parameter(Mandatory)]
        [String[]]
        $SearchBase
    )
    Begin {
        $DL = Import-csv $CSV | Select-Object @{Name = 'SamAccountName'; Expression = { $_.'4 - User Name' } }
    }
    Process {
        $SearchBase.forEach({
            get-aduser -Properties emailAddress -Filter {enabled -eq $true} -SearchBase $psitem
        }) |
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
            throw "Version 1 CSV's are no longer supported, Dynamic learning won't import them."
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
            if($PipedObject.'Access to application (Y/N) *' -eq 'Y'){
                $this.Enabled = $true
            } else {
                $this.Enabled = $false
            }

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
            } else {
                Write-Warning "Groups aren't included with this CSV, you should get the version with groups to validate memberships"
            }
            return
        }
    }

    DLUser([Microsoft.ActiveDirectory.Management.ADUser]$PipedObject) {
        $this.Action = 'A'
        $this.Type = 'S'
        $this.UserName = $PipedObject.EmailAddress
        $this.Firstname = $PipedObject.GivenName
        $this.Lastname = $PipedObject.Surname
        $this.Enabled = $true
        $this.dob = '01/01/1970'
    }

    [DLUser] Delete() {
        if($this.Enabled -eq $false){
            $this.Action  = 'D'
            return $this
        }
        Throw "Users must be disabled before they can be deleted, current user is enabled."
    }

    [DLUser] Disable() {
        # Only set and return the object if it has really changed
        if($this.Enabled -eq $true){
            $this.Action  = 'E'
            $this.Enabled = $false
    
            return $this
        }
        return $null
    }
    [DLUser] Enable() {
        # Only set and return the object if it has really changed
        if($this.Enabled -eq $false){
            $this.Action  = 'E'
            $this.Enabled = $true
    
            return $this
        }
        return $null
    }

    [PSCustomObject] Export() {
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
            $base | Add-member -NotePropertyName "Group: $name" -NotePropertyValue "N"
        }
        Foreach ($membership in $this.memberof) {
            $base."Group: $membership" = "Y"
        }
        return $base
    }

    [DLUser] AddGroup([string]$name) {
        $valid_group = $this::Groups.where( { $_.split('|')[0].trim() -eq $name })
        if (-not $valid_group) {
            Throw "Group $name is not found out of $($this::Groups.count) in ::Groups list"
        }
        # TODO: test if name contains | and switch search cases instead of throwing
        if ($valid_group.count -gt 1) {
            Throw "Multiple matches for group($name) as: $valid_group"
        }
        if ($this.action -eq 'D') {
            Write-Warning "User $($this.UserName) was marked to be deleted, changing their group memberships will only edit the user instead"
        }

        if ($this.MemberOf -notcontains $valid_group) {
            # If this list actually needs modifing then set the edit attribute. But not if user is set to be created
            if ($this.action -ne 'A') {
                $this.action = 'E'
            }
            $this.MemberOf.Add($valid_group)
        }

        return $this
    }
    [DLUser] AddGroup([string]$name, [switch]$force) {
        $valid_group = $this::Groups.where( { $_.split('|')[0].trim() -eq $name })
        if (-not $valid_group -and -not $force) {
            Throw "Group $name is not found out of $($this::Groups.count) in ::Groups list"
        }
        # TODO: test if name contains | and switch search cases instead of throwing
        if (-not $valid_group -and $force) {
            $valid_group = $name
            # Put this group into the static list for export to correctly create properties with y/n for a csv.
            $this::Groups.add($name)
        }
        if ($force) {
            Write-Warning "Bypass check validating group name exists from imported users."
        }
        if ($valid_group.count -gt 1) {
            Throw "Multiple matches for group($name) as: $valid_group"
        }
        if ($this.action -eq 'D') {
            Write-Warning "User $($this.UserName) was marked to be deleted, changing their group memberships will only edit the user instead"
        }

        if ($this.MemberOf -notcontains $valid_group) {
            # If this list actually needs modifing then set the edit attribute. But not if user is set to be created
            if ($this.action -ne 'A') {
                $this.action = 'E'
            }
            $this.MemberOf.Add($valid_group)
        }

        return $this
    }

    [DLUser] RemoveGroup([string]$name) {
        if($name -eq '*'){
            if($this.memberOf.count -gt 0){
                $this.Action = 'E'
                $this.memberOf.RemoveRange(0, $this.MemberOf.count)
                return $this
            }
            return $null
        }
        $valid_group = $this::Groups.where( { $psitem -eq $name }, 'Default', 1) # return first group match
        if (-not $valid_group) {
            Write-Warning "Group $name was not found in shared ::Groups list of $($this::Groups.count) items(s)"
        }

        if ($this.MemberOf -contains $valid_group) {
            # If this list actually needs modifing then set the edit attribute.
            $this.action = 'E'
            $this.MemberOf.Remove($valid_group)
            return $this
        }
        # If the user hasn't been modified then do not return the user object.
        return $null
    }
}

function ConvertTo-User {
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
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $User
    )
    process {
        [DLUser]::new($User)
    }
}

function New-User {
    <#
    .SYNOPSIS
        Create a new Dynamic Learning user type
    .DESCRIPTION
        Create new users to import into DL as a csv. Ensure you've used import-dluser from DL in the first place to validate groups that exist on the platform
        To view all groups from the csv read the ::Groups static property or Get-DLGroup.
    .EXAMPLE
        $new_users = get-aduser -Filter {enabled -eq $true} -SearchBase 'OU=...,DC=INTERNAl' -Properties emailaddress | New-DLUser

        Every user from ad has been made into a DLUser type object.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName,ParameterSetName="ActiveDirectory")]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser[]]
        $User
    )
    process {
        foreach ($u in $user) {
            [DLUser]::new($u)
        }
    }
}

function Export-User {
    <#
    .SYNOPSIS
        Transform a user object into properties required for the Dynamic learning CSV
    .DESCRIPTION
        Append a property for every group imported in order to create a full CSV of groups from convertTo-CSV

        equivilent to calling the export methods on the DLUser class object as an entire list
    .EXAMPLE
        $new_users | Export-DLUser

        This is the same as $new_users.export() for the whole list. Individual users can be $new_users[7].export()
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

function Get-Group() {
    <#
    .SYNOPSIS
        Get Dynamic Learning groups
    .DESCRIPTION
        The Dynamic Learning User Export adds a column for each group on the system that the users then have yes/no filled in to assign membership

        Once users have been imported from a CSV from DL, this function lists all the groups DL already has created.
    .EXAMPLE
        PS C:\> Get-DLGroup
        Show all groups already present from Dynamic Learning.

        Year 10 GCSE PE
        Year 9 GCSE PE
        Year 8
        11D_cs1
        11B_cs1
        7M1_Cs
        7M2_Cs
        7M6_Cs
        7SEM_Cs
        7LH_Cs
        8TD_Cs
        8TA_Cs
        ...
    .INPUTS
        DLUser
    .OUTPUTS
        System.String
    .NOTES
        General notes
    #>
    
    [DLUser]::Groups
}

function Update-Group {
    <#
    .SYNOPSIS
        Get the AD Group name matching the DL group and set the members accordingly.
    .DESCRIPTION
        Simply removes all users first, then adds back only the users found in AD, which makes the removed count useless currently.
    .EXAMPLE
        Update-DLGroup -User $all -group '7HF_Cs','7JAC_Cs','7LH_Cs','7GMB_Cs','7CW_Cs'

        Group   Added Removed Total
        -----   ----- ------- -----
        7HF_Cs     27    1196     0
        7JAC_Cs    26    1196     0
        7LH_Cs     28    1196     0
        7GMB_Cs    27    1196     0
        7CW_Cs     26    1196     0
    #>
    [CmdletBinding()]
    param (
        # Imported user list to apply membership
        [Parameter(Mandatory)]
        [DLUser[]]$User,

        # AD group of member list
        [Parameter(Mandatory)]
        [string[]]$group
    )

    Process {
        # compare all the users against username, dropping any email address suffix.
        foreach ($g in $group) {
            $users_in_AD = get-adgroupmember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force

            if ($users_in_AD.count -eq 0) {
                throw "No Users in AD Group to use as a memberlist"
            }

            $users_removed_from_group = $User.RemoveGroup($g)
            $users_addedd_to_group = $users_in_AD.foreach{
                $name = $Psitem.username
                $User.where( { $psitem.username -like "$name*" }, 'Default', 1).AddGroup($g)
            }

            [pscustomObject]@{
                "Group"   = $g
                "Added"   = $users_addedd_to_group.count
                "Removed" = $users_removed_from_group.count
                "Total"   = $Users.where( { $g -in $psitem.memberOf }).count
            }
            # TODO: If users in DL are Yes, check they're in AD, if no set to no
        }
    }
}
