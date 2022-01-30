## This enumeration represents the values of the ConsentPromptBehaviorUser registry item.
## See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsb/15f4f7b3-d966-4ff4-8393-cb22ea1c3a63

enum ConsentPromptBehaviorUser {
    AutoDeny = 0            # This option SHOULD be set to ensure that any operation that requires elevation of privilege will fail as a standard user.
    LoginSecureDesktop = 1  # This option SHOULD be set to ensure that a standard user that needs to perform an operation that requires elevation of privilege will be prompted for an administrative user name and password. If the user enters valid credentials, the operation will continue with the applicable privilege.
    Login = 3               # ! NOT DOCUMENTED BUT USED IN WINDOWS SERVER 2016
}