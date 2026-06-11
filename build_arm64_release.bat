@echo off
setlocal EnableExtensions

chcp 65001 >nul
cd /d "%~dp0"

set "KEYSTORE=android\app\aigen-release.p12"
set "OLD_KEYSTORE=android\app\aigen-release.jks"
set "KEY_PROPERTIES=android\key.properties"
set "KEY_ALIAS=aigen-release"
set "STORE_PASSWORD=aigen_release_2026"
set "KEY_PASSWORD=aigen_release_2026"
set "OBFUSCATION_DIR=%CD%\build\app\outputs\symbols"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter was not found in PATH.
  exit /b 1
)

if exist "%OLD_KEYSTORE%" (
  echo [INFO] Removing old JKS keystore. PKCS12 will be used instead.
  del /f /q "%OLD_KEYSTORE%"
)

if not exist "%KEYSTORE%" (
  echo [INFO] Release keystore not found. Creating %KEYSTORE%
  where keytool >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] keytool was not found in PATH. Install/use a JDK and try again.
    exit /b 1
  )

  keytool -genkeypair -keystore "%KEYSTORE%" -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias "%KEY_ALIAS%" -storepass "%STORE_PASSWORD%" -keypass "%KEY_PASSWORD%" -dname "CN=AI Gen, OU=Release, O=AI Gen, L=Unknown, S=Unknown, C=CN" >nul
  if errorlevel 1 exit /b 1

  > "%KEY_PROPERTIES%" echo storePassword=%STORE_PASSWORD%
  >> "%KEY_PROPERTIES%" echo keyPassword=%KEY_PASSWORD%
  >> "%KEY_PROPERTIES%" echo keyAlias=%KEY_ALIAS%
  >> "%KEY_PROPERTIES%" echo storeFile=app/aigen-release.p12

  echo [INFO] Created %KEY_PROPERTIES%
) else (
  if not exist "%KEY_PROPERTIES%" (
    echo [ERROR] %KEYSTORE% exists but %KEY_PROPERTIES% is missing.
    echo [ERROR] Create android\key.properties with storePassword, keyPassword, keyAlias, storeFile.
    exit /b 1
  )
)

echo [INFO] Cleaning previous Android release outputs...
if exist "build\app\outputs\flutter-apk" rmdir /s /q "build\app\outputs\flutter-apk"
if exist "%OBFUSCATION_DIR%" rmdir /s /q "%OBFUSCATION_DIR%"
if exist "build\image_gallery_saver_plus\kotlin" rmdir /s /q "build\image_gallery_saver_plus\kotlin"
if exist "build\shared_preferences_android\kotlin" rmdir /s /q "build\shared_preferences_android\kotlin"

echo [INFO] Building arm64-v8a release APK with Dart AOT obfuscation...
call flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info="%OBFUSCATION_DIR%" --no-tree-shake-icons
if errorlevel 1 exit /b 1

echo.
echo [OK] APK:
echo build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo.
echo [OK] Obfuscation symbols:
echo %OBFUSCATION_DIR%

endlocal
