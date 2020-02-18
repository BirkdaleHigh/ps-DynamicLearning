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
        [ValidateRange({1..30})]
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


# PS Class workflow pseudocode

# getting the users
# all =  import-csv | import-dlUser

# rolling the years
# $all.removegroup yeargroup
# ($all | where username -like 18*).addgroup yeargroup

# get the new users
# $new get-aduser -searchbase intake year -properties emailaddress enabled | new-dluserclass
# $all + $new

# setting the class'
# get-adgroupmember <groupname> + emailaddress |
#     Foreach { $aduser = $psitem.samaccountname;
#     $all.removeGroup(<groupanme>);
#     $all.where($psitem.username -eq $aduser,'Default',1).addgroup(<groupname>) # stop where at first result
# }

# get-history
# 110 $g = '7GMB_Cs'
# 111 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 112 $add = $grp.foreach{...
# 113 $add.count
# 114 $g = '7HF_Cs'
# 115 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 116 $add = $grp.foreach{...
# 117 $g = '7JAC_Cs'
# 118 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 119 $add = $grp.foreach{...
# 120 $g = '7LH_Cs'
# 121 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 122 $add = $grp.foreach{...
# 123 $g = '7SEM_Cs'
# 124 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 125 $add = $grp.foreach{...
# 126 $g = '7SMB_Cs'
# 127 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 128 $add = $grp.foreach{...
# 129 $add.count
# 130 $g = '8TA_Cs'
# 131 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 132 $add = $grp.foreach{...
# 133 $g = '8TB_Cs'
# 134 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 135 $add = $grp.foreach{...
# 136 $g = '8TC_Cs'
# 137 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 138 $add = $grp.foreach{...
# 139 $g = '8TD_Cs'
# 140 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 141 $add = $grp.foreach{...
# 142 $g = '8TE_Cs'
# 143 $grp = Get-ADGroupMember $g | Add-Member -PassThru -MemberType AliasProperty -Name Username -Value SamAccountName -force
# 144 $add = $grp.foreach{...
# 145 $final |sort username| ft username,memberof
# 146 $final |sort username| ft action,username,memberof
# 147 $final | export-dluser | ConvertTo-Csv -NoTypeInformation | Set-Content y78DL.csv


# N:\
# jbennett > $add = $grp.foreach{
# >>                 $name = $Psitem.username
# >>                 $final.where({
# >>                     $psitem.username -like "$name*"},
# >>                     'Default',
# >>                     1
# >>                 ).AddGroup($g)
# >> }