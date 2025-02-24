# Banner Display
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  User Rights Assignment Export Script   " -ForegroundColor White
Write-Host "  Written by: cloverophile               " -ForegroundColor Green
Write-Host "  Description: Exports user rights       " -ForegroundColor White
Write-Host "  assignments from the local security    " -ForegroundColor White
Write-Host "  policy and logs the results.           " -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Define the working directory (current directory)
$WorkingDir = Get-Location

# Creating/selecting destination files dynamically:
$SecpolFile = Join-Path -Path $WorkingDir -ChildPath "exported.cfg"
$LogFile = Join-Path -Path $WorkingDir -ChildPath "UserRightsReport.log"

# If the current user is not Administrator, the warning message is shown: 
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)

if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit
}

# Function to match SID values:
function Is-SID($value) {
    return $value -match "^S-.*"
}

# Function to match SIDs for corresponding account/group name values:  
function Get-AccountOrGroupNameFromSID($value) {
    $value = $value.TrimStart('*').Trim()  

    if (Is-SID $value) {
        try {
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($value)
            return $objSID.Translate([System.Security.Principal.NTAccount]).Value
        } catch {
            return "Unresolved SID: $value (it might be a capability SID)"
        }
    } else {
        return "Not an SID: $value"
    }
}

# Exporting the policy:
Write-Host "Exporting User Rights Policy..." -ForegroundColor DarkCyan
secedit /export /areas USER_RIGHTS /cfg $SecpolFile 2>&1 | Out-Null

if (!(Test-Path $SecpolFile)) {
    Write-Host "Error: Failed to export security policy to $SecpolFile" -ForegroundColor Red
    exit
}

$SecpolContent = Get-Content -Path $SecpolFile
$LogOutput = @()

# Printing the result to the console: 
Write-Host "`n=== USER RIGHTS ASSIGNMENT ===" -ForegroundColor Yellow
$LogOutput += "=== USER RIGHTS ASSIGNMENT ===`n"

$SecpolContent | ForEach-Object {
    if ($_ -match "^(Se\w+Right)\s*=\s*(.*)" -Or $_ -match "^(Se\w+Privilege)\s*=\s*(.*)") {
        $Privilege = $matches[1]
        $SIDs = $matches[2] -split ","

        Write-Host "`n[$Privilege]" -ForegroundColor Cyan 
        $LogOutput += "`n[$Privilege]"
        $Debug = $Debug + 1

        foreach ($SID in $SIDs) {
            $Object = Get-AccountOrGroupNameFromSID $SID 
            Write-Host "  - $Object" -ForegroundColor Green
            $LogOutput += "  - $Object"
        }
    }
}

# Exporting the result to a log file: 
$LogOutput | Out-File -FilePath $LogFile -Encoding utf8
Write-Host "`nResults saved to: $LogFile" -ForegroundColor DarkCyan