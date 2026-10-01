# Funciones compartidas por install.ps1 y uninstall.ps1. No se ejecuta solo.
#
# Está escrito para Windows PowerShell 5.1 (el que trae Windows) y también
# funciona en PowerShell 7. Por eso evita lo que solo existe en la versión 7:
# operadores ?: y ??, ConvertFrom-Json -AsHashtable, Join-Path con tres rutas.

$ExtensionFondo = 'subframe7536.custom-ui-style'

# ── Mensajes ─────────────────────────────────────────────────────────────────

function Write-Titulo([string]$Texto) {
    Write-Host ''
    Write-Host $Texto -ForegroundColor White
}

function Write-Bien([string]$Texto) {
    Write-Host '  [OK] ' -ForegroundColor Green -NoNewline
    Write-Host $Texto
}

function Write-Aviso([string]$Texto) {
    Write-Host '  [!]  ' -ForegroundColor Yellow -NoNewline
    Write-Host $Texto
}

function Write-Fallo([string]$Texto) {
    Write-Host '  [X]  ' -ForegroundColor Red -NoNewline
    Write-Host $Texto
}

function Write-Paso([string]$Texto) {
    Write-Host '  ->   ' -ForegroundColor Cyan -NoNewline
    Write-Host $Texto
}

function Write-Detalle([string]$Texto) {
    Write-Host "       $Texto"
}

function Write-Tenue([string]$Texto) {
    Write-Host "       $Texto" -ForegroundColor DarkGray
}

# ── Detección del sistema y del editor ───────────────────────────────────────

function Test-EsWindows {
    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

# Ruta del comando del editor, o $null si no está en el PATH.
function Get-Editor {
    $nombre = $env:VSCODE_BIN
    if (-not $nombre) { $nombre = 'code' }
    $comando = Get-Command $nombre -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $comando) { return $null }
    if ($comando.Source) { return $comando.Source }
    return $nombre
}

# Carpeta "User" del editor, o $null si no se reconoce el editor.
function Get-CarpetaUsuario([string]$Editor) {
    if ($env:VSCODE_USER_DIR) { return $env:VSCODE_USER_DIR }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Editor).ToLowerInvariant()
    switch ($base) {
        'code'          { $nombre = 'Code' }
        'code-insiders' { $nombre = 'Code - Insiders' }
        'codium'        { $nombre = 'VSCodium' }
        'cursor'        { $nombre = 'Cursor' }
        default         { return $null }
    }
    if (Test-EsWindows) {
        return (Join-Path (Join-Path $env:APPDATA $nombre) 'User')
    }
    # PowerShell 7 en macOS o Linux.
    if ($IsMacOS) {
        return (Join-Path $HOME "Library/Application Support/$nombre/User")
    }
    $config = $env:XDG_CONFIG_HOME
    if (-not $config) { $config = Join-Path $HOME '.config' }
    return (Join-Path (Join-Path $config $nombre) 'User')
}

# ── JSON con comentarios ─────────────────────────────────────────────────────
# VS Code admite comentarios y comas finales en settings.json; ConvertFrom-Json
# de PowerShell 5.1, no. Estas dos funciones los quitan respetando las cadenas.

function Remove-ComentariosJson([string]$Texto) {
    $salida = New-Object System.Text.StringBuilder
    $n = $Texto.Length
    $i = 0
    $enCadena = $false
    while ($i -lt $n) {
        $c = $Texto[$i]
        if ($enCadena) {
            [void]$salida.Append($c)
            if ($c -eq '\' -and ($i + 1) -lt $n) {
                [void]$salida.Append($Texto[$i + 1])
                $i += 2
                continue
            }
            if ($c -eq '"') { $enCadena = $false }
        }
        elseif ($c -eq '"') {
            $enCadena = $true
            [void]$salida.Append($c)
        }
        elseif ($c -eq '/' -and ($i + 1) -lt $n -and $Texto[$i + 1] -eq '/') {
            $fin = $Texto.IndexOf([char]10, $i)
            if ($fin -lt 0) { $i = $n } else { $i = $fin }
            continue
        }
        elseif ($c -eq '/' -and ($i + 1) -lt $n -and $Texto[$i + 1] -eq '*') {
            $fin = $Texto.IndexOf('*/', $i + 2, [System.StringComparison]::Ordinal)
            if ($fin -lt 0) { $i = $n } else { $i = $fin + 2 }
            continue
        }
        else {
            [void]$salida.Append($c)
        }
        $i++
    }
    return $salida.ToString()
}

