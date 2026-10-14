param(
    [string[]]$Escenas = @('menus', 'partida', 'clasico', 'de_pie', 'raros', 'ute', 'final', 'mostrador', 'explorar'),
    [string]$Godot = '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe',
    [int]$LimiteSimulado = 1200,
    [int]$LimiteProceso = 1800,
    [switch]$Grabar,
    [switch]$AuditarCadaFrame,
    [string]$Resolucion = '1280x720',
    [int]$Semilla = 20261004
)
# Un proceso por escena, sin borrar grabaciones anteriores ni arrancar servidores.
$ErrorActionPreference = 'Stop'
$proyectoRecorrido = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$permitidas = @('menus', 'partida', 'clasico', 'de_pie', 'raros', 'ute', 'final', 'mostrador', 'mostrador_tiempo', 'salidas', 'explorar')
foreach ($escenaRecorrido in $Escenas) {
    if ($escenaRecorrido -notin $permitidas) { throw "Escena local no reconocida: $escenaRecorrido" }
}
if ($LimiteProceso -lt 1 -or $LimiteSimulado -lt 1) { throw 'Los límites deben ser positivos' }
$sesionRecorrido = 'capturas/recorrido_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff')
$salidaRecorrido = Join-Path $proyectoRecorrido $sesionRecorrido
New-Item -ItemType Directory -Path $salidaRecorrido | Out-Null
Set-Content -LiteralPath (Join-Path $salidaRecorrido '.gdignore') -Value ''
$resultadosRecorrido = @()
foreach ($escenaRecorrido in $Escenas) {
    $carpetaRecorrido = Join-Path $salidaRecorrido $escenaRecorrido
    New-Item -ItemType Directory -Path $carpetaRecorrido -Force | Out-Null
    $argsRecorrido = @('--path', ('"' + $proyectoRecorrido + '"'), '--resolution', $Resolucion, '--fixed-fps', '30')
    if ($Grabar) {
        $argsRecorrido += @('--write-movie', ('"' + (Join-Path $carpetaRecorrido 'video.avi') + '"'))
    }
    $argsRecorrido += @('--', '--recorrido', "--escena=$escenaRecorrido", "--limite-recorrido=$LimiteSimulado", "--salida-recorrido=res://$sesionRecorrido")
    if ($AuditarCadaFrame) { $argsRecorrido += '--auditar-cada-frame' }
    $argsRecorrido += "--semilla=$Semilla"
    $procesoRecorrido = $null
    $estadoRecorrido = 'FALLO_LANZADOR'
    $codigoRecorrido = $null
    try {
        Write-Output "INICIO $escenaRecorrido"
        $procesoRecorrido = Start-Process -FilePath $Godot -ArgumentList $argsRecorrido -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $carpetaRecorrido 'log.txt') -RedirectStandardError (Join-Path $carpetaRecorrido 'motor.txt')
        if (-not $procesoRecorrido.WaitForExit($LimiteProceso * 1000)) {
            # El ejecutable console puede crear un hijo Godot; cerrar también ese hijo de esta copia.
            Get-CimInstance Win32_Process -Filter "ParentProcessId=$($procesoRecorrido.Id)" | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine.Contains($proyectoRecorrido) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            # Solo termina el proceso creado para esta escena, nunca otras ventanas.
            Stop-Process -Id $procesoRecorrido.Id -Force
            $procesoRecorrido.WaitForExit()
            $estadoRecorrido = 'TIEMPO_PROCESO_AGOTADO'
        } else {
            $procesoRecorrido.Refresh()
            $codigoRecorrido = $procesoRecorrido.ExitCode
            $resultadoRecorrido = Join-Path $carpetaRecorrido 'resultado_bot.json'
            if ($codigoRecorrido -eq 0 -and (Test-Path -LiteralPath $resultadoRecorrido)) {
                $estadoRecorrido = (Get-Content -LiteralPath $resultadoRecorrido -Raw | ConvertFrom-Json).estado
            } else { $estadoRecorrido = 'PROCESO_INCOMPLETO' }
        }
    } catch {
        Set-Content -LiteralPath (Join-Path $carpetaRecorrido 'fallo_lanzador.txt') -Value $_.Exception.Message
    } finally {
        if ($null -ne $procesoRecorrido) { $procesoRecorrido.Dispose() }
        $motorRecorrido = Join-Path $carpetaRecorrido 'motor.txt'
        if (Test-Path -LiteralPath $motorRecorrido) {
            Get-Content -LiteralPath $motorRecorrido | Add-Content -LiteralPath (Join-Path $carpetaRecorrido 'log.txt')
        }
    }
    $logFinalQA = Get-Content -LiteralPath (Join-Path $carpetaRecorrido 'log.txt') -Raw
    if ($estadoRecorrido -eq 'COMPLETADO' -and $logFinalQA -match 'SCRIPT ERROR:|(?m)^ERROR:') { $estadoRecorrido = 'FALLO_MOTOR' }
    $resultadosRecorrido += [pscustomobject]@{ escena = $escenaRecorrido; estado = $estadoRecorrido; codigo = $codigoRecorrido }
    $resultadosRecorrido | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $salidaRecorrido 'sesion.json')
    Write-Output "FIN $escenaRecorrido : $estadoRecorrido"
}
Write-Output "Evidencias: $salidaRecorrido"
