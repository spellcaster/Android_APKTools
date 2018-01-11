:: Script for operations on APK's
:: Requirements:
::   You must have JDK installed and java.exe in PATH
:: Usage:
::   1. Copy all apk files from your device's /system/framework into some folder
::   2. Run APK_worker.bat instfw {framework_folder}
::   3. Run APK_worker.bat {command} [{source}] [{param}]
::   You can use env variables for changing options:
::	 APKW_UseCustomAAPT - use aapt_Custom.exe instead of SDK version

@echo off

:: Not changing calling process' PATH variable
setlocal

set CDir=%~dp0%
IF NOT DEFINED APKW_UseCustomAAPT (
	:: Use aapt from SDK by default
	set AAPT=aapt_SDK.exe
) ELSE (
	:: ! Use ONLY if you have troubles building/decompiling apk's !
	set AAPT=aapt_Custom.exe
)

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

:: ***** Perform operation basing on the parameter given *****

:: No parameters/help parameters - print usage
if .%1%.==.. goto label_Help
if .%1%.==./?. goto label_Help
if .%1%.==.help. goto label_Help

if .%1%.==.instfw. goto label_Install_FW
if .%1%.==.decomp. goto label_Decomp_Full
if .%1%.==.decomp_src. goto label_Decomp_Src
if .%1%.==.decomp_res. goto label_Decomp_Res
if .%1%.==.fixfolders. goto label_FixFolders
if .%1%.==.build. goto label_Build
if .%1%.==.modify. goto label_Modify
if .%1%.==.sign. goto label_Sign
if .%1%.==.pack. goto label_Pack
if .%1%.==.clean. goto label_Clean_FW

:: ***** Actions *****

:: ### Help
:label_Help
	echo Script for main operations with APK
	echo Usage:
	echo APK_Worker.bat {command} [{source}] [{param}]
	echo command:
	echo   help, /? - this text
	echo   instfw - install frameworks (required for building/decompiling only)
	echo	 {source} - path to framework APK
	echo   decomp - full decompile APK (res + source)
	echo	 {source} - APK file
	echo	 {param} - (opt) folder for extracted files. Default: Path({source})\Name({source})\
	echo   decomp_res - decompile APK (res only - faster)
	echo	 {source} - APK file
	echo	 {param} - (opt) folder for extracted files. Default: Path({source})\Name({source})\
	echo   decomp_src - decompile APK (source only)
	echo	 {source} - APK file
	echo	 {param} - (opt) folder for extracted files. Default: Path({source})\Name({source})\
	echo   fixfolders - fix folder names in APK folder that were wrongfully renamed on decompile
	echo	 {source} - APK folder
	echo	 {param} - path to file with rename rules
	echo   build - build temporary files
	echo	 {source} - folder with source files
	echo	 {param} - (opt) path to resulting APK. Default: Path({source})\Name({source})_built.apk
	echo	 Files are built to {source}\build
	echo   modify - add/replace files inside APK
	echo	 {source} - APK file
	echo	 {param} - path to file with modify rules
	echo   pack - pack files to APK
	echo	 {source} - source folder
	echo	 APK is built to {source}\..
	echo   sign - remove certificate and sign the APK {source}
	echo	 {source} - APK file
	echo   clean - remove installed frameworks from %HOMEDRIVE%%HOMEPATH%\apktool\framework
	echo For detailed info, check README file
	pause
	goto :EOF

:: ### (Re)Install framework
:label_Install_FW

	set FW_Path=%~2%

	call java.exe -jar "%CDir%\apktool.jar" if "%FW_Path%" || goto :Err
	
	goto :EOF

:: ### Decompile res and sources
:label_Decomp_Full

	SET Decomp_Param=
	goto label_Decomp

:: ### Decompile res only
:label_Decomp_Res

	SET Decomp_Param=--no-src
	goto label_Decomp

:: ### Decompile src only
:label_Decomp_Src

	SET Decomp_Param=--no-res
	goto label_Decomp

:: ### Do decompile
:label_Decomp

	set APK_Path=%~dp2%
	set APK_Name=%~n2%
	set Output_Path=%~3%
	if .%Output_Path%.==.. set Output_Path=%APK_Path%\%APK_Name%

	rd /s/q "%Output_Path%" 2> nul
	
	:: Decompile
	call java.exe -jar "%CDir%\apktool.jar" d %Decomp_Param% --force -o "%Output_Path%" "%APK_Path%\%APK_Name%.apk" || goto :Err

	goto :EOF

:: ### Do fix folders
:label_FixFolders

	set Src_Path=%~dp2%
	set Lst_File=%~3%
	
	for /f "tokens=1,*" %%s in (%Lst_File%) do (
		ren "%Src_Path%\%%s" "%%t"
	)
	goto :EOF

:: ### Do build
:label_Build

	set Src_Path=%~2%
	set NewAPK_Path=%~3%
	if .%NewAPK_Path%.==.. set NewAPK_Path=%Src_Path%_built.apk

	:: Build
	call java.exe -jar "%CDir%\apktool.jar" b --force-all -o "%NewAPK_Path%" "%Src_Path%" || goto :Err
	
	goto :EOF

:: ### Replace/remove files in APK with files from %3 according to list file %4
:label_Modify

	set APK_FullPath=%~2%
	set Src_Path=%~3%
	set Lst_File=%~4%
	
	:: Changing CD so that 7zip could add/remove files with correct paths
	pushd "%Src_Path%"
	for /f "tokens=1,*" %%s in (%Lst_File%) do (
		if .%%s.==.-. (
			call "%CDir%\7za.exe" d -tzip "%APK_FullPath%" "%%t" || (popd && goto :Err)
		) else (
			call "%CDir%\7za.exe" a -tzip -mx%%s "%APK_FullPath%" "%%t" || (popd && goto :Err)
		)
	)
	popd
	goto :EOF

:: ### Remove certificate(s) and sign APK
:label_Sign

	set APK_FullPath=%~2%

	if not exist "%CDir%\..\Sign_APK\Sign.bat" (
		echo "%CDir%\..\Sign_APK\Sign.bat" not found!
		goto :Err
	)
	
	:: Remove previous certs
	call "%CDir%\7za.exe" d -tzip "%APK_FullPath%" META-INF\* || goto :Err
	
	:: Sign with our own cert
	call "%CDir%\..\Sign_APK\Sign.bat" "%APK_FullPath%" || goto :Err
	
	goto :EOF

:: ### Pack files into APK; *.arsc and *.png files are added with 0 compression
:label_Pack

	set Src_Path=%~2%
	set NewAPK_Path=..\Built.apk
	
	:: changing CD for 7zip to handle relative dirs
	pushd "%Src_Path%"

	del "%NewAPK_Path%" 2> nul
	
	:: Add files with compression
	call "%CDir%\7za.exe" a -tzip -mx5 -r "%NewAPK_Path%" * -x!*.arsc -x!*.png "%Src_Path%"

	:: Add files without compression
	call "%CDir%\7za.exe" a -tzip -mx0 -r "%NewAPK_Path%" *.arsc *.png "%Src_Path%"
	
	popd
	goto :EOF

:: ### Remove frameworks
:label_Clean_FW

	rd /s/q "%HOMEDRIVE%%HOMEPATH%\apktool\framework" 2> nul
	goto :EOF

:Err
echo Error occured - process not finished
exit /b 1