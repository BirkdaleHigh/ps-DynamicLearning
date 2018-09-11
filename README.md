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

# To Do List

* `Update-User` should have test-user split off to remove compare-object output so it can be used to pipe further
* Improve workflow to a solid import -> add -> edit -> export steps to upload to DL, currently we have separate but useful functions
* Create `Export-DLUsers` that consumes `add-dlgroup`
* Create `Import-DLUsers` to consume a CSV into something suitable for `Update-DLusers`
* Finalize `New-DLUser` from reference.ps1 to be called in `update-DLUser` for adding new AD users to Dynamic learning to then have proper group assignment
* `New-DLUser` needs to expose account password for distribution to students.
* `Format-DLForHumans` should accept the same object about to be piped to `Export-DLUsers`
