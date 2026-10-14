param(
 [string]$Godot = '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe',
 [switch]$Grabar,
 [switch]$Local,
 [int]$LimiteProceso = 900,
 [string]$Extra = ''
)
$ErrorActionPreference = 'Stop'
$proyectoQA = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sesionQA = 'capturas/online_cuatro_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff')
$dirQA = Join-Path $proyectoQA $sesionQA
New-Item -ItemType Directory -Path $dirQA | Out-Null
Set-Content -LiteralPath (Join-Path $dirQA '.gdignore') -Value ''
$procesosQA = @()
try {
 for ($rolQA = 0; $rolQA -lt 4; $rolQA++) {
  $cuentaQA = 'qa_recorrido_' + (Split-Path $dirQA -Leaf) + '_' + $rolQA
  $carpetaQA = Join-Path $dirQA ('cliente_' + $rolQA)
  New-Item -ItemType Directory -Path $carpetaQA | Out-Null
  $argsQA = @('--path', ('"' + $proyectoQA + '"'), '--resolution', '960x540', '--log-file', ('"' + (Join-Path $carpetaQA 'godot.log') + '"'))
  if ($Grabar) { $argsQA += @('--fixed-fps', '30', '--write-movie', ('"' + (Join-Path $carpetaQA 'video.avi') + '"')) }
  $argsQA += @('--') + $(if ($Local) { @('--local') } else { @() }) + @('--recorrido', '--escena=online_cuatro', '--auditar-cada-frame', "--rol-recorrido=$rolQA", "--cuenta=$cuentaQA", "--codigo-recorrido=res://$sesionQA/codigo.txt", "--salida-recorrido=res://$sesionQA/cliente_$rolQA") + $(if ($Extra) { $Extra.Split(' ') } else { @() })
  $procesosQA += Start-Process -FilePath $Godot -ArgumentList $argsQA -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $carpetaQA 'log.txt') -RedirectStandardError (Join-Path $carpetaQA 'motor.txt')
 }
 $inicioQA = Get-Date
 while (($procesosQA | Where-Object { -not $_.HasExited }).Count -gt 0 -and ((Get-Date)-$inicioQA).TotalSeconds -lt $LimiteProceso) { Start-Sleep -Seconds 1 }
 foreach ($iQA in 0..3) {
  $carpetaQA = Join-Path $dirQA ('cliente_' + $iQA)
  $artefactosQA = Join-Path $carpetaQA 'online_cuatro'
  if (Test-Path -LiteralPath $artefactosQA) { Get-ChildItem -LiteralPath $artefactosQA -File | Copy-Item -Destination $carpetaQA }
  Get-Content -LiteralPath (Join-Path $carpetaQA 'motor.txt') | Add-Content -LiteralPath (Join-Path $carpetaQA 'log.txt')
 }
 foreach ($pQA in $procesosQA) {  }
} finally {
 foreach ($pQA in $procesosQA) {
  if (-not $pQA.HasExited) {
   Get-CimInstance Win32_Process -Filter "ParentProcessId=$($pQA.Id)" | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine.Contains($proyectoQA) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
   Stop-Process -Id $pQA.Id -Force -ErrorAction SilentlyContinue
  }
  $pQA.Dispose()
 }
}
Write-Output "Evidencias: $dirQA"
