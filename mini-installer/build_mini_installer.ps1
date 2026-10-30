<#
  build_mini_installer.ps1
  Compila el APK de mini-installer usando el SDK de Android Studio local.
  Usa Python (zipfile ZIP_STORED) para reempaquetar: resources.arsc SIN comprimir
  (requerido para targetSdk 30+ en Android 12).
#>

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

$JavaHome = "D:\AndroidStudio\jbr"
$SdkDir   = "D:\AndroidStudioSDK"
$BuildTools = "$SdkDir\build-tools\36.0.0"
$Platform = "$SdkDir\platforms\android-35\android.jar"

$Javac    = "$JavaHome\bin\javac.exe"
$Keytool  = "$JavaHome\bin\keytool.exe"
$Aapt2    = "$BuildTools\aapt2.exe"
$D8       = "$BuildTools\d8.bat"
$Zipalign = "$BuildTools\zipalign.exe"
$Apksigner = "$BuildTools\apksigner.bat"
$Python   = "python3"

$Project  = $PSScriptRoot
$App      = "$Project\app"
$Src      = "$App\src\main"
$BuildDir = "$Project\build"

Write-Host "[*] Limpiando carpeta build..."
if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$BuildDir\res"     | Out-Null
New-Item -ItemType Directory -Force -Path "$BuildDir\classes" | Out-Null
New-Item -ItemType Directory -Force -Path "$BuildDir\dex"     | Out-Null
New-Item -ItemType Directory -Force -Path "$BuildDir\gen"     | Out-Null

Write-Host "[*] 1. Compilando recursos con aapt2 compile --dir..."
& $Aapt2 compile --dir "$Src\res" -o "$BuildDir\res\res.zip"
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile fallo" }

Write-Host "[*] 2. Enlazando recursos y generando AndroidManifest + R.java con aapt2 link..."
& $Aapt2 link -o "$BuildDir/base.apk" -I $Platform --manifest "$Src\AndroidManifest.xml" --java "$BuildDir\gen" --auto-add-overlay "$BuildDir\res\res.zip" --no-resource-deduping --min-sdk-version 21 --target-sdk-version 31 --version-code 1 --version-name "1.0"
if ($LASTEXITCODE -ne 0) { throw "aapt2 link fallo" }

Write-Host "[*] 3. Compilando clases Java con javac..."
$javaFiles = Get-ChildItem -Path "$Src\java" -Recurse -Filter "*.java" | Select-Object -ExpandProperty FullName
$genJavaFiles = Get-ChildItem -Path "$BuildDir\gen" -Recurse -Filter "*.java" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$allJava = @($javaFiles)
if ($genJavaFiles) { $allJava += $genJavaFiles }

# Use -Xlint:-options to suppress obsolete source/target warnings
cmd /c "`"$Javac`" -d `"$BuildDir\classes`" -source 8 -target 8 -bootclasspath `"$Platform`" -Xlint:-options $($allJava -join ' ')"
if ($LASTEXITCODE -ne 0) { throw "javac fallo" }

Write-Host "[*] 4. Convirtiendo bytecode a DEX con d8..."
$classFiles = Get-ChildItem -Path "$BuildDir\classes" -Recurse -Filter "*.class" | Select-Object -ExpandProperty FullName
& $D8 --output "$BuildDir\dex" --lib $Platform $classFiles
if ($LASTEXITCODE -ne 0) { throw "d8 fallo" }

Write-Host "[*] 5. Reempaquetando con Python (resources.arsc SIN comprimir)..."
& $Python "$Project\repack.py" "$BuildDir/base.apk" "$BuildDir/dex/classes.dex" "$BuildDir/unpacked.apk"
if ($LASTEXITCODE -ne 0) { throw "repack fallo" }

Write-Host "[*] 6. Alineando APK con zipalign..."
& $Zipalign -f 4 "$BuildDir/unpacked.apk" "$BuildDir/aligned.apk"
if ($LASTEXITCODE -ne 0) { throw "zipalign fallo" }

Write-Host "[*] 7. Generando keystore de depurado y firmando APK..."
$Keystore = "$Project\keystore\mini.keystore"
New-Item -ItemType Directory -Force -Path "$Project\keystore" | Out-Null
if (-not (Test-Path $Keystore)) {
  cmd /c "`"$Keytool`" -genkey -v -keystore `"$Keystore`" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname `"CN=Android Debug,O=Android,C=US`" > `"$BuildDir\keytool.log`" 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "keytool fallo" }
}

$FinalApk = "D:\mumu-global-debloat\patch\com.mumu.store.apk"
if (-not (Test-Path "D:\mumu-global-debloat\patch")) { New-Item -ItemType Directory -Force -Path "D:\mumu-global-debloat\patch" | Out-Null }

cmd /c "`"$Apksigner`" sign --ks `"$Keystore`" --ks-pass pass:android --out `"$FinalApk`" `"$BuildDir\aligned.apk`" > `"$BuildDir\apksigner.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { throw "apksigner fallo (exit=$LASTEXITCODE): $(Get-Content "$BuildDir\apksigner.log" -Raw)" }

Write-Host "[+] APK compilado con exito!"
Write-Host "[+] Salida: $FinalApk"
Write-Host "    Tamano: $((Get-Item $FinalApk).Length) bytes"