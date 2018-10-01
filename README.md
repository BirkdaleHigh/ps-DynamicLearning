# Dynamic Learning User Data
This is a set of commands to make the headache of managing Dynamic Learning user accounts easier with regards to class memberships and student details

As an example;

```Powershell
get-adgroup -SearchBase 'OU=Class Groups,OU=...,DC=EXAMPLE' -Filter * |
    where name -match 'cs' |
    where name -NotLike '11*' |
    sort |
    select name |
    Update-DLUser -CSV 'N:\Dynamic Learning Downloaded Users.csv' |
    convertto-csv -NoTypeInformation |
    out-file 'N:\DLWithGroupsSetToUpload.csv'
```

New class-based example
``` powershell
Import-csv 'N:\downloads\Accounts.csv' |
    import-DLUser |
    where {$_.memberof.count -eq 0} |
    foreach {$_.delete().export()} |
    Sort-Object username |
    ConvertTo-Csv -NoTypeInformation |
    out-file AccountsToDelete.csv -Force -Encoding utf8
```

## Add-DLGroup
* Adds an empty group header to the csv
or
* Adds a property of a group name to a user account, can then be piped to a csv

## Format-DLForHumans
Re-write the DL exported CSV with sensible column headers

## Get-DLGroup
Lists all groups found on the imported CSV

## Update-DLUser
Clear the users groups and re-assign "Yes" to their class and year group.

# Using The Class
## Import-DLUser
Creates new account object with a more usable set of property names;

```
Action     :
ID         : 000000
Type       : S
UserName   : StudentAccont
Password   : abcd
Title      :
Firstname  : Fisrtname
Middlename :
Lastname   : Surname
DOB        : 01/01/1970
Sex        :
UPN        : 000007
email      : Student@example.com
memberOf   : {7M5_Cs | Class Teacher, Year 7 | Class Teacher}
```

### Methods
#### Delete
`$user.delete()` sets the Action property to 'D'
#### Export
`$user.export()` export does a number of things to prepare for creating a CSV to import back to Dynamic Learning

1. Re-format all property names to the pattern as desired by their template
1. Append properties of all the possible group memberships in order to negate previous values
1. Update the group memberships to account for the membersOf property

## Export-DLUser
Simply a wrapper to the `.export()` method described above.

# To Do List

* `Update-User` should have test-user split off to remove compare-object output so it can be used to pipe further
* Improve workflow to a solid import -> add -> edit -> export steps to upload to DL, currently we have separate but useful functions
* Create `Export-DLUsers` that consumes `add-dlgroup`
* Create `Import-DLUsers` to consume a CSV into something suitable for `Update-DLusers`
* Finalize `New-DLUser` from reference.ps1 to be called in `update-DLUser` for adding new AD users to Dynamic learning to then have proper group assignment
* `New-DLUser` needs to expose account password for distribution to students.
* `Format-DLForHumans` should accept the same object about to be piped to `Export-DLUsers`

# Class
* DLuser class currently does not support group memberships

Class is planned to be used by import-DLUser to create object from a data source that can be used by export-dluser which creates a CSV.
