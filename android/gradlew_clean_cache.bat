@echo off
echo Cleaning Flutter and Gradle caches...

echo.
echo Step 1: Cleaning Flutter build...
cd /d "%~dp0\.."
call flutter clean

echo.
echo Step 2: Cleaning Gradle cache...
cd android
call gradlew clean --no-daemon

echo.
echo Step 3: Removing Gradle cache directory...
if exist "%USERPROFILE%\.gradle\caches" (
    echo Removing Gradle caches...
    rmdir /s /q "%USERPROFILE%\.gradle\caches"
    echo Gradle cache removed.
) else (
    echo Gradle cache directory not found.
)

echo.
echo Step 3b: Removing Gradle kotlin-dsl cache...
if exist "%USERPROFILE%\.gradle\caches\8.14\kotlin-dsl" (
    echo Removing kotlin-dsl cache...
    rmdir /s /q "%USERPROFILE%\.gradle\caches\8.14\kotlin-dsl"
    echo kotlin-dsl cache removed.
) else (
    echo kotlin-dsl cache directory not found.
)

echo.
echo Step 3c: Removing all Gradle cache (full clean)...
if exist "%USERPROFILE%\.gradle\caches" (
    echo Removing ALL Gradle caches...
    rmdir /s /q "%USERPROFILE%\.gradle\caches"
    echo All Gradle cache removed.
)

echo.
echo Step 4: Cleaning Flutter pub cache...
cd /d "%~dp0\.."
call flutter pub cache repair

echo.
echo Done! Now try building again:
echo   flutter pub get
echo   flutter build apk --release

pause