function Remove-ComasFinales([string]$Texto) {
    $salida = New-Object System.Text.StringBuilder
    $n = $Texto.Length
    $i = 0
    $enCadena = $false
    while ($i -lt $n) {
        $c = $Texto[$i]
        if ($enCadena) {
            [void]$salida.Append($c)
            if ($c -eq '\' -and ($i + 1) -lt $n) {
                [void]$salida.Append($Texto[$i + 1])
                $i += 2
                continue
            }
            if ($c -eq '"') { $enCadena = $false }
        }
        elseif ($c -eq '"') {
            $enCadena = $true
            [void]$salida.Append($c)
        }
        elseif ($c -eq ',') {
            $j = $i + 1
            while ($j -lt $n -and [char]::IsWhiteSpace($Texto[$j])) { $j++ }
            if ($j -ge $n -or ($Texto[$j] -ne '}' -and $Texto[$j] -ne ']')) {
                [void]$salida.Append($c)
            }
        }
        else {
            [void]$salida.Append($c)
        }
        $i++
    }
    return $salida.ToString()
}

# Devuelve @{ Datos = objeto; TeniaComentarios = $true/$false }.
# Un archivo ausente o vacío cuenta como {}. Si el JSON no es válido, lanza un error.
function Read-Jsonc([string]$Ruta) {
    if (-not (Test-Path -LiteralPath $Ruta)) {
        return @{ Datos = (New-Object PSObject); TeniaComentarios = $false }
    }
    $texto = [System.IO.File]::ReadAllText($Ruta)
    $sinComentarios = Remove-ComentariosJson $texto
    $teniaComentarios = $sinComentarios -cne $texto
    $limpio = Remove-ComasFinales $sinComentarios
    if (-not $limpio.Trim()) {
        return @{ Datos = (New-Object PSObject); TeniaComentarios = $teniaComentarios }
    }
    try {
        $datos = ConvertFrom-Json -InputObject $limpio
    }
    catch {
        throw "$Ruta no es un JSON válido ($($_.Exception.Message))"
    }
    if ($datos -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$Ruta no contiene un objeto JSON"
    }
    return @{ Datos = $datos; TeniaComentarios = $teniaComentarios }
}

# ConvertTo-Json de PowerShell 5.1 alinea el texto de forma rara y escribe
# ' < > & como ', etc. Esta función parte del JSON compacto y lo deja con
# cuatro espacios de sangría, igual que lo escribe VS Code.
function Format-Json([string]$Compacto) {
    $salida = New-Object System.Text.StringBuilder
    $n = $Compacto.Length
    $i = 0
    $nivel = 0
    $legibles = @{ '0027' = "'"; '003c' = '<'; '003e' = '>'; '0026' = '&' }
    while ($i -lt $n) {
        $c = $Compacto[$i]
        if ($c -eq '"') {
            # Copia la cadena completa, deshaciendo solo los escapes innecesarios.
            [void]$salida.Append($c)
            $i++
            while ($i -lt $n -and $Compacto[$i] -ne '"') {
                if ($Compacto[$i] -eq '\' -and ($i + 1) -lt $n) {
                    if ($Compacto[$i + 1] -eq 'u' -and ($i + 5) -lt $n) {
                        $codigo = $Compacto.Substring($i + 2, 4).ToLowerInvariant()
                        if ($legibles.ContainsKey($codigo)) {
                            [void]$salida.Append($legibles[$codigo])
                        }
                        else {
                            [void]$salida.Append($Compacto, $i, 6)
                        }
                        $i += 6
                        continue
                    }
                    [void]$salida.Append($Compacto, $i, 2)
                    $i += 2
                    continue
                }
                [void]$salida.Append($Compacto[$i])
                $i++
            }
            [void]$salida.Append('"')
            $i++
            continue
        }
        if ($c -eq '{' -or $c -eq '[') {
            $cierre = '}'
            if ($c -eq '[') { $cierre = ']' }
            if (($i + 1) -lt $n -and $Compacto[$i + 1] -eq $cierre) {
                [void]$salida.Append($c).Append($cierre)
                $i += 2
                continue
            }
            $nivel++
            [void]$salida.Append($c).Append("`n").Append([char]32, 4 * $nivel)
        }
        elseif ($c -eq '}' -or $c -eq ']') {
            $nivel--
            [void]$salida.Append("`n").Append([char]32, 4 * $nivel).Append($c)
        }
        elseif ($c -eq ',') {
            [void]$salida.Append($c).Append("`n").Append([char]32, 4 * $nivel)
        }
        elseif ($c -eq ':') {
            [void]$salida.Append(': ')
        }
        elseif (-not [char]::IsWhiteSpace($c)) {
            [void]$salida.Append($c)
        }
        $i++
    }
    return $salida.ToString()
}

