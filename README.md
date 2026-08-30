# IT Support User Manager

Herramienta para Windows que permite **crear, actualizar o desbloquear una cuenta de usuario local de soporte técnico** mediante PowerShell.

El proyecto incluye dos archivos:

- `ITSupportUser.ps1`: contiene toda la lógica de administración del usuario.
- `RunITSupportUser.bat`: facilita la ejecución del script de PowerShell desde CMD y reenvía los parámetros recibidos.

> [!WARNING]
> Este script realiza cambios administrativos en Windows, incluyendo la creación de usuarios locales, modificación de contraseñas, incorporación al grupo de administradores y cambios en la política local de contraseñas. Debe revisarse y probarse en un entorno controlado antes de utilizarse en producción.

---

## Requisitos

- Windows 10, Windows 11 o una versión compatible de Windows con PowerShell.
- PowerShell 5.1 o superior recomendado.
- Permisos de **Administrador local**.
- Cmdlets del módulo `Microsoft.PowerShell.LocalAccounts`, cuando estén disponibles.
- El script debe ejecutarse en un sistema donde se permita administrar usuarios locales.

> En equipos unidos a un dominio pueden existir políticas de dominio que prevalezcan sobre las configuraciones locales realizadas por este script.

---

## Archivos

### `ITSupportUser.ps1`

Script principal.

Puede:

- Crear un usuario local.
- Actualizar la contraseña de un usuario existente.
- Desbloquear/activar una cuenta.
- Configurar la contraseña para que no expire.
- Impedir que el usuario cambie su propia contraseña.
- Agregar el usuario al grupo local de administradores.
- Ejecutarse en modo silencioso.
- Mostrar ayuda integrada.

### `RunITSupportUser.bat`

Lanzador para facilitar la ejecución:

```bat
RunITSupportUser.bat [parámetros]
```

El `.bat`:

1. Cambia la página de códigos de la consola a UTF-8.
2. Cambia el directorio de trabajo a la carpeta donde se encuentra el `.bat`.
3. Ejecuta `ITSupportUser.ps1`.
4. Usa `-ExecutionPolicy Bypass` solamente para esa ejecución de PowerShell.
5. Reenvía al script todos los argumentos recibidos mediante `%*`.
6. Mantiene la ventana abierta al finalizar mediante `pause`.

---

## Uso básico

El script debe ejecutarse con privilegios de administrador.

### Opción 1: usando el archivo BAT

Abra **CMD o Windows Terminal como Administrador**, vaya a la carpeta del proyecto y ejecute:

```bat
RunITSupportUser.bat
```

También puede hacer clic derecho sobre el archivo y ejecutarlo desde una consola elevada.

### Opción 2: ejecutando PowerShell directamente

```powershell
.\ITSupportUser.ps1
```

Si la política de ejecución de PowerShell impide iniciar el script, puede utilizar:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\ITSupportUser.ps1"
```

---

## Parámetros

| Parámetro | Descripción |
|---|---|
| `-User` | Nombre de la cuenta local que se administrará. El valor predeterminado es `itsupport`. |
| `-UserName` | Alias de `-User`. |
| `-Password` | Contraseña que se asignará al usuario. |
| `-UnlockOnly` | Intenta desbloquear/activar únicamente la cuenta, sin crearla ni actualizarla. |
| `-Silent` | Reduce la salida mostrada en pantalla y presenta principalmente el resultado final. |
| `-Help` | Muestra la ayuda integrada del script. |
| `-h` | Alias de `-Help`. |
| `-?` | Alias de `-Help`. |

---

## Ejemplos

### Crear o actualizar el usuario predeterminado

```powershell
.\ITSupportUser.ps1
```

El usuario utilizado será:

```text
itsupport
```

Si no se proporciona `-Password`, el script utiliza la contraseña predeterminada definida internamente en la variable:

```powershell
$DefaultPassword
```

> [!IMPORTANT]
> En la versión actual del código, el valor real de `$DefaultPassword` es `DefaultPassword`. La documentación interna ubicada al principio del `.ps1` menciona otra contraseña, por lo que actualmente existe una inconsistencia entre el comentario de ayuda y el código.

---

### Crear un usuario diferente

Para cualquier usuario distinto de `itsupport`, la contraseña debe indicarse explícitamente:

```powershell
.\ITSupportUser.ps1 -User soporte -Password "UnaContraseñaSegura"
```

Con el BAT:

```bat
RunITSupportUser.bat -User soporte -Password "UnaContraseñaSegura"
```

---

### Actualizar un usuario existente

No existe un comando separado para actualizar.

Si el usuario ya existe:

```powershell
.\ITSupportUser.ps1 -User soporte -Password "NuevaContraseña"
```

el script detecta la cuenta y cambia su contraseña.

---

### Desbloquear la cuenta predeterminada

```powershell
.\ITSupportUser.ps1 -UnlockOnly
```

O:

```bat
RunITSupportUser.bat -UnlockOnly
```

---

### Desbloquear otro usuario

```powershell
.\ITSupportUser.ps1 -User soporte -Password "UnaContraseña" -UnlockOnly
```

> [!NOTE]
> Debido al orden actual de validación del script, cuando se utiliza `-UnlockOnly` con un usuario distinto de `itsupport`, también se exige `-Password`, aunque la contraseña no se utiliza durante el desbloqueo. Esto puede corregirse en una futura versión del script.

---

### Modo silencioso

```powershell
.\ITSupportUser.ps1 -Silent
```

También puede combinarse con otros parámetros:

```powershell
.\ITSupportUser.ps1 -User soporte -Password "UnaContraseñaSegura" -Silent
```

Para desbloquear:

```powershell
.\ITSupportUser.ps1 -UnlockOnly -Silent
```

> El `.bat` siempre ejecuta `pause` al terminar, por lo que la ventana continuará esperando una tecla incluso cuando PowerShell se haya ejecutado con `-Silent`.

---

### Mostrar ayuda

```powershell
.\ITSupportUser.ps1 -Help
```

También funcionan:

```powershell
.\ITSupportUser.ps1 -h
```

```powershell
.\ITSupportUser.ps1 -?
```

---

## Flujo de funcionamiento

En una ejecución normal, el script sigue aproximadamente este proceso:

```text
Inicio
  |
  +--> Verificar privilegios de administrador
  |
  +--> Determinar usuario y contraseña
  |
  +--> Revisar política local de contraseñas
  |
  +--> Crear usuario o actualizar su contraseña
  |
  +--> Configurar propiedades de contraseña
  |
  +--> Agregar usuario al grupo Administradores
  |
  +--> Mostrar información de verificación
  |
  +--> Mostrar resumen
  |
  +--> Fin
```

Cuando se utiliza `-UnlockOnly`, la intención es:

```text
Inicio
  |
  +--> Verificar privilegios
  |
  +--> Comprobar que el usuario existe
  |
  +--> Intentar desbloquear/activar la cuenta
  |
  +--> Mostrar resultado
  |
  +--> Fin
