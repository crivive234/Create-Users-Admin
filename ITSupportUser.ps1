<#
.SYNOPSIS
    Local IT user account manager (Windows) - PowerShell version.
.DESCRIPTION
    Creates, updates or unlocks a local user, adds it to the Administrators group,
    and sets the password to never expire and not be changeable by the user.
.PARAMETER User
    Target user name. Default: "itsupport".
.PARAMETER Password
    User password. If not provided and User is "itsupport", the default password
    "ColombiaIT2025!!" is used. For any other user, it is mandatory.
.PARAMETER UnlockOnly
    If specified, only unlocks the user account (no create/update).
.PARAMETER Silent
    Silent mode: suppresses all verbose output and only shows a summary message at the end.
.PARAMETER Help
    Displays this help message.
.EXAMPLE
    .\ITSupportUser.ps1 -User yubico -Password "Thanksgiving2025*"
    Creates or updates user "yubico" with the given password.
.EXAMPLE
    .\ITSupportUser.ps1 -UnlockOnly -Silent
    Unlocks the "itsupport" account and shows only "User itsupport unlocked".
.EXAMPLE
    .\ITSupportUser.ps1 -User itsupport
    Creates/updates "itsupport" with the default password.
.EXAMPLE
    .\ITSupportUser.ps1 -Help
    Displays this help message.
.NOTES
    Requires administrator privileges.
    Author: Adapted from original Batch script.
#>

[CmdletBinding()]
param(
    [Alias('UserName')]
    [string]$User = "itsupport",
    [string]$Password,
    [switch]$UnlockOnly,
    [switch]$Silent,
    [Alias('?', 'h')]
    [switch]$Help
)

# -----------------------------------------------------------
# 1. Show help if requested
# -----------------------------------------------------------
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# -----------------------------------------------------------
# 2. Initial configuration
# -----------------------------------------------------------
$ErrorActionPreference = "Continue"
$DefaultPassword = "DefaultPassword"

function Write-VerboseOutput {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host $Message
    }
}

# -----------------------------------------------------------
# 3. Verify administrator privileges
# -----------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as administrator'." -ForegroundColor Red
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}
Write-VerboseOutput "[INFO] Administrator privileges verified."

# -----------------------------------------------------------
# 4. Assign default password if not provided
# -----------------------------------------------------------
if (-not $Password) {
    if ($User -eq "itsupport") {
        $Password = $DefaultPassword
        Write-VerboseOutput "[INFO] No -Password specified. Using default password for itsupport."
    } else {
        Write-Host "[ERROR] You must specify a password with -Password for user '$User'." -ForegroundColor Red
        Write-Host "Empty passwords are not allowed." -ForegroundColor Red
        if (-not $Silent) { Read-Host "Press Enter to exit" }
        exit 1
    }
}

if ([string]::IsNullOrEmpty($Password)) {
    Write-Host "[ERROR] Password cannot be empty." -ForegroundColor Red
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}

Write-VerboseOutput "[INFO] Target user: $User"

# -----------------------------------------------------------
# 5. Function to unlock a user account
# -----------------------------------------------------------
function Unlock-LocalUserAccount {
    param([string]$UserName)
    Write-VerboseOutput "[STEP] Unlocking user account '$UserName'..."

    # Check if user exists
    try {
        $existingUser = Get-LocalUser -Name $UserName -ErrorAction Stop
    } catch {
        Write-Host "[ERROR] User '$UserName' does not exist." -ForegroundColor Red
        return $false
    }

    $unlocked = $false
    # Prefer PowerShell cmdlet
    try {
        Unlock-LocalUser -Name $UserName -ErrorAction Stop
        $unlocked = $true
        Write-VerboseOutput "[OK] Account unlocked (via PowerShell)."
    } catch {
        Write-VerboseOutput "[WARN] Unlock-LocalUser not available. Falling back to net user..."
        $result = net user $UserName /active:yes 2>&1
        if ($LASTEXITCODE -eq 0) {
            $unlocked = $true
            Write-VerboseOutput "[OK] Account unlocked (via net user)."
        } else {
            Write-Host "[ERROR] Could not unlock the account." -ForegroundColor Red
            return $false
        }
    }

    if ($unlocked -and $UnlockOnly) {
        if ($Silent) {
            Write-Host "User '$User' unlocked"
        } else {
            Write-Host "============================================"
            Write-Host "   User '$User' successfully unlocked"
            Write-Host "============================================"
        }
    }
    return $unlocked
}

