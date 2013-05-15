:: Script for operations on APK's
:: Requirements:
::   You must have JDK installed and java.exe in PATH
:: Usage:
::   Put all apk's from your device's /system/framework into folder \framework
::   Run APK_worker.bat with parameters

@echo off

:: Not changing calling process' PATH variable
setlocal

set CDir=%~dp0%
:: Use aapt from SDK by default
set AAPT=aapt_SDK.exe
:: ! Uncomment this line ONLY if you have troubles building/decompiling apk's !
:: set AAPT=aapt_Custom.exe

:: Check all needed files

copy /y "%CDir%\%AAPT%" "%CDir%\aapt.exe" > nul

:: Java
java -version 2> nul
if errorlevel 1 (
	echo Java not installed!
	goto :Err
)
:: apktool
if not exist "%CDir%\apktool.jar" (
	echo %CDir%\apktool.jar not found
	goto :Err
)
:: aapt
if not exist "%CDir%\aapt.exe" (
	echo %CDir%\aapt.exe not found
	goto :Err
)
:: 7zip
if not exist "%CDir%\7za.exe" (
	echo %CDir%\7za.exe not found
	goto :Err
)

:: Perform operation basing on the parameter given

:: Wrong parameters/help parameters - print usage
if .%1%.==.. goto label_Help
if .%1%.==./?. goto label_Help
if .%1%.==.help. goto label_Help

:: Split 2nd param into path and name (for build and fixfolders, no name is needed)
if .%1%.==.build. (
    set APK_Path=%~dpn2%
) else if .%1%.==.fixfolders. (
    set APK_Path=%~dpn2%
) else (
    set APK_Path=%~dp2%
    set APK_Name=%~n2%
)

if .%1%.==.decomp. goto label_Decomp_Full
if .%1%.==.decomp_src. goto label_Decomp_Src
if .%1%.==.decomp_res. goto label_Decomp_Res
if .%1%.==.fixfolders. goto label_FixFolders
if .%1%.==.build. goto label_Build
if .%1%.==.modify. goto label_Modify
if .%1%.==.sign. goto label_Sign
if .%1%.==.clean. goto label_Clean

:: Help
:label_Help
echo Script for main operations with APK
echo Usage:
echo APK_Worker.bat {command} [{source}] [{param}]
echo command:
echo   /?, help - this text
echo   decomp - full decompile APK (res + source) to {apk_path}\{apk_name} folder
echo   decomp_res - decompile APK (res only - faster) to {apk_path}\{apk_name} folder
echo   decomp_src - decompile APK (source only) to {apk_path}\{apk_name} folder
echo   fixfolders - fix folder names that were wrongfully renamed on decompile
echo   build - build temporary APK to {apk_path}\build\
echo   modify - add/replace files inside APK
echo   sign - remove certificate and sign the APK
echo   clean - remove installed frameworks from %HOMEDRIVE%%HOMEPATH%\apktool\framework
echo For detailed info, check README file
pause
goto :EOF

:: Decompile res and sources
:label_Decomp_Full

SET Decomp_Param=
goto label_Decomp

:: Decompile res only
:label_Decomp_Res

SET Decomp_Param=--no-src
goto label_Decomp

:: Decompile src only
:label_Decomp_Src

SET Decomp_Param=--no-res
goto label_Decomp

:: Do decompile
:label_Decomp

:: apktool couldn't work if aapt.exe isn't in the %CD% so moving there temporarily
pushd "%CDir%"

:: (Re)Install all the frameworks (sometimes required)
rd /s/q "%HOMEDRIVE%%HOMEPATH%\apktool\framework" 2> nul
FOR %%F IN ("%APK_Path%\framework\*.apk") DO java -jar "apktool.jar" if "%%F"

rd /s/q "%APK_Path%\%APK_Name%" 2> nul

:: Decompile
call java.exe -jar "apktool.jar" d %Decomp_Param% --force "%APK_Path%\%APK_Name%.apk" "%APK_Path%\%APK_Name%"

if errorlevel 1 (
    popd
    goto :Err
)
popd
goto :EOF

:: Do fix folders
:label_FixFolders

set Lst_File=%~3%

for /f "tokens=1,*" %%s in (%Lst_File%) do (
    ren "%APK_Path%\%APK_Name%\%%s" "%%t"
)
goto :EOF

:: Do build
:label_Build

:: apktool couldn't work if aapt.exe isn't in the %CD% so moving there temporarily
pushd "%CDir%"

:: Build
call java.exe -jar "apktool.jar" b --force-all "%APK_Path%"

if errorlevel 1 (
    popd
    goto :Err
)
popd
goto :EOF

:: Replace/remove files in APK with files from %3 according to list file %4
:label_Modify

set Src_Path=%~3%
set Lst_File=%~4%

:: Changing CD so that 7zip could add/remove files with correct paths
pushd "%Src_Path%"
for /f "tokens=1,*" %%s in (%Lst_File%) do (
    if .%%s.==.-. (
        call "%CDir%\7za.exe" d -tzip "%APK_Path%\%APK_Name%.apk" "%%t"
    ) else (
        call "%CDir%\7za.exe" a -tzip -mx%%s "%APK_Path%\%APK_Name%.apk" "%%t"
    )
    if errorlevel 1 (
        popd
        goto :Err
    )
)
popd
goto :EOF

:: Remove certificate(s) and sign APK
:label_Sign

if not exist "%CDir%\..\Sign_APK\Sign.bat" (
    echo "%CDir%\..\Sign_APK\Sign.bat" not found!
    set errorlevel=1
    goto :Err
)

:: Remove previous certs
call "%CDir%\7za.exe" d -tzip "%APK_Path%\%APK_Name%.apk" META-INF\*
if errorlevel 1 goto :Err

:: Sign with our own cert
call "%CDir%\..\Sign_APK\Sign.bat" "%APK_Path%\%APK_Name%.apk"
if errorlevel 1 goto :Err

goto :EOF

:: Remove frameworks
:label_Clean

rd /s/q "%HOMEDRIVE%%HOMEPATH%\apktool\framework" 2> nul

:Err
echo Error occured - process not finished