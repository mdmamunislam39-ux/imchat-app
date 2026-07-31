@echo off
echo ===================================================
echo     GETX COMPATIBILITY & CLEANUP SCRIPT
echo ===================================================
echo.

echo [1/5] Cleaning Flutter build artifacts...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [WARNING] flutter clean encountered some issues. Continuing...
)

echo.
echo [2/5] Deleting pubspec.lock...
if exist pubspec.lock (
    del /f /q pubspec.lock
    echo   - pubspec.lock deleted successfully.
) else (
    echo   - pubspec.lock not found or already deleted.
)

echo.
echo [3/5] Deleting .dart_tool folder...
if exist .dart_tool (
    rmdir /s /q .dart_tool
    echo   - .dart_tool folder deleted successfully.
) else (
    echo   - .dart_tool folder not found or already deleted.
)

echo.
echo [4/5] Running flutter pub get...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo.
    echo [!] flutter pub get failed. Attempting to repair pub cache...
    echo [4.5/5] Repairing pub cache (this might take a few minutes)...
    call flutter pub cache repair
    
    echo.
    echo [4.6/5] Retrying flutter pub get...
    call flutter pub get
)

echo.
echo [5/5] Verification: Analyzing project for compile errors...
call flutter analyze
if %ERRORLEVEL% neq 0 (
    echo.
    echo [!] flutter analyze reported warnings/errors. Please check them.
) else (
    echo.
    echo [SUCCESS] Project is clean and compiles without errors!
)

echo.
echo ===================================================
echo     DONE! You can now start the app with:
echo     flutter run
echo ===================================================
pause
