@ECHO off
SETLOCAL

REM Run this from the Setup folder, every path below is relative to it. SETLOCAL keeps the
REM directory change from leaking back into the calling shell, and the ECHO off above covers
REM the whole script instead of starting one line too late.
cd ..\src

cls

FOR /d /r . %%d in (bin,obj) DO (
	IF EXIST "%%d" (
		ECHO %%d | FIND /I "\node_modules\" > Nul && (
			ECHO.Skipping: %%d
		) || (
			ECHO.Deleting: %%d
			rd /s/q "%%d"
		)
	)
)

ECHO.Publishing self contained for win-x64...
cd SSHServerShutdown
dotnet publish -c Release -r win-x64 --self-contained true -o bin/publish
IF ERRORLEVEL 1 GOTO :publishfailed

ECHO.Deleting *.pdb files...
del /q bin\publish\*.pdb > Nul 2>&1

REM The published Config.xml goes into the installer, so it has to be the placeholder one.
REM Whoever put a real server and a real password in there while testing would otherwise
REM hand those credentials to everyone who downloads the setup.
FINDSTR /C:"202.202.202.202" bin\publish\Config.xml > Nul || GOTO :configleak
FINDSTR /C:"DeinPasswortStehen" bin\publish\Config.xml > Nul || GOTO :configleak

ECHO.Build successful. Press any key to exit.
pause
EXIT /B 0

:publishfailed
ECHO.
ECHO.ERROR: dotnet publish failed, no installer content was produced.
pause
EXIT /B 1

:configleak
ECHO.
ECHO.ERROR: Config.xml is missing or does not hold the placeholder server and password
ECHO.any more. Building the installer now would ship those credentials to every user.
ECHO.Restore it with: git checkout -- src/SSHServerShutdown/Config.xml
rd /s/q bin\publish
pause
EXIT /B 1