@ECHO OFF

   REM  
   REM  Version 2.03 - Updated 11/3/2017 to add logging to Installed.LOG,corrected SMSTS log folder source,
   REM                 Successful exit code is now 555

SET ScriptVer=2.03

SET NG_DRIVE=%~d0
SET NG_PATH=%~p0
   REM  Strip the trailing "\" off the %NG_PATH% path variable
SET NG_PATH=%NG_PATH:~0,-1%


   REM  Move to the folder that the batch file exists in so that all commands are rooted here
%NG_DRIVE%
CD %NG_PATH%

IF "%SMSLOGDIR%"=="" SET SMSLOGDIR=%TEMP%

GOTO :START

   REM  Please call this subroutine liberally to document what's being done by the script!
:LOG
   @set LDT=%DATE:~-10% %TIME%
   @ECHO %LDT%	%*
   @ECHO %LDT% ENCPHASE1 - %* >>%SMSLOGDIR%\INSTALLED.LOG
   GOTO :EOF

:START

CALL :LOG Running SophosDE Phase 1 Script Version %ScriptVer%
ECHO ScriptRoot=%ScriptRoot%
ECHO DeployRoot=%DeployRoot%

@ECHO Scanning for WIM Folder with LiteTouchPE_x64.wim
SET WIM-FOLDER=Not Found
FOR /D %%D IN (C:\_SMSTaskSequence\Packages\*) DO IF EXIST %%D\Boot\LiteTouchPE_x64.wim SET WIM-Folder=%%D
IF NOT EXIST %WIM-Folder%\Boot\LiteTouchPE_x64.wim (
   CALL :LOG ERROR - Could Not Locate Package Source folder with .\Boot\LiteTouchPE_x64.wim
   EXIT 800
)
CALL :LOG WIM-Folder=%WIM-Folder%


ROBOCOPY %WIM-Folder%\Boot\ %DeployRoot%\Boot\ /E /NP
CALL :LOG Robocopy WIM Folder, Exit Code = %ERRORLEVEL%


cscript //nologo %ScriptRoot%\LTIApply.wsf /pe
CALL :LOG Running LTIApply.wsf, Exit Code = %ERRORLEVEL%


CALL :LOG Mounting WIM Image
IF EXIST "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$" (
   @ECHO Temporary Mount Folder already exists, removing it . . .
   RMDIR /Q /S "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$"
)
MKDIR "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$"
IF EXIST .\IMAGEX.EXE (
   .\IMAGEX.EXE /MountRW "C:\sources\boot.wim" 1 "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$"
) ELSE (
   DISM /Mount-WIM /WimFile:"C:\sources\boot.wim" /Index:1 /MountDir:"C:\_SMSTaskSequence\WinPE\$MOUNTDIR$"
)


CALL :LOG Injecting TS State into WIM, next message will be after Phase 2 WIM boots
mkdir "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE"
mkdir "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence"
        REM robocopy C:\_SMSTaskSequence\ C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\ *.* /e /xd C:\_SMSTaskSequence\WinPE
   REM  Just saving the Logs folder, TSEnv.dat, and _SMSTSVolumeID.* file


MKDIR C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs

IF EXIST C:\_SMSTaskSequence\Logs ECHO %DATE %TIME% ScriptVer=%ScriptVer% > %SMSLOGDIR%\Sophos-Phase1.LOG
xcopy     %SMSLOGDIR%\*             C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs\* /ecihrkyf
IF EXIST C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs\SMSTS.LOG COPY /Y C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs\SMSTS.LOG C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs\smsts-Before-IPMP-Reboot.log
copy /y   C:\Windows\IPMP-*.MRK.LOG                  C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs\



copy /y   C:\_SMSTaskSequence\TSEnv.dat          C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\TSEnv.dat
attrib -h C:\_SMSTSVolumeID.*
copy /y   C:\_SMSTSVolumeID.*                    C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\
xcopy     C:\_SMSTaskSequence\WDPackage\Boot\*   C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\* /ecihrkyf
mkdir     C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs
copy /y C:\Windows\CCM\Logs\smsts.log C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\_SMSTaskSequence\Logs\smsts.log


@ECHO Updating WIM Image with Phase2  scripts . . .
copy /y X:\sms\bin\x64\cmtrace.exe  C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\windows\system32\cmtrace.exe
copy /y .\SophosDE-Phase2.cmd       C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\SophosDE-Phase2.cmd
IF EXIST .\IMAGEX.EXE copy /y .\IMAGEX.EXE                C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\NGSTATE\IMAGEX.EXE
ECHO [LaunchApps]>C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\Windows\system32\winpeshl.ini
ECHO wpeinit>>C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\Windows\system32\winpeshl.ini
ECHO \NGSTATE\SophosDE-Phase2.cmd>>C:\_SMSTaskSequence\WinPE\$MOUNTDIR$\Windows\system32\winpeshl.ini


@ECHO Waiting 60 seconds before attempting to unmount WIM . . 
IF /I     "%PROCESSOR_ARCHITECTURE%"=="AMD64" .\SLEEPx64.EXE 60
IF /I NOT "%PROCESSOR_ARCHITECTURE%"=="AMD64" .\SLEEPx86.EXE 60
@ECHO Unmounting WIM Image . . .
IF EXIST .\IMAGEX.EXE (
   .\IMAGEX /UNMOUNT /COMMIT "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$"
) ELSE (
   DISM.EXE /Unmount-Wim /MountDir:"C:\_SMSTaskSequence\WinPE\$MOUNTDIR$" /Commit
)
IF "%ERRORLEVEL%"=="0" RMDIR /S /Q "C:\_SMSTaskSequence\WinPE\$MOUNTDIR$"

@ECHO Ready to return to the Source OS Task Sequence, it will then reboot the PC
exit 555


