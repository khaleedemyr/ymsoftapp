@echo off
echo ========================================
echo FIX GRADLE CACHE ERROR
echo ========================================
echo.

echo Step 1: Stopping Gradle daemon...
cd /d "%~dp0"
call gradlew --stop

echo.
echo Step 2: Removing kotlin-dsl cache...
if exist "%USERPROFILE%\.gradle\caches\8.14\kotlin-dsl" (
    echo Removing kotlin-dsl cache...
    rmdir /s /q "%USERPROFILE%\.gradle\caches\8.14\kotlin-dsl"
    echo kotlin-dsl cache removed.
) else (
    echo kotlin-dsl cache directory not found.
)

echo.
echo Step 3: Removing ALL Gradle caches (recommended)...
if exist "%USERPROFILE%\.gradle\caches" (
    echo WARNING: This will remove ALL Gradle caches!
    echo Press Ctrl+C to cancel, or
    pause
    echo Removing ALL Gradle caches...
    rmdir /s /q "%USERPROFILE%\.gradle\caches"
    echo All Gradle cache removed.
) else (
    echo Gradle cache directory not found.
)

echo.
echo Step 4: Cleaning Flutter build...
cd /d "%~dp0\.."
call flutter clean

echo.
echo Step 5: Cleaning Android build...
cd android
call gradlew clean --no-daemon

echo.
echo Step 6: Getting Flutter dependencies...
cd /d "%~dp0\.."
call flutter pub get

echo.
echo ========================================
echo Done! Now try building:
echo   flutter build apk --release
echo ========================================
pause