function Write-Json([string]$Ruta, $Datos) {
    $compacto = ConvertTo-Json -InputObject $Datos -Depth 100 -Compress
    $texto = (Format-Json $compacto) + "`n"
    $carpeta = Split-Path -Parent $Ruta
    if ($carpeta -and -not (Test-Path -LiteralPath $carpeta)) {
        New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
    }
    # UTF-8 sin BOM, como lo escribe VS Code.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Ruta, $texto, $utf8)
}

# Copia $Ruta a $Carpeta\settings-FECHA.json y devuelve la ruta de la copia.
function Copy-Seguridad([string]$Ruta, [string]$Carpeta) {
    if (-not (Test-Path -LiteralPath $Ruta)) { return $null }
    if (-not (Test-Path -LiteralPath $Carpeta)) {
        New-Item -ItemType Directory -Force -Path $Carpeta | Out-Null
    }
    $marca = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destino = Join-Path $Carpeta "settings-$marca.json"
    $n = 1
    while (Test-Path -LiteralPath $destino) {
        $n++
        $destino = Join-Path $Carpeta "settings-$marca-$n.json"
    }
    Copy-Item -LiteralPath $Ruta -Destination $destino
    return $destino
}

# ── Ajustes: aplicar y revertir ──────────────────────────────────────────────

function Test-Igual($A, $B) {
    $a1 = ConvertTo-Json -InputObject $A -Depth 100 -Compress
    $b1 = ConvertTo-Json -InputObject $B -Depth 100 -Compress
    return $a1 -ceq $b1
}

function Set-Propiedad($Objeto, [string]$Nombre, $Valor) {
    $propiedad = $Objeto.PSObject.Properties[$Nombre]
    if ($propiedad) {
        $propiedad.Value = $Valor
    }
    else {
        Add-Member -InputObject $Objeto -NotePropertyName $Nombre -NotePropertyValue $Valor
    }
}

function Format-Valor($Valor) {
    $texto = ConvertTo-Json -InputObject $Valor -Depth 100 -Compress
    $texto = Format-Json $texto
    $texto = $texto -replace '\s+', ' '
    if ($texto.Length -gt 60) { return $texto.Substring(0, 57) + '...' }
    return $texto
}

# El estado recuerda, para cada ajuste que cambió el instalador, qué valor
# había antes. Así la desinstalación devuelve solo eso a su sitio.
function Read-Estado([string]$Ruta) {
    if (Test-Path -LiteralPath $Ruta) {
        try {
            $estado = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($Ruta))
            if ($estado -and $estado.PSObject.Properties['ajustes'] -and
                $estado.ajustes -is [System.Management.Automation.PSCustomObject]) {
                return $estado
            }
        }
        catch {
            # Un estado ilegible se trata como si no hubiera ninguno.
            $estado = $null
        }
    }
    return [PSCustomObject]@{ version = 1; ajustes = (New-Object PSObject) }
}

