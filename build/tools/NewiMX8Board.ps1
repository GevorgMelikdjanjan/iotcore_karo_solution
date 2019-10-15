# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Param(
    [string] $NewBoard
)

if ($NewBoard -eq "") {
    Write-Host "Usage: NewiMX8Board.ps1 <NewBoardName>"
    Write-Host "Creates a new board package based on the i.MX8M Mini EVK and a new Firmware folder"
    Write-Host "The resulting board directory is stored in imx-iotcore\build\board"
    Write-Host "The resulting firmware directory is stored in imx-iotcore\build\firmware"
    Write-Host "This new board name should follow the format BoardName_SoCType_MemoryCapacity, for example:"
    Get-ChildItem $PSScriptRoot\..\board\ | Write-Host
    exit
}

if (Test-Path $PSScriptRoot\..\board\$NewBoard) {
    Write-Host "Board name $NewBoard already exists in $PSScriptRoot\..\board\"
    exit
}

robocopy $PSScriptRoot\..\board\NXPEVK_iMX8M_Mini_2GB $PSScriptRoot\..\board\$NewBoard /E


Push-Location -Path "$PSScriptRoot\..\board\$NewBoard"

# Clean out the build folder and readme that were copied
Remove-Item -path Package\ARM -recurse -ErrorAction SilentlyContinue
Remove-Item -path README.md
Write-Output $NewBoard board package > README.md

# Replace the word NXPEVK_iMX8M_Mini_2GB in all new files, excluding the firmware binaries
Write-Host "Replacing NXPEVK_iMX8M_Mini_2GB in new board package files with $NewBoard"
$Files = Get-ChildItem . * -rec -File -Exclude *.fd, *.merged, *.fit
foreach ($file in $Files)
{
    (Get-Content $file.PSPath) |
    Foreach-Object { $_ -replace "NXPEVK_iMX8M_Mini_2GB", $NewBoard } |
    Set-Content $file.PSPath
}

# Replace the word NXPEVK_iMX8M_Mini_2GB in all new folder and filenames
Write-Host "Replacing NXPEVK_iMX8M_Mini_2GB in new board package file/folder names with $NewBoard"
Get-ChildItem -Filter "*NXPEVK_iMX8M_Mini_2GB*" -Recurse | Rename-Item -NewName {$_.name -replace 'NXPEVK_iMX8M_Mini_2GB',$NewBoard }

Pop-Location

# Create a new firmware folder
robocopy $PSScriptRoot\..\firmware\NXPEVK_iMX8M_Mini_2GB $PSScriptRoot\..\firmware\$NewBoard /E

Push-Location -Path "$PSScriptRoot\..\firmware\"

$UpperNewBoard = $NewBoard.ToUpper();

$oldmake1 = "NXPEVK_iMX8M_Mini_2GB"
$newmake1 = "${NewBoard} NXPEVK_iMX8M_Mini_2GB"

$oldmake2 = "NXPEVK_iMX8M_Mini_2GB:`n"
$newmake2 = "${NewBoard}:`n`t`$(MAKE) -C `$@`n`nNXPEVK_iMX8M_Mini_2GB:`n"

$oldmake3 = "NXPEVK_IMX8M_MINI_2GB_PKG_DIR="
$newmake3 = "${UpperNewBoard}_PKG_DIR=`$(CURDIR)/../board/${NewBoard}/Package/BootLoader`nNXPEVK_IMX8M_MINI_2GB_PKG_DIR="

$oldmake4 = "`tcd NXPEVK_iMX8M_Mini_2GB"
$newmake4 = "`tcd ${NewBoard} && \`n`t  cp firmware_fit.merged firmwareversions.log `$(${UpperNewBoard}_PKG_DIR) && cd ..`n`tcd NXPEVK_iMX8M_Mini_2GB"

$oldmake5 = "`tgit reset`n"
$newmake5 = "`tgit reset`n`tcd `$(${UpperNewBoard}_PKG_DIR) && \`n`t  git add firmware_fit.merged firmwareversions.log`n"

Write-Host "Adding $NewBoard to the common firmware makefile"

$content = Get-Content .\Makefile -Raw
$content = $content -replace $oldmake1, $newmake1
$content = $content -replace $oldmake2, $newmake2
$content = $content -replace $oldmake3, $newmake3
$content = $content -replace $oldmake4, $newmake4
$content = $content -replace $oldmake5, $newmake5

Set-Content -Path ".\Makefile" -Value $content

Pop-Location

# Add the new board to the iMX6 FFU build script
Push-Location -Path "$PSScriptRoot\..\solution\iMXPlatform\GenerateTestFFU"

Add-Content -Path GenerateFFU.bat -Encoding Ascii -Value " "
Add-Content -Path GenerateFFU.bat -Encoding Ascii -Value "cd /d %BATCH_HOME%"
Add-Content -Path GenerateFFU.bat -Encoding Ascii -Value "echo ""Building $NewBoard FFU"""
Add-Content -Path GenerateFFU.bat -Encoding Ascii -Value "call BuildImage $NewBoard ${NewBoard}_TestOEMInput.xml"

Pop-Location

Write-Host "`n`nNew board package created in imx-iotcore\build\board\$NewBoard`n
New firmware folder created in imx-iotcore\build\firmware\$NewBoard"

Write-Warning "Firmware setup is not complete!"
Write-Warning "You must update imx-iotcore\build\firmware\$NewBoard\Makefile with the correct UBOOT and OP-TEE and EDK2 settings for your device!"

Write-Warning "The project file imx-iotcore\build\board\$NewBoard\Package\${NewBoard}_Package.vcxproj must also be added to your solution"