```

---

## Compatibilidad con diferentes idiomas de Windows

Para agregar la cuenta al grupo administrativo, el script intenta primero:

```text
Administradores
```

y posteriormente:

```text
Administrators
```

Esto busca ofrecer compatibilidad básica con instalaciones de Windows en español e inglés.

---

## Métodos alternativos utilizados por el script

El script intenta utilizar primero los cmdlets nativos de PowerShell, por ejemplo:

- `Get-LocalUser`
- `New-LocalUser`
- `Set-LocalUser`
- `Unlock-LocalUser`
- `Add-LocalGroupMember`

Cuando alguna operación falla o el cmdlet no está disponible, en varios puntos utiliza herramientas clásicas de Windows como alternativa:

```text
net user
net localgroup
secedit
```

Esto permite cierta compatibilidad con configuraciones donde algunos cmdlets no funcionan.

---

## Cambios realizados en el sistema

En una ejecución completa, el script puede modificar:

### Cuenta local

Puede crear:

```text
<nombre de usuario indicado>
```

o modificar una cuenta existente.

### Contraseña

Asigna la contraseña indicada mediante:

```text
-Password
```

o la contraseña predeterminada interna si se utiliza `itsupport` sin especificarla.

### Grupo de administradores

Intenta agregar la cuenta a:

```text
Administradores
```

o:

```text
Administrators
```

### Propiedades de contraseña

Intenta establecer:

- Contraseña sin expiración.
- El usuario no puede cambiar su contraseña.

### Política local de contraseñas

La función `Disable-PasswordPolicy` utiliza `secedit` y puede configurar temporalmente valores equivalentes a:

```text
MinimumPasswordLength = 0
PasswordComplexity = 0
PasswordHistorySize = 0
MaximumPasswordAge = -1
MinimumPasswordAge = 0
```

---

## Advertencia sobre la política de contraseñas

> [!CAUTION]
> La función se llama `Disable-PasswordPolicy` y el código indica que la política se deshabilita "temporalmente". Sin embargo, **la versión actual no guarda la configuración original ni la restaura al finalizar**.

Esto significa que, si Windows tenía habilitados requisitos de complejidad, longitud mínima u otras restricciones locales, estos valores podrían permanecer modificados después de ejecutar el script.

Antes de utilizar esta versión en un entorno real se recomienda modificar el programa para:

1. Exportar y guardar la política original.
2. Aplicar solamente los cambios estrictamente necesarios.
3. Crear o actualizar la cuenta.
4. Restaurar la política original incluso si ocurre un error, idealmente mediante un bloque `finally`.

---

## Consideraciones de seguridad

### No almacenar contraseñas reales en el código

Actualmente existe una contraseña predeterminada escrita directamente dentro del archivo `.ps1`.

Para entornos reales, es preferible evitar contraseñas embebidas en scripts, especialmente si el proyecto se almacena en:

- Git.
- GitHub.
- GitLab.
- OneDrive.
- Carpetas compartidas.
- Sistemas de tickets.
- Repositorios internos accesibles por múltiples personas.

Una alternativa más segura es solicitar la contraseña en tiempo de ejecución o utilizar un mecanismo seguro de administración de secretos.

### Contraseña visible en línea de comandos

Al utilizar:

```powershell
-Password "..."
```

la contraseña se proporciona como texto.

Dependiendo del entorno, puede quedar expuesta en historial de comandos, registros o herramientas de administración.

### Cuenta administrativa

El usuario creado se agrega al grupo local de administradores. Por ello, quien conozca sus credenciales podría obtener privilegios elevados en el equipo.

Debe aplicarse únicamente cuando sea necesario y de acuerdo con las políticas de seguridad de la organización.

### `ExecutionPolicy Bypass`

El archivo BAT utiliza:

```powershell
-ExecutionPolicy Bypass
```

Esto no modifica permanentemente la política de ejecución del equipo; se aplica al proceso de PowerShell iniciado por el `.bat`.

Aun así, el script debería ejecutarse solamente si su origen y contenido son confiables.

---

## Códigos de salida

El script utiliza principalmente:

| Código | Significado |
|---:|---|
| `0` | Operación principal completada correctamente. |
| `1` | Se produjo un error considerado crítico. |

Algunos errores relacionados con propiedades secundarias, como pertenencia al grupo o determinadas políticas del usuario, se tratan como advertencias y pueden no provocar un código de salida distinto de cero.

---

## Problemas conocidos de la versión actual

Durante la revisión del código se identificaron los siguientes puntos:

1. **La política de contraseñas no se restaura.**  
   `Disable-PasswordPolicy` cambia la política local, pero no conserva ni vuelve a aplicar los valores anteriores.

2. **La contraseña predeterminada documentada no coincide con el código.**  
   El bloque de ayuda inicial menciona una contraseña diferente al valor actual de `$DefaultPassword`.

3. **`-UnlockOnly` valida la contraseña antes de llegar a la lógica de desbloqueo.**  
   Para usuarios distintos de `itsupport` se exige innecesariamente `-Password`.

4. **El método alternativo de desbloqueo no es equivalente.**  
   Si `Unlock-LocalUser` falla, el script ejecuta:

   ```text
   net user <usuario> /active:yes
   ```

   Este comando habilita una cuenta deshabilitada, pero no necesariamente elimina un bloqueo producido por intentos fallidos de autenticación.

5. **La función que agrega al grupo administrativo devuelve éxito incluso si ambos intentos fallan.**  
   `Add-UserToAdministrators` termina devolviendo `$true` después del fallback, aunque el usuario no haya podido agregarse.

6. **El resumen siempre indica que la contraseña fue proporcionada.**  
   En la lógica principal se establece:

   ```powershell
   $passwordWasSet = $true
   ```

   incluso cuando se utilizó la contraseña predeterminada.

7. **El modo silencioso no es completamente silencioso cuando se utiliza el BAT.**  
   `RunITSupportUser.bat` imprime mensajes propios y ejecuta `pause` al finalizar.

Estos puntos no impiden comprender el funcionamiento general del programa, pero deberían corregirse antes de considerar el script listo para despliegues automatizados o de producción.

---

## Solución de problemas

### Error: el script debe ejecutarse como administrador

Mensaje:

```text
[ERROR] This script must be run as Administrator.
```

Abra PowerShell, CMD o Windows Terminal utilizando **Ejecutar como administrador** y vuelva a ejecutar el comando.

---

### El usuario ya existe

No es necesariamente un error.

El script detecta la cuenta y trata de actualizar la contraseña indicada.

---

### No se puede agregar al grupo Administradores

Compruebe:

```powershell
Get-LocalGroup
```

y confirme el nombre del grupo administrativo en el idioma instalado.

También puede verificar la pertenencia con:

```powershell
Get-LocalGroupMember -Group "Administradores"
```

o, en Windows en inglés:

```powershell
Get-LocalGroupMember -Group "Administrators"
```

---

### Verificar manualmente el usuario

Puede consultar la cuenta con:

```powershell
Get-LocalUser -Name "itsupport"
```

o:

```cmd
net user itsupport
```

---

### Verificar administradores locales

Windows en español:

```cmd
net localgroup Administradores
```

Windows en inglés:

```cmd
net localgroup Administrators
```

---

## Estructura recomendada

```text
ITSupportUser/
|
+-- ITSupportUser.ps1
+-- RunITSupportUser.bat
+-- README.md
```

Los archivos `.ps1` y `.bat` deben mantenerse en la misma carpeta, ya que el lanzador busca `ITSupportUser.ps1` en su propio directorio.

---

## Recomendaciones antes de producción

Antes de distribuir esta herramienta ampliamente sería recomendable:

- Eliminar la contraseña predeterminada del código.
- Pedir la contraseña de forma segura e interactiva cuando sea necesario.
- Restaurar la política local de contraseñas después de crear la cuenta.
- Corregir la lógica de `-UnlockOnly`.
- Detectar el grupo de administradores mediante SID en lugar de depender del idioma.
- Verificar realmente que la cuenta quedó dentro del grupo administrativo.
- Corregir el estado devuelto por `Add-UserToAdministrators`.
- Separar claramente "habilitar cuenta" de "desbloquear cuenta".
- Evitar imprimir o registrar información sensible.
- Añadir registros opcionales para auditoría.
- Probar el script en las versiones de Windows que vaya a soportar.

---

## Resumen rápido

Crear/actualizar `itsupport`:

```bat
RunITSupportUser.bat
```

Crear otro usuario:

```bat
RunITSupportUser.bat -User soporte -Password "UnaContraseñaSegura"
```

Actualizar contraseña:

```bat
RunITSupportUser.bat -User soporte -Password "NuevaContraseña"
```

Desbloquear/activar `itsupport`:

```bat
RunITSupportUser.bat -UnlockOnly
```

Modo silencioso:

```bat
RunITSupportUser.bat -Silent
```

Ayuda:

```bat
RunITSupportUser.bat -Help
```

---

## Licencia

Añada aquí la licencia correspondiente si el proyecto va a distribuirse o almacenarse en un repositorio público.
