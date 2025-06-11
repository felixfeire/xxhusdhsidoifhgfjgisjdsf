@echo off

set NASM_PATH="C:\Dev\nasm\nasm.exe"
set QEMU_PATH="C:\Program Files\QEMU\qemu-system-i386w.exe"

set BOOT_ASM=boot.asm
set KERNEL_ASM=kernel.asm

set BOOT_BIN=boot.bin
set KERNEL_BIN=kernel.bin
set OUTPUT_IMAGE=os_image.img
set FLOPPY_IMAGE=floppy.img

echo Building bootloader...
%NASM_PATH% %BOOT_ASM% -f bin -o %BOOT_BIN%
if errorlevel 1 goto error_nasm

echo Building kernel (all ASM modules)...
%NASM_PATH% %KERNEL_ASM% -f bin -o %KERNEL_BIN%
if errorlevel 1 goto error_nasm

echo Creating raw OS image...
copy /b %BOOT_BIN%+%KERNEL_BIN% %OUTPUT_IMAGE%
if errorlevel 1 goto error_copy

echo Generating floppy image via Python script...
python make_floppy.py
if errorlevel 1 goto error_py

echo Running in QEMU with HDD and Floppy...
%QEMU_PATH% -hda %OUTPUT_IMAGE% -fda %FLOPPY_IMAGE% -m 256M -debugcon stdio -no-shutdown -no-reboot

goto :eof

:error_nasm
echo.
echo ERROR: NASM compilation failed!
pause
goto :eof

:error_copy
echo.
echo ERROR: Image creation failed!
pause
goto :eof

:error_py
echo.
echo ERROR: Python script failed!
pause
goto :eof
