@echo off
setlocal
set CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo ERROR: csc.exe not found.
  exit /b 1
)
"%CSC%" /nologo /target:winexe /optimize+ /out:AssemblyGame.exe /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll src\Program.cs
if errorlevel 1 exit /b 1
echo Build OK: AssemblyGame.exe
endlocal
