@echo off
setlocal
set APP_HOME=%~dp0

REM Use a project-local Gradle user home so android\.gradle\init.d scripts are loaded.
IF "%GRADLE_USER_HOME%"=="" (
  set GRADLE_USER_HOME=%APP_HOME%\.gradle
)

set WRAPPER_JAR=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar
if not exist "%WRAPPER_JAR%" (
  echo gradle-wrapper.jar not found, downloading...
  if not exist "%APP_HOME%\gradle\wrapper" mkdir "%APP_HOME%\gradle\wrapper"
  set WRAPPER_URL=https://raw.githubusercontent.com/gradle/gradle/v8.11.1/gradle/wrapper/gradle-wrapper.jar
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { (New-Object Net.WebClient).DownloadFile('%WRAPPER_URL%', '%WRAPPER_JAR%') } catch { Write-Host 'Download failed: ' $_.Exception.Message; exit 1 }"
  if not exist "%WRAPPER_JAR%" (
    echo Failed to download gradle-wrapper.jar
    exit /b 1
  )
)
set JAVA_EXE=%JAVA_HOME%\bin\java.exe
if not exist "%JAVA_EXE%" set JAVA_EXE=java

REM Always load the project-local init script to enforce repository mirrors.
set INIT_SCRIPT=%APP_HOME%\.gradle\init.d\00_repo_mirrors.gradle
if exist "%INIT_SCRIPT%" (
  "%JAVA_EXE%" -Dorg.gradle.appname=gradlew -classpath "%WRAPPER_JAR%" org.gradle.wrapper.GradleWrapperMain --init-script "%INIT_SCRIPT%" %*
) else (
  "%JAVA_EXE%" -Dorg.gradle.appname=gradlew -classpath "%WRAPPER_JAR%" org.gradle.wrapper.GradleWrapperMain %*
)
