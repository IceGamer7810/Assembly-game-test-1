@echo off
setlocal
cd /d "%~dp0"
set ASM=tools\FASM.EXE
if not exist "%ASM%" (
  echo ERROR: tools\FASM.EXE not found.
  exit /b 1
)
"%ASM%" game.asm AssemblyGame.exe
if errorlevel 1 exit /b 1
echo Build OK: AssemblyGame.exe
endlocal