# Pone los ajustes de $Archivos (y los de $Extra) encima de los existentes.
# Devuelve $true si todo fue bien.
function Invoke-AplicarAjustes {
    param(
        [string]$Settings,
        [string]$Estado,
        [string[]]$Archivos,
        [hashtable]$Extra,
        [string]$Copias,
        [bool]$Simular
    )
    $nuevos = New-Object System.Collections.Specialized.OrderedDictionary
    foreach ($archivo in $Archivos) {
        $datos = (Read-Jsonc $archivo).Datos
        foreach ($propiedad in $datos.PSObject.Properties) {
            $nuevos[$propiedad.Name] = $propiedad.Value
        }
    }
    if ($Extra) {
        foreach ($clave in $Extra.Keys) { $nuevos[[string]$clave] = $Extra[$clave] }
    }

    $leido = Read-Jsonc $Settings
    $actuales = $leido.Datos
    $registros = (Read-Estado $Estado)

    $cambios = @()
    foreach ($clave in $nuevos.Keys) {
        $propiedad = $actuales.PSObject.Properties[$clave]
        if (-not $propiedad -or -not (Test-Igual $propiedad.Value $nuevos[$clave])) {
            $cambios += $clave
        }
    }
    $yaEstaban = $nuevos.Count - $cambios.Count

    if ($cambios.Count -eq 0) {
        Write-Tenue "Los $($nuevos.Count) ajustes ya estaban aplicados."
        return $true
    }

    if ($Simular) {
        Write-Tenue "Ajustes que cambiarían: $($cambios.Count) (ya aplicados: $yaEstaban)"
        foreach ($clave in $cambios) {
            $propiedad = $actuales.PSObject.Properties[$clave]
            if ($propiedad) {
                Write-Tenue "  ~ ${clave}: $(Format-Valor $propiedad.Value) -> $(Format-Valor $nuevos[$clave])"
            }
            else {
                Write-Tenue "  + ${clave}: $(Format-Valor $nuevos[$clave])"
            }
        }
        return $true
    }

    $copia = Copy-Seguridad $Settings $Copias
    foreach ($clave in $cambios) {
        $valor = $nuevos[$clave]
        $propiedad = $actuales.PSObject.Properties[$clave]
        $registro = $registros.ajustes.PSObject.Properties[$clave]
        if ($registro) {
            Set-Propiedad $registro.Value 'aplicado' $valor
        }
        else {
            $existia = $false
            $anterior = $null
            if ($propiedad) {
                $existia = $true
                $anterior = $propiedad.Value
            }
            $nuevo = [PSCustomObject]@{ existia = $existia; anterior = $anterior; aplicado = $valor }
            Set-Propiedad $registros.ajustes $clave $nuevo
        }
        Set-Propiedad $actuales $clave $valor
    }

    Write-Json $Settings $actuales
    Write-Json $Estado $registros

    if ($copia) { Write-Tenue "Copia de seguridad: $copia" }
    Write-Tenue "Ajustes aplicados: $($cambios.Count) (ya estaban: $yaEstaban)"
    if ($leido.TeniaComentarios) {
        Write-Tenue 'Tu settings.json tenía comentarios; al reescribirlo se pierden,'
        Write-Tenue 'pero siguen en la copia de seguridad.'
    }
    return $true
}

# Devuelve cada ajuste a su valor anterior, salvo los que la persona cambió
# después de instalar.
function Invoke-RevertirAjustes {
    param(
        [string]$Settings,
        [string]$Estado,
        [string]$Copias,
        [bool]$Simular
    )
    $registros = Read-Estado $Estado
    $claves = @($registros.ajustes.PSObject.Properties | ForEach-Object { $_.Name })
    if ($claves.Count -eq 0) {
        Write-Tenue 'No hay ajustes de vscode-setup que revertir.'
        return $true
    }

    $actuales = (Read-Jsonc $Settings).Datos
    $restaurados = @()
    $conservados = @()
    foreach ($clave in $claves) {
        $propiedad = $actuales.PSObject.Properties[$clave]
        if (-not $propiedad) { continue }
        $registro = $registros.ajustes.PSObject.Properties[$clave].Value
        if (Test-Igual $propiedad.Value $registro.aplicado) {
            $restaurados += $clave
        }
        else {
            $conservados += $clave
        }
    }

    if ($Simular) {
        Write-Tenue "Ajustes que se revertirían: $($restaurados.Count)"
        foreach ($clave in $restaurados) {
            $registro = $registros.ajustes.PSObject.Properties[$clave].Value
            if ($registro.existia) {
                Write-Tenue "  ~ ${clave}: vuelve a $(Format-Valor $registro.anterior)"
            }
            else {
                Write-Tenue "  - $clave"
            }
        }
        foreach ($clave in $conservados) {
            Write-Tenue "  = $clave (lo cambiaste después; se queda como está)"
        }
        return $true
    }

    if ($restaurados.Count -gt 0) {
        $copia = Copy-Seguridad $Settings $Copias
        foreach ($clave in $restaurados) {
            $registro = $registros.ajustes.PSObject.Properties[$clave].Value
            if ($registro.existia) {
                Set-Propiedad $actuales $clave $registro.anterior
            }
            else {
                $actuales.PSObject.Properties.Remove($clave)
            }
        }
        Write-Json $Settings $actuales
        if ($copia) { Write-Tenue "Copia de seguridad: $copia" }
    }

    Remove-Item -LiteralPath $Estado -Force
    Write-Tenue "Ajustes revertidos: $($restaurados.Count)"
    if ($conservados.Count -gt 0) {
        Write-Tenue "Se quedan como están porque los cambiaste después de instalar: $($conservados -join ', ')"
    }
    return $true
}

