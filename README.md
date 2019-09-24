# Dynamic Learning User Data
This is a set of commands to make the headache of managing Hodder Education's "Dynamic Learning" platform user accounts easier with regards to class memberships and student details

* Imports users with groups into easy-to-modify powershell objects (as a class) (`$list = Import-csv export_with_groups.csv | Convertto-DLUser`)
* Create new users from scratch or AD account (from `get-aduser -properties emailaddress | New-DLUser`) with the username set to the email, avoiding password management.
  * An example might be `$new = ...as above` and make a new full list to work with `$all = $new + $list`
* Bulk remove group memberships on the user list (`$list.removeGroup('example')`)
* Bulk add group membership on the whole list (`$list.addgroup('example)`) or a subest (`($list | where username -like 18*).addGroup('Example')`)
* Automatically assign group memberships form matching AD Group Names (`Update-DLGroup -Users $List -group AD_Name1, AD_Name2`) see also: [School Groups](https://github.com/BirkdaleHigh/ps-SchoolGroups)
* Bulk disable user access to DL (`($list | where xyz).Disable()`)
* Create CSV Files ready to upload in their specific format and advice

You can bulk delete users from DL (`($list | where xyz).Delete()`) but They have disabled this feature from the CSV import menu, so this can at least help you format a CSV to send them. It will warn you if users aren't disabled before they're deleted.


New class methods example;

``` powershell
# Import the data sheet
$allUsers = Import-CSV 'N:\downloads\Accounts.csv' | ConvertTo-DLUser

# Show the users and groups to yourself
$allUsers | format-table username,memberOf

# Empty the year 10 group of everyone
$allUsers.removeGroup('Year 10')

# Set the correct intake year to the new year 10
($allUsers | where-object username -like 16*).addGroup('Year 10')
    
# Set members of 5 classes
Update-DLGroup -user $allUsers -group '7HF_Cs','7JAC_Cs','7LH_Cs','7GMB_Cs','7CW_Cs'

#Create a CSV(s) of only the changed users
$all | where-object action | New-DLCSV
```

When making new users this won't bother adding data DL doesn't need to know therefore help to prevent data loss. This being Dob, UPN, gender.

# Workflow

1. Import the users with groups from a DL CSV (this sets the available groups) from import-user
   1. Once the users are imported, it will have an accurate list of group names to validate future commands against.
2. Add new students from AD piping to new-userclass
3. Combine the lists e.g. `$all = $importedUsers + $newUsers`
4. Update the year groups removegroup/ filter and call addgroup
5. update the class groups `Update-DLGroupMembershipFromAD`
6. export modified users and upload each file.

The Dynamic learning upload works most reliabled around a 250 user limit in the CSVs

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
## ConvertTo-DLUser
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
UPN        : -blank-
email      : Student@example.com
memberOf   : {7M5_Cs, Year 7}
```

### Methods
#### Delete
`$user.delete()` sets the Action property to 'D'
#### Export
`$user.export()` export does a number of things to prepare for creating a CSV to import back to Dynamic Learning

1. Re-format all property names to the pattern as desired by their template
2. Append properties of all the possible group memberships in order to negate previous values
3. Update the group memberships to account for the membersOf property

## Export-DLUser
Simply a wrapper to the `.export()` method described above.

# To Do List

* `Update-User` should have test-user split off to remove compare-object output so it can be used to pipe further
* Finalize `New-DLUser` from reference.ps1 to be called in `update-DLUser` for adding new AD users to Dynamic learning to then have proper group assignment
