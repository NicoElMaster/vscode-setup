<#
vscode-setup · instalador para Windows

Aplica los ajustes de config\settings.json encima de los que ya tengas (con
copia de seguridad) e instala las extensiones de extensiones.txt. El fondo y
la fuente de la interfaz son opcionales: -Fondo.

Se puede ejecutar las veces que haga falta: solo hace lo que falte.
Para deshacerlo, uninstall.ps1.

Uso, desde PowerShell y dentro de la carpeta del repositorio:

    powershell -ExecutionPolicy Bypass -File .\install.ps1
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Ayuda
#>
[CmdletBinding()]
param(
    [switch]$Fondo,
    [string]$Imagen,
    [switch]$Todo,
    [switch]$Terminal,
    [switch]$Simular,
    [Alias('h')]
    [switch]$Ayuda
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
. (Join-Path (Join-Path $raiz 'scripts') 'lib.ps1')

if ($Ayuda) {
    Write-Host @'
vscode-setup · instalador para Windows

Uso: powershell -ExecutionPolicy Bypass -File .\install.ps1 [opciones]

Sin opciones aplica los ajustes visuales e instala las 38 extensiones básicas.
Tus ajustes actuales se conservan y antes de tocarlos se guarda una copia.

Opciones:
  -Fondo          Además prepara la imagen de fondo y la fuente de la interfaz
                  con Custom UI Style. Termina con un paso manual.
  -Imagen RUTA    Como -Fondo, pero con tu propia imagen.
  -Todo           En Windows equivale a -Fondo.
  -Simular        Muestra lo que haría, sin cambiar nada.
  -Ayuda          Muestra esta ayuda.

Variables de entorno:
  VSCODE_BIN       Comando del editor. Por defecto "code"; también se reconocen
                   code-insiders, codium y cursor.
  VSCODE_USER_DIR  Carpeta "User" del editor, si no está en el lugar habitual.

La parte de terminal (Starship, bat y eza) es solo para Linux y macOS.
Para deshacerlo todo: uninstall.ps1
'@
    exit 0
}

$conFondo = $Fondo -or $Todo -or [bool]$Imagen
if ($Imagen) {
    if (-not (Test-Path -LiteralPath $Imagen -PathType Leaf)) {
        Write-Fallo "No existe la imagen: $Imagen"
        exit 1
    }
    # Ruta completa: las funciones de .NET no usan la carpeta actual de PowerShell.
    $Imagen = (Resolve-Path -LiteralPath $Imagen).ProviderPath
}

$editor = Get-Editor
if (-not $editor) {
    Write-Fallo "No encuentro el comando 'code'."
    Write-Detalle 'Cierra PowerShell y vuelve a abrirlo. Si sigue sin aparecer, reinstala VS Code'
    Write-Detalle 'dejando marcada la casilla "Agregar a PATH".'
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
# Todo lo que el instalador necesita recordar vive aquí, junto a los ajustes.
$carpetaEstado = Join-Path $carpetaUsuario 'vscode-setup'
$carpetaCopias = Join-Path $carpetaEstado 'copias'
$estadoAjustes = Join-Path $carpetaEstado 'ajustes-anteriores.json'
$estadoExtensiones = Join-Path $carpetaEstado 'extensiones-instaladas.txt'
$config = Join-Path $raiz 'config'
$fallos = 0

Write-Host 'vscode-setup · instalador' -ForegroundColor White
Write-Detalle "Editor:  $editor"
Write-Detalle "Ajustes: $settings"
if ($Simular) { Write-Detalle 'Modo simulación: no se cambia nada.' }
if ($Terminal) {
    Write-Aviso 'La parte de terminal es solo para Linux y macOS; aquí se omite.'
}

# ── 1. Ajustes ───────────────────────────────────────────────────────────────
# Van antes que las extensiones: así, cuando una extensión se activa por
# primera vez, ya encuentra su configuración (por ejemplo, Background nace
# apagada en vez de ofrecer aplicar sus imágenes de muestra).

Write-Titulo '[1/3] Ajustes de VS Code'
$archivos = @((Join-Path $config 'settings.json'))
$extra = $null
if ($conFondo) {
    $origen = $Imagen
    if (-not $origen) {
        $origen = Join-Path (Join-Path (Join-Path $raiz 'assets') 'fondos') 'kde-next-oscuro.jpg'
    }
    $carpetaFondos = Join-Path $carpetaEstado 'fondos'
    $destino = Join-Path $carpetaFondos (Split-Path -Leaf $origen)
    if ($Simular) {
        Write-Paso "Se copiaría la imagen de fondo a $destino"
    }
    else {
        New-Item -ItemType Directory -Force -Path $carpetaFondos | Out-Null
        Copy-Item -LiteralPath $origen -Destination $destino -Force
        Write-Bien "Imagen de fondo en $destino"
    }
    # Custom UI Style necesita la dirección completa de la imagen, que depende
    # de cada equipo; por eso no está en settings-fondo.json.
    $archivos += (Join-Path $config 'settings-fondo.json')
    $extra = @{ 'custom-ui-style.background.url' = (Get-UriArchivo $destino) }
}

try {
    [void](Invoke-AplicarAjustes -Settings $settings -Estado $estadoAjustes -Archivos $archivos `
            -Extra $extra -Copias $carpetaCopias -Simular ([bool]$Simular))
    if (-not $Simular) { Write-Bien "Ajustes en $settings" }
}
catch {
    Write-Tenue "$($_.Exception.Message)"
    Write-Fallo 'No se pudieron aplicar los ajustes; tu settings.json quedó como estaba.'
    Write-Detalle 'Puedes copiarlos a mano: docs\instalacion-manual.md'
    $fallos++
}

# ── 2. Extensiones ───────────────────────────────────────────────────────────

Write-Titulo '[2/3] Extensiones'
$deseadas = Get-ListaExtensiones (Join-Path $raiz 'extensiones.txt')
if ($conFondo) {
    $deseadas += Get-ListaExtensiones (Join-Path $raiz 'extensiones-fondo.txt')
}
$instaladas = Get-Instaladas $editor
$faltan = @($deseadas | Where-Object { $instaladas -notcontains $_.ToLowerInvariant() })
$yaEstaban = $deseadas.Count - $faltan.Count

if ($faltan.Count -eq 0) {
    Write-Bien "Las $($deseadas.Count) extensiones ya estaban instaladas"
}
elseif ($Simular) {
    Write-Paso "Extensiones que se instalarían: $($faltan.Count) (ya instaladas: $yaEstaban)"
    foreach ($id in $faltan) { Write-Tenue $id }
}
else {
    Write-Paso "Extensiones por instalar: $($faltan.Count) (ya instaladas: $yaEstaban). Puede tardar unos minutos..."
    $argumentos = @()
    foreach ($id in $faltan) {
        $argumentos += '--install-extension'
        $argumentos += $id
    }
    # El resultado no se juzga por lo que diga el editor, sino comprobando
    # después qué quedó instalado de verdad.
    Invoke-Editor $editor $argumentos

    $instaladas = Get-Instaladas $editor
    $fallidas = @($faltan | Where-Object { $instaladas -notcontains $_.ToLowerInvariant() })
    $nuevas = @($faltan | Where-Object { $fallidas -notcontains $_ })

    # Se apunta qué instaló este script para que uninstall.ps1 quite solo eso
    # y no las extensiones que la persona ya tenía.
    if ($nuevas.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path $carpetaEstado | Out-Null
        $apuntadas = Get-ListaExtensiones $estadoExtensiones
        $todas = @($apuntadas) + @($nuevas | Where-Object { $apuntadas -notcontains $_ })
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($estadoExtensiones, [string[]]$todas, $utf8)
    }

    if ($fallidas.Count -eq 0) {
        Write-Bien "Extensiones nuevas: $($faltan.Count). Ya están las $($deseadas.Count)."
    }
    else {
        Write-Bien "Extensiones nuevas: $($nuevas.Count)"
        Write-Fallo "Extensiones que no se pudieron instalar: $($fallidas.Count)"
        foreach ($id in $fallidas) { Write-Tenue $id }
        Write-Detalle 'Revisa tu conexión y vuelve a ejecutar el instalador: solo reintentará estas.'
        $fallos++
    }
}

# ── 3. Fuente ────────────────────────────────────────────────────────────────

Write-Titulo '[3/3] Fuente'
if (Test-Fuente) {
    Write-Bien 'La fuente JetBrainsMono Nerd Font está instalada'
}
else {
    Write-Aviso 'No encuentro la fuente JetBrainsMono Nerd Font.'
    Write-Detalle 'Todo funciona sin ella, pero no verás las ligaduras ni los iconos de la terminal.'
    Write-Detalle 'Descarga "JetBrainsMono" de https://www.nerdfonts.com/font-downloads,'
    Write-Detalle 'descomprime, selecciona los archivos .ttf, clic derecho y "Instalar".'
}

# ── Qué sigue ────────────────────────────────────────────────────────────────

if ($Simular) {
    Write-Titulo 'Simulación terminada: no se cambió nada.'
    exit 0
}

if ($fallos -eq 0) {
    Write-Titulo 'Listo. Qué sigue:'
}
else {
    Write-Titulo 'Terminado con problemas (los marcados con [X]). Qué sigue:'
}
$n = 1
Write-Detalle "$n. En VS Code pulsa Ctrl+Shift+P y ejecuta ""Developer: Reload Window""."
$n++
if ($conFondo) {
    Write-Detalle "$n. Para activar el fondo y la fuente de la interfaz:"
    if ($editor -like '*Program Files*') {
        Write-Detalle '   · VS Code está instalado para todos los usuarios: ciérralo y ábrelo'
        Write-Detalle '     con clic derecho, "Ejecutar como administrador".'
    }
    Write-Detalle '   · En VS Code: Ctrl+Shift+P -> "Custom UI Style: Reload" y acepta el reinicio.'
    Write-Detalle '   VS Code avisará de que la instalación "parece dañada": es lo esperado.'
    Write-Detalle '   Hay que repetirlo tras cada actualización de VS Code. Más en docs\fondo-y-fuente.md'
    $n++
}
Write-Detalle "$n. Si quieres volver atrás: powershell -ExecutionPolicy Bypass -File .\uninstall.ps1"

if ($fallos -ne 0) { exit 1 }