# Dirección file:///... de un archivo, como la necesita Custom UI Style.
# (La conversión [uri]$ruta no sirve: fuera de Windows la toma por relativa.)
function Get-UriArchivo([string]$Ruta) {
    $uri = New-Object System.Uri($Ruta, [System.UriKind]::Absolute)
    return $uri.AbsoluteUri
}

# ── Extensiones ──────────────────────────────────────────────────────────────

# Identificadores de una lista de extensiones: sin comentarios ni espacios.
function Get-ListaExtensiones([string]$Ruta) {
    $ids = @()
    if (Test-Path -LiteralPath $Ruta) {
        foreach ($linea in [System.IO.File]::ReadAllLines($Ruta)) {
            $id = ($linea -replace '#.*', '') -replace '\s', ''
            if ($id) { $ids += $id }
        }
    }
    return , $ids
}

# Extensiones instaladas ahora mismo, en minúsculas.
function Get-Instaladas([string]$Editor) {
    # Con 'Stop', Windows PowerShell convierte en error cualquier línea que el
    # editor escriba por la salida de errores (y Node siempre escribe avisos).
    $ErrorActionPreference = 'Continue'
    $salida = & $Editor --list-extensions 2>$null
    $ids = @()
    foreach ($linea in @($salida)) {
        $id = "$linea".Trim().ToLowerInvariant()
        if ($id -match '^[a-z0-9][a-z0-9-]*\.[a-z0-9._-]+$') { $ids += $id }
    }
    return , $ids
}

# Ejecuta el editor mostrando su salida sangrada y sin el ruido de Node.
function Invoke-Editor([string]$Editor, [string[]]$Argumentos) {
    $ErrorActionPreference = 'Continue'
    & $Editor @Argumentos 2>&1 | ForEach-Object {
        $linea = "$_"
        if ($linea -and $linea -notmatch 'DeprecationWarning|trace-deprecation|^Installing extension|^Uninstalling ') {
            Write-Tenue $linea
        }
    }
}

# ── Fuente ───────────────────────────────────────────────────────────────────

function Test-Fuente {
    if (Test-EsWindows) {
        $claves = @(
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
            'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        )
        foreach ($clave in $claves) {
            $fuentes = Get-ItemProperty -Path $clave -ErrorAction SilentlyContinue
            if (-not $fuentes) { continue }
            foreach ($propiedad in $fuentes.PSObject.Properties) {
                if ($propiedad.Name -like '*JetBrainsMono N*' -or "$($propiedad.Value)" -like '*JetBrainsMonoNerdFont*') {
                    return $true
                }
            }
        }
        return $false
    }
    # PowerShell 7 en macOS o Linux.
    if (Get-Command fc-list -ErrorAction SilentlyContinue) {
        $lista = (& fc-list ':' family 2>$null) -join "`n"
        if ($lista -like '*JetBrainsMono N*') { return $true }
    }
    foreach ($carpeta in @((Join-Path $HOME 'Library/Fonts'), '/Library/Fonts')) {
        if ((Test-Path -LiteralPath $carpeta) -and
            (Get-ChildItem -LiteralPath $carpeta -Filter 'JetBrainsMono*Nerd*' -ErrorAction SilentlyContinue)) {
            return $true
        }
    }
    return $false
}
