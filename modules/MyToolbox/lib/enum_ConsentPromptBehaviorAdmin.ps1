## This enumeration represents the values of the ConsentPromptBehaviorAdmin registry item.
## See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsb/341747f5-6b5d-4d30-85fc-fa1cc04038d4

enum ConsentPromptBehaviorAdmin {
    Disable = 0                 # This option allows the Consent Admin to perform an operation that requires elevation without consent or credentials.
    LoginSecureDesktop = 1      # This option prompts the Consent Admin to enter his or her user name and password (or another valid admin) when an operation requires elevation of privilege. This operation occurs on the secure desktop.
    AgreeSecureDesktop = 2      # This option prompts the administrator in Admin Approval Mode to select either "Permit" or "Deny" an operation that requires elevation of privilege. If the Consent Admin selects Permit, the operation will continue with the highest available privilege. "Prompt for consent" removes the inconvenience of requiring that users enter their name and password to perform a privileged task. This operation occurs on the secure desktop.
    Login = 3                   # This option prompts the Consent Admin to enter his or her user name and password (or that of another valid admin) when an operation requires elevation of privilege.
    Agree = 4                   # This prompts the administrator in Admin Approval Mode to select either "Permit" or "Deny" an operation that requires elevation of privilege. If the Consent Admin selects Permit, the operation will continue with the highest available privilege. "Prompt for consent" removes the inconvenience of requiring that users enter their name and password to perform a privileged task.
    AgreeIfNotMicrosoft = 5     # This option is the default. It is used to prompt the administrator in Admin Approval Mode to select either "Permit" or "Deny" for an operation that requires elevation of privilege for any non-Windows binaries. If the Consent Admin selects Permit, the operation will continue with the highest available privilege. This operation will happen on the secure desktop.
}