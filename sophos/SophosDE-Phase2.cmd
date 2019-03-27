@ECHO OFF

   REM  
   REM  Version 2.01 - Updated 11/4/2017 to add logging to Installed.LOG 
   REM  Version 2.02 - Updated 11/7/2017 to add a backup copy of TSENV.DAT to help recover from a WinPE crash
   REM  Version 2.03 - Updated 11/9/2017 fix a bug in logging, copying TSENV.DAT to TS Logs TSENV.DAT.LOG

SET ScriptVer=2.03

SET NG_DRIVE=%~d0
SET NG_PATH=%~p0
   REM  Strip the trailing "\" off the %NG_PATH% path variable
SET NG_PATH=%NG_PATH:~0,-1%

GOTO :START

   REM  Please call this subroutine liberally to document what's being done by the script!
:LOG
   @set LDT=%DATE:~-10% %TIME%
   @ECHO %LDT%	%*
   @IF NOT EXIST C:\_SMSTaskSequence\Logs IF EXIST X:\NGSTATE\_SMSTaskSequence\Logs\Installed.LOG @ECHO %LDT% ENCPHASE2 - %* >>X:\NGSTATE\_SMSTaskSequence\Logs\Installed.LOG
   @IF     EXIST C:\_SMSTaskSequence\Logs @ECHO %LDT% ENCPHASE2 - %* >>C:\_SMSTaskSequence\Logs\Installed.LOG
   GOTO :EOF

:START

   REM  Move to the folder that the batch file exists in so that all commands are rooted here
%NG_DRIVE%
CD %NG_PATH%

ECHO ScriptVer=%ScriptVer%
CALL :LOG Running SophosDE Phase 2 Script Version %ScriptVer%

IF EXIST C:\*.* IF NOT EXIST X:\sms\bin\x64\*.INI (
   CALL :LOG ERROR, C: drive already exists!
   GOTO :EOF
)
CALL :LOG Running DiskPart to format C: Drive and remove encryption
@ECHO SELECT DISK 0 >%TEMP%\PARTION-DISK-0.TXT
@ECHO CLEAN>>%TEMP%\PARTION-DISK-0.TXT
@ECHO CREATE PARTITION PRIMARY>>%TEMP%\PARTION-DISK-0.TXT
@ECHO FORMAT QUICK FS=NTFS LABEL=WIN10IPMP>>%TEMP%\PARTION-DISK-0.TXT
@ECHO ACTIVE>>%TEMP%\PARTION-DISK-0.TXT
@ECHO ASSIGN LETTER="C">>%TEMP%\PARTION-DISK-0.TXT
@ECHO EXIT>>%TEMP%\PARTION-DISK-0.TXT
IF EXIST X:\sms\bin\x64\*.INI diskpart < %TEMP%\PARTION-DISK-0.TXT



CALL :LOG Restoring Task Sequence State to C: Drive 
xcopy X:\NGSTATE\_SMSTaskSequence\*  C:\_SMSTaskSequence\* /ecihrkyf
   REM  Make a backup copy of TSENV.DAT so that we can do a crash recovery restart
IF EXIST C:\_SMSTaskSequence\TSEnv.dat copy /y C:\_SMSTaskSequence\TSEnv.dat C:\_SMSTaskSequence\TSEnv.dat.BAK
IF EXIST C:\_SMSTaskSequence\TSEnv.dat copy /y C:\_SMSTaskSequence\TSEnv.dat C:\_SMSTaskSequence\Logs\TSEnv.dat.LOG

   REM  If this file doesn't exist the next reboot will generate a "Failed to find the current TS configuration path" error.
   REM  Turns out that it's not really processed and that the volume ID inside doesn't matter for our purposes
   REM  might matter for the "restore" boot sector scripts but we just formatted the drive so that doesn't much matter!!
   REM  Also not that the name of the file is always the same GUID and doesn't change from one machine to another.
if exist X:\NGSTATE\_SMSTSVolumeID.* (
   COPY /Y  X:\NGSTATE\_SMSTSVolumeID.* C:\ 
) ELSE (
   ECHO [SMSTS]> C:\_SMSTSVolumeID.7159644d-f741-45d5-ab29-0ad8aa4771ca
   ECHO VolumeID=D11116222200100000000000>> C:\_SMSTSVolumeID.7159644d-f741-45d5-ab29-0ad8aa4771ca
   ECHO LDP=true>> C:\_SMSTSVolumeID.7159644d-f741-45d5-ab29-0ad8aa4771ca
)
if exist C:\_SMSTSVolumeID.*         attrib +h C:\_SMSTSVolumeID.*

IF EXIST C:\_SMSTaskSequence\Logs ECHO %DATE %TIME% ScriptVer=%ScriptVer% > C:\_SMSTaskSequence\Logs\Sophos-Phase2.LOG

CALL :LOG Copying Boot.wim to C: and creating Boot folder
MKDIR C:\_SMSTaskSequence\WinPE\sources
COPY /Y X:\NGSTATE\LiteTouchPE_x64.wim C:\_SMSTaskSequence\WinPE\sources\boot.wim

XCOPY X:\NGSTATE\x64\* C:\ /ecihrkyf
Attrib +s +h C:\boot
Attrib +s +h C:\EFI
Attrib +s +h +r C:\bootmgr
Attrib +s +h +r C:\bootmgr.efi



CALL :LOG Running BCD Edit commands to make C: Drive bootable 
bcdedit /store C:\BOOT\BCD /create {ramdiskoptions}
bcdedit /store C:\BOOT\BCD /set {ramdiskoptions} ramdisksdidevice partition=c:
bcdedit /store C:\BOOT\BCD /set {ramdiskoptions} ramdisksdipath \boot\boot.sdi
bcdedit /store C:\BOOT\BCD /create {AAAC669D-BC73-4D7B-A4CA-D224664202DA} /d  "Windows 10 IPMP Process"  /application OSLOADER
bcdedit /store C:\BOOT\BCD /set {AAAC669D-BC73-4D7B-A4CA-D224664202DA} device ramdisk=[boot]\_SMSTaskSequence\WinPE\sources\boot.wim,{ramdiskoptions}
bcdedit /store C:\BOOT\BCD /set {AAAC669D-BC73-4D7B-A4CA-D224664202DA} osdevice ramdisk=[boot]\_SMSTaskSequence\WinPE\sources\boot.wim,{ramdiskoptions}
bcdedit /store C:\BOOT\BCD /set {AAAC669D-BC73-4D7B-A4CA-D224664202DA} systemroot \windows
bcdedit /store C:\BOOT\BCD /set {AAAC669D-BC73-4D7B-A4CA-D224664202DA} winpe yes
bcdedit /store C:\BOOT\BCD /set {AAAC669D-BC73-4D7B-A4CA-D224664202DA} ems yes
bcdedit /store C:\BOOT\BCD /set {AAAC669D-BC73-4D7B-A4CA-D224664202DA} detecthal yes
bcdedit /store C:\BOOT\BCD /displayorder {AAAC669D-BC73-4D7B-A4CA-D224664202DA} /addfirst
bcdedit /store C:\BOOT\BCD /default {AAAC669D-BC73-4D7B-A4CA-D224664202DA}
bcdedit /store C:\BOOT\BCD /timeout 5
   REM  This just displays the output for debugging purposes
bcdedit /store C:\BOOT\BCD /enum



CALL :LOG Writing the boot sector to C: Drive 
X:\sms\bin\x64\BOOTSECT.EXE /nt60 C: /force /mbr


CALL :LOG Rebooting back into into Task Sequence Process
exit 0