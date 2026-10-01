<#
vscode-setup · desinstalador para Windows

Deshace lo que hizo install.ps1 y nada más:
  · cada ajuste vuelve al valor que tenía antes (los que hayas cambiado
    después de instalar se quedan como los dejaste);
  · se desinstalan solo las extensiones que instaló el instalador, no las
    que ya tenías.
Las copias de seguridad no se borran.

Uso, desde PowerShell y dentro de la carpeta del repositorio:

    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -Simular
#>
[CmdletBinding()]
param(
    [switch]$Simular,
    [Alias('h')]
    [switch]$Ayuda
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
. (Join-Path (Join-Path $raiz 'scripts') 'lib.ps1')

if ($Ayuda) {
    Write-Host @'
vscode-setup · desinstalador para Windows

Uso: powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 [opciones]

Devuelve los ajustes a como estaban y desinstala las extensiones que puso el
instalador (las que ya tenías se quedan).

Opciones:
  -Simular   Muestra lo que haría, sin cambiar nada.
  -Ayuda     Muestra esta ayuda.

Usa las mismas variables VSCODE_BIN y VSCODE_USER_DIR que el instalador.
'@
    exit 0
}

$editor = Get-Editor
if (-not $editor) {
    Write-Fallo "No encuentro el comando 'code'."
    Write-Detalle 'Si usas otro editor (VSCodium, Cursor...), indícalo: $env:VSCODE_BIN = "codium"'
    exit 1
}
$carpetaUsuario = Get-CarpetaUsuario $editor
if (-not $carpetaUsuario) {
    Write-Fallo "No sé dónde guarda sus ajustes '$editor'."
    Write-Detalle 'Indícalo así: $env:VSCODE_USER_DIR = "C:\ruta\a\la\carpeta\User"'
    exit 1
}

$settings = Join-Path $carpetaUsuario 'settings.json'
$carpetaEstado = Join-Path $carpetaUsuario 'vscode-setup'
$carpetaCopias = Join-Path $carpetaEstado 'copias'
$estadoAjustes = Join-Path $carpetaEstado 'ajustes-anteriores.json'
$estadoExtensiones = Join-Path $carpetaEstado 'extensiones-instaladas.txt'
$fallos = 0

Write-Host 'vscode-setup · desinstalador' -ForegroundColor White
Write-Detalle "Editor:  $editor"
Write-Detalle "Ajustes: $settings"
if ($Simular) { Write-Detalle 'Modo simulación: no se cambia nada.' }

if (-not (Test-Path -LiteralPath $carpetaEstado)) {
    Write-Titulo 'No hay nada que desinstalar.'
    Write-Detalle "No encuentro una instalación de vscode-setup en $carpetaUsuario"
    exit 0
}

# ¿Se llegó a configurar el fondo? Entonces Custom UI Style pudo modificar los
# archivos de VS Code y hay que tratarla aparte.
$nuestras = Get-ListaExtensiones $estadoExtensiones
$teniaFondo = $nuestras -contains $ExtensionFondo
if ((Test-Path -LiteralPath $estadoAjustes) -and
    ([System.IO.File]::ReadAllText($estadoAjustes) -like '*custom-ui-style*')) {
    $teniaFondo = $true
}

# ── 1. Ajustes ───────────────────────────────────────────────────────────────

Write-Titulo '[1/2] Ajustes de VS Code'
try {
    [void](Invoke-RevertirAjustes -Settings $settings -Estado $estadoAjustes `
            -Copias $carpetaCopias -Simular ([bool]$Simular))
    if (-not $Simular) { Write-Bien "Ajustes en $settings" }
}
catch {
    Write-Tenue "$($_.Exception.Message)"
    Write-Fallo 'No se pudieron revertir los ajustes; tu settings.json quedó como estaba.'
    $fallos++
}

# ── 2. Extensiones ───────────────────────────────────────────────────────────

Write-Titulo '[2/2] Extensiones'
if ($teniaFondo) {
    # Custom UI Style hace falta para devolver VS Code a su estado original,
    # así que no se desinstala aquí (se explica al final).
    $nuestras = @($nuestras | Where-Object { $_ -ne $ExtensionFondo })
}
$instaladas = Get-Instaladas $editor
$quitar = @($nuestras | Where-Object { $instaladas -contains $_.ToLowerInvariant() })

if (-not (Test-Path -LiteralPath $estadoExtensiones)) {
    Write-Bien 'El instalador no había añadido ninguna extensión'
}
elseif ($quitar.Count -eq 0) {
    Write-Bien 'No queda instalada ninguna extensión de las que añadió el instalador'
    if (-not $Simular) { Remove-Item -LiteralPath $estadoExtensiones -Force }
}
elseif ($Simular) {
    Write-Paso "Extensiones que se desinstalarían: $($quitar.Count)"
    foreach ($id in $quitar) { Write-Tenue $id }
}
else {
    Write-Paso "Extensiones por desinstalar: $($quitar.Count)"
    $argumentos = @()
    foreach ($id in $quitar) {
        $argumentos += '--uninstall-extension'
        $argumentos += $id
    }
    Invoke-Editor $editor $argumentos

    $instaladas = Get-Instaladas $editor
    $restantes = @($quitar | Where-Object { $instaladas -contains $_.ToLowerInvariant() })
    if ($restantes.Count -eq 0) {
        Write-Bien "Extensiones desinstaladas: $($quitar.Count)"
        Remove-Item -LiteralPath $estadoExtensiones -Force
    }
    else {
        Write-Bien "Extensiones desinstaladas: $($quitar.Count - $restantes.Count)"
        Write-Fallo "Extensiones que no se pudieron desinstalar: $($restantes.Count)"
        foreach ($id in $restantes) { Write-Tenue $id }
        Write-Detalle 'Quítalas desde el panel de extensiones o vuelve a ejecutar uninstall.ps1'
        # Se deja apuntado lo que falta para que un segundo intento lo retome.
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($estadoExtensiones, [string[]]$restantes, $utf8)
        $fallos++
    }
}

if ($Simular) {
    Write-Titulo 'Simulación terminada: no se cambió nada.'
    exit 0
}

# ── Limpieza y qué sigue ─────────────────────────────────────────────────────

$carpetaFondos = Join-Path $carpetaEstado 'fondos'
if (Test-Path -LiteralPath $carpetaFondos) {
    Remove-Item -LiteralPath $carpetaFondos -Recurse -Force
}
if (-not (Get-ChildItem -LiteralPath $carpetaEstado -Force)) {
    Remove-Item -LiteralPath $carpetaEstado -Force
}

if ($fallos -eq 0) {
    Write-Titulo 'Listo. Qué sigue:'
}
else {
    Write-Titulo 'Terminado con problemas (los marcados con [X]). Qué sigue:'
}
Write-Detalle '· En VS Code pulsa Ctrl+Shift+P y ejecuta "Developer: Reload Window".'
if ($teniaFondo) {
    Write-Detalle '· La extensión Custom UI Style sigue instalada a propósito. Si llegaste a activar'
    Write-Detalle '  el fondo, ejecuta primero "Custom UI Style: Rollback" en VS Code para devolverlo'
    Write-Detalle '  a su estado original, y después desinstálala desde el panel de extensiones.'
}
if (Test-Path -LiteralPath $carpetaCopias) {
    Write-Detalle "· Las copias de seguridad siguen en $carpetaCopias"
}

if ($fallos -ne 0) { exit 1 }
