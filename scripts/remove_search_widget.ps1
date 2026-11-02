<#
  remove_search_widget.ps1
  Elimina la lupa/buscador "Buscar juegos" del launcher de MuMu.
  Deshabilita componentes de Play Store relacionados con widgets de búsqueda
  y aplica settings para desactivar sugerencias.
#>

$AdbExe = "D:\MuMuPlayerGlobal-12.0\nx_main\adb.exe"
$port = "16416"

Write-Host "=== Eliminando lupa/buscador 'Buscar juegos' ===" -ForegroundColor Cyan

# 1. Deshabilitar widgets de Play Store (Rubik's Cubes)
Write-Host "`n[1/3] Deshabilitando widgets de Play Store..."
$widgets = @(
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.GamesWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.WatchWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.ReadWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.ListenWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.ShoppingWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.FoodWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.SocialWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.personalized.TravelWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.CubesAppWidgetProvider",
    "com.android.vending/com.google.android.finsky.rubiks.cubes.widget.ContentForwardWidgetProvider",
    "com.android.vending/com.google.android.finsky.dsehelper.SearchWidgetDseChangeBroadcastReceiver"
)
foreach ($w in $widgets) {
    & $AdbExe -s "127.0.0.1:$port" shell "/system/xbin/su -c 'pm disable $w'" 2>&1 | Out-Null
    Write-Host "  OK: $w"
}

# 2. Deshabilitar RecentSuggestionsProvider
Write-Host "`n[2/3] Deshabilitando sugerencias recientes..."
& $AdbExe -s "127.0.0.1:$port" shell "/system/xbin/su -c 'pm disable com.android.vending/com.google.android.finsky.searchsuggestions.RecentSuggestionsProvider'" 2>&1 | Out-Null
Write-Host "  OK: RecentSuggestionsProvider disabled"

# 3. Settings globales para desactivar búsqueda/asistente
Write-Host "`n[3/3] Aplicando settings anti-búsqueda..."
& $AdbExe -s "127.0.0.1:$port" shell "settings put secure show_search_app_suggestions 0" | Out-Null
& $AdbExe -s "127.0.0.1:$port" shell "settings put global search_assist_enabled 0" | Out-Null
& $AdbExe -s "127.0.0.1:$port" shell "settings put secure assistant_enabled 0" | Out-Null
& $AdbExe -s "127.0.0.1:$port" shell "settings put secure overlay_display_devices null" | Out-Null
Write-Host "  OK: Settings aplicados"

Write-Host "`n=== LISTO ===" -ForegroundColor Green
Write-Host "Reinicia el launcher o la VM para que los cambios surtan efecto."
Write-Host "Si la lupa persiste, puede ser parte del launcher de MuMu (no de Play Store)."