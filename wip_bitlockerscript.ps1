# Ensure this script is run as an administrator for proper execution

# Function to provide instructions to enable TPM
function ProvideTPMInstructions {
    Write-Output "TPM is not ready. Please ensure TPM is enabled and activated in your BIOS settings."
    Write-Output "1. Restart your computer and enter the BIOS setup (often by pressing F2, F10, Delete, or Esc during boot)."
    Write-Output "2. Locate the TPM settings within the BIOS, often under Security or Advanced settings."
    Write-Output "3. Enable and activate the TPM. Save changes and exit the BIOS."
    Write-Output "4. Once done, you may re-run this script."
    exit
}

# Check if the D: drive is available
if (-not (Test-Path "D:\")) {
    Write-Output "The D: drive is not detected. Please ensure that the D: drive is connected and try again."
    exit
}

# Check TPM status using Get-TPM cmdlet
try {
    $tpm = Get-TPM
    Write-Output "TPM Present: $($tpm.TpmPresent)"
    Write-Output "TPM Enabled: $($tpm.TpmEnabled)"
    Write-Output "TPM Activated: $($tpm.TpmActivated)"
    Write-Output "TPM Ready: $($tpm.TpmReady)"

    if (-not $tpm.TpmReady) {
        ProvideTPMInstructions
    }
} catch {
    Write-Output "Failed to retrieve TPM status using Get-TPM: $_"
    exit
}

# Define the path to save the recovery key
$recoveryKeyPath = "D:\$env:COMPUTERNAME BitLocker Recovery Key.txt"
Write-Output "Recovery key will be saved to: $recoveryKeyPath"

# Proceed with BitLocker setup if TPM is ready
Write-Output "TPM is enabled and activated. Proceeding with BitLocker setup..."

$osDrive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3 -and $_.DeviceID -eq "C:"}
$osDriveLetter = $osDrive.DeviceID

# Enable BitLocker encryption with TPM and save recovery key to the D: drive
$encryptionStatus = Enable-BitLocker -MountPoint $osDriveLetter -EncryptionMethod XtsAes256 -UsedSpaceOnly -TpmProtector -SkipHardwareTest | Out-String
if ($LASTEXITCODE -eq 0) {
    Write-Output "BitLocker encryption has been successfully initiated on drive $osDriveLetter."

    $recoveryKey = (Get-BitLockerVolume -MountPoint $osDriveLetter).KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
    if ($recoveryKey -ne $null) {
        $recoveryKeyId = $recoveryKey.KeyProtectorId
        Manage-bde -protectors -get $osDriveLetter -Type RecoveryPassword | Out-File $recoveryKeyPath
        Write-Output "Recovery key backed up to $recoveryKeyPath"
    } else {
        Write-Output "Failed to backup the recovery key. Please check BitLocker settings."
    }
} else {
    Write-Output "Failed to initiate BitLocker encryption on drive $osDriveLetter."
}
