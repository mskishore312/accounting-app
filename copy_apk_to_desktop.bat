@echo off
echo Copying Release APK to Desktop...
copy "build\app\outputs\flutter-apk\app-release.apk" "%USERPROFILE%\Desktop\accounting_app.apk"
echo APK copied to Desktop as 'accounting_app.apk'
pause