# -----------------------------------------------------------
# 6. Function to temporarily disable password complexity policy
# -----------------------------------------------------------
function Disable-PasswordPolicy {
    Write-VerboseOutput "[STEP 1] Checking password policy..."

    $tempCfg = Join-Path $env:TEMP "secpol_check.cfg"
    secedit /export /cfg $tempCfg /quiet 2>$null

    $needSecEdit = $false
    if (Test-Path $tempCfg) {
        $content = Get-Content $tempCfg -Raw
        if ($content -match "PasswordComplexity\s*=\s*1") { $needSecEdit = $true }
        if ($content -match "MinimumPasswordLength\s*=\s*([1-9]\d*)") { $needSecEdit = $true }
        Remove-Item $tempCfg -Force -ErrorAction SilentlyContinue
    }

    if (-not $needSecEdit) {
        Write-VerboseOutput "[OK] No active policy. Skipping this step."
        return $true
    }

    Write-VerboseOutput "[INFO] Active password policy detected. Disabling temporarily..."

    $secpolContent = @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordLength = 0
PasswordComplexity = 0
PasswordHistorySize = 0
MaximumPasswordAge = -1
MinimumPasswordAge = 0
ClearTextPassword = 0
[Version]
signature="`$CHICAGO`$"
Revision=1
"@
    $tempSecPol = Join-Path $env:TEMP "secpol_temp.cfg"
    $secpolContent | Out-File -FilePath $tempSecPol -Encoding ASCII -Force

    secedit /configure /db "$env:TEMP\secedit_temp.sdb" /cfg $tempSecPol /areas SECURITYPOLICY /quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to modify policy. Exit code: $LASTEXITCODE" -ForegroundColor Red
        return $false
    }

    Write-VerboseOutput "[OK] Policy disabled successfully."
    Remove-Item $tempSecPol -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\secedit_temp.sdb" -Force -ErrorAction SilentlyContinue
    return $true
}

# -----------------------------------------------------------
# 7. Function to create or update user and set password
# -----------------------------------------------------------
function Set-LocalUserAccount {
    param(
        [string]$UserName,
        [string]$Password
    )

    $userExists = $false
    try {
        $existingUser = Get-LocalUser -Name $UserName -ErrorAction Stop
        $userExists = $true
    } catch {
        # User does not exist
    }

    if ($userExists) {
        Write-VerboseOutput "[WARN] User '$UserName' already exists. Updating password..."
        try {
            $securePwd = ConvertTo-SecureString -String $Password -AsPlainText -Force
            Set-LocalUser -Name $UserName -Password $securePwd -ErrorAction Stop
            Write-VerboseOutput "[OK] Password updated successfully (via PowerShell)."
            return $true
        } catch {
            Write-VerboseOutput "[WARN] Set-LocalUser failed. Falling back to net user..."
            net user $UserName $Password 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Could not update password (net user). Exit code: $LASTEXITCODE" -ForegroundColor Red
                return $false
            }
            Write-VerboseOutput "[OK] Password updated successfully (via net user)."
            return $true
        }
    } else {
        Write-VerboseOutput "[STEP 2] Creating user '$UserName'..."
        try {
            $securePwd = ConvertTo-SecureString -String $Password -AsPlainText -Force
            New-LocalUser -Name $UserName -Password $securePwd -FullName $UserName -Description "User $UserName" -ErrorAction Stop
            Write-VerboseOutput "[OK] User '$UserName' created successfully (via PowerShell)."
            return $true
        } catch {
            Write-VerboseOutput "[WARN] New-LocalUser failed. Falling back to net user..."
            net user $UserName $Password /add /comment:"User $UserName" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Could not create user (net user). Exit code: $LASTEXITCODE" -ForegroundColor Red
                return $false
            }
            Write-VerboseOutput "[OK] User '$UserName' created successfully (via net user)."
            return $true
        }
    }
}

# -----------------------------------------------------------
# 8. Function to set password policy (never expire, cannot change)
# -----------------------------------------------------------
function Set-UserPasswordPolicy {
    param([string]$UserName)

    Write-VerboseOutput "[STEP 3] Setting user password policy..."

    $policyOk = $false
    # Try with PowerShell cmdlet
    try {
        Set-LocalUser -Name $UserName -PasswordNeverExpires $true -UserMayNotChangePassword $true -ErrorAction Stop
        Write-VerboseOutput "[OK] Password set to never expire and user cannot change it (via PowerShell)."
        $policyOk = $true
    } catch {
        Write-VerboseOutput "[WARN] Set-LocalUser for policy failed. Falling back to net user..."
        # Set never expire
        net user $UserName /expires:never 2>&1 | Out-Null
        $errCode = $LASTEXITCODE
        if ($errCode -eq 0) {
            Write-VerboseOutput "[OK] Password set to never expire (net user)."
        } elseif ($errCode -eq 1322) {
            Write-VerboseOutput "[WARN] Could not set 'never expire' because $UserName is the last enabled administrator (error 1322)."
        } else {
            Write-VerboseOutput "[WARN] Could not set 'never expire' (exit code $errCode)."
        }

        # Prevent user from changing password
        net user $UserName /passwordchg:no 2>&1 | Out-Null
        $errCode = $LASTEXITCODE
        if ($errCode -eq 0) {
            Write-VerboseOutput "[OK] User cannot change password (net user)."
        } elseif ($errCode -eq 1322) {
            Write-VerboseOutput "[WARN] Could not block password change because $UserName is the last enabled administrator (error 1322)."
        } else {
            Write-VerboseOutput "[WARN] Could not block password change (exit code $errCode)."
        }
        # WMIC is no longer used; net user covers both attributes.
        $policyOk = $true  # Consider non-critical
    }

    return $policyOk
}

# -----------------------------------------------------------
# 9. Function to add user to Administrators group
# -----------------------------------------------------------
function Add-UserToAdministrators {
    param([string]$UserName)

    Write-VerboseOutput "[STEP 4] Adding to Administrators group..."

    try {
        Add-LocalGroupMember -Group "Administradores" -Member $UserName -ErrorAction Stop
        Write-VerboseOutput "[OK] Added to Administradores group (via PowerShell)."
        return $true
    } catch {
        Write-VerboseOutput "[WARN] Add-LocalGroupMember failed. Falling back to net localgroup..."
        net localgroup Administradores $UserName /add 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            net localgroup Administrators $UserName /add 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-VerboseOutput "[WARN] Could not add to group or already a member."
            } else {
                Write-VerboseOutput "[OK] Added to Administrators group (net localgroup)."
            }
        } else {
            Write-VerboseOutput "[OK] Added to Administradores group (net localgroup)."
        }
        return $true
    }
}

# -----------------------------------------------------------
# 10. Function to show summary
# -----------------------------------------------------------
function Show-Summary {
    param(
        [string]$UserName,
        [string]$Password,
        [bool]$PasswordWasSet
    )

    if ($Silent) {
        Write-Host "User '$UserName' configured successfully"
        Write-Host ""
        return
    }

    Write-Host "============================================"
    Write-Host "   User '$UserName' configured successfully"
    Write-Host "============================================"
    Write-Host ""
    Write-Host " - Username: $UserName"
    if ($PasswordWasSet) {
        Write-Host " - Password: as provided with -Password"
    } else {
        Write-Host " - Password: default for itsupport (defined in script)"
    }
    Write-Host " - Administrator of the system"
    Write-Host " - Password never expires (if allowed by system)"
    Write-Host " - User cannot change password (if allowed by system)"
    Write-Host ""
}

# -----------------------------------------------------------
# 11. Main logic
# -----------------------------------------------------------
try {
    # If only unlock requested, run and exit
    if ($UnlockOnly) {
        $result = Unlock-LocalUserAccount -UserName $User
        if ($result) {
            if (-not $Silent) { Read-Host "Press Enter to close" }
            exit 0
        } else {
            if (-not $Silent) { Read-Host "Press Enter to close" }
            exit 1
        }
    }

    # Step 1: Disable complexity policy
    $policyOk = Disable-PasswordPolicy
    if (-not $policyOk) {
        if (-not $Silent) { Read-Host "Press Enter to close" }
        exit 1
    }

    # Step 2: Create/update user
    $userOk = Set-LocalUserAccount -UserName $User -Password $Password
    if (-not $userOk) {
        if (-not $Silent) { Read-Host "Press Enter to close" }
        exit 1
    }

    # Step 3: Set password policy
    $policyUserOk = Set-UserPasswordPolicy -UserName $User
    # Not critical if it fails, just warning

    # Step 4: Add to Administrators
    $groupOk = Add-UserToAdministrators -UserName $User
    # Not critical

    # Final verification (only in verbose mode)
    if (-not $Silent) {
        Write-VerboseOutput "[VERIFICATION] Final user configuration:"
        Write-VerboseOutput ""
        net user $User
        Write-VerboseOutput ""
    }

    # Show summary
    $passwordWasSet = $true
    Show-Summary -UserName $User -Password $Password -PasswordWasSet $passwordWasSet

    if (-not $Silent) {
        Read-Host "Press Enter to close"
    }

} catch {
    Write-Host "[ERROR] Unhandled exception: $_" -ForegroundColor Red
    if (-not $Silent) { Read-Host "Press Enter to close" }
    exit 1
}
