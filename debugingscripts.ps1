Get-Content "$env:ProgramData\ProactiveIT\reboot_schedule.json"

Unregister-ScheduledTask -TaskName "ProactiveIT_UpdateAndReboot" -Confirm:$false -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName "ProactiveIT_UpdateAndReboot" | Get-ScheduledTaskInfo
powershell -ExecutionPolicy Bypass -File "C:\Users\sauls\OneDrive\Desktop\ProactiveNetworking\Projects\BasicAppsInstaller\Reboot_popup_step2.ps1"


Unregister-ScheduledTask -TaskName "ProactiveIT_RebootPopup" -Confirm:$false 
Unregister-ScheduledTask -TaskName "ProactiveIT_RebootWarning" -Confirm:$false 