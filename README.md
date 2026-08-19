# harvy-arch-packages

Recetas personales de paquetes Arch Linux para `x86_64`.

Este repositorio mantiene los `PKGBUILD` de:

- `google-chrome`
- `visual-studio-code-bin`

Las recetas fueron creadas revisando las versiones correspondientes del AUR.
El AUR se usa como referencia, pero no es una dependencia del proceso de
construcción. Los binarios se descargan únicamente desde los proveedores
oficiales de cada aplicación.

Los paquetes compilados y la base de datos de pacman pertenecen al repositorio
separado `harvy-pacman-repo`.

## Responsabilidad De Mantenimiento

`pacman -Syu` no consulta directamente si Google o Microsoft publicaron una
nueva versión. Solo puede instalar actualizaciones que ya hayan sido
compiladas y publicadas en `harvy-pacman-repo`.

Con el proceso local actual, cada actualización de Chrome o VS Code requiere
una revisión y una publicación manual. La clave GPG no se genera nuevamente:
se crea una sola vez y se reutiliza para firmar todas las versiones futuras.

El trabajo repetido por cada nueva versión es:

1. Confirmar que el proveedor publicó una versión Linux nueva.
2. Actualizar `pkgver` si la receta no lo obtiene automáticamente.
3. Aumentar `pkgrel` solamente si cambió la receta de empaquetado.
4. Ejecutar `updpkgsums`.
5. Revisar el diff del `PKGBUILD` y las URLs de descarga.
6. Regenerar `.SRCINFO`.
7. Construir y firmar el paquete.
8. Copiar el paquete al repositorio `harvy-pacman-repo`.
9. Regenerar y firmar la base de datos del repositorio.
10. Probar el paquete y publicar los cambios.

Si una receta tiene una función `pkgver()`, puede detectar la versión durante
la construcción. Aun así, hay que revisar el resultado, actualizar checksums,
regenerar `.SRCINFO` y publicar el nuevo paquete. No se debe asumir que todo el
proceso es automático.

## Primera Configuración

Instalar las herramientas de construcción:

```bash
sudo pacman -S --needed base-devel pacman-contrib gnupg
```

Crear una clave GPG exclusiva para estos paquetes. La clave privada debe
permanecer en esta máquina y nunca debe subirse a GitHub. La clave pública se
distribuirá más adelante para que pacman pueda verificar los paquetes.

La clave se crea una sola vez. No se debe crear una clave nueva por cada
actualización, porque las instalaciones existentes dejarían de confiar en la
clave anterior.

## Construcción Manual

Desde el directorio del paquete:

```bash
updpkgsums
makepkg --printsrcinfo > .SRCINFO
makepkg -Cfs --sign --key KEY_ID
```

Antes de aceptar el resultado, revisar:

```bash
git diff -- PKGBUILD .SRCINFO
makepkg --verifysource
```

No utilizar `makepkg --skipinteg`, `--skipchecksums` ni `--skippgpcheck` para
resolver errores de descarga o checksums.

## Actualizar Un Paquete

Ejemplo para Chrome:

```bash
cd /home/harvy/repositories/harvy-arch-packages/google-chrome
updpkgsums
makepkg --printsrcinfo > .SRCINFO
makepkg -Cfs --sign --key KEY_ID
```

Para VS Code se repite el mismo flujo entrando en:

```text
/home/harvy/repositories/harvy-arch-packages/visual-studio-code-bin
```

Si cambia el `PKGBUILD`, revisar especialmente `source`, `depends`,
`optdepends`, `package()` y cualquier script auxiliar. No copiar cambios del
AUR sin revisarlos.

## Publicar En harvy-pacman-repo

Copiar los paquetes firmados a:

```text
/home/harvy/repositories/harvy-pacman-repo/x86_64/
```

Regenerar la base de datos firmada:

```bash
cd /home/harvy/repositories/harvy-pacman-repo/x86_64
repo-add --sign --key KEY_ID harvy.db.tar.zst *.pkg.tar.zst
```

La base de datos debe publicarse junto con su firma y con las firmas de los
paquetes. No publicar una base de datos nueva sin los paquetes que referencia.

## Automatización Futura

El flujo manual puede automatizarse después con GitHub Actions. La clave GPG
seguiría creándose una sola vez, pero su clave privada tendría que guardarse
como secreto de GitHub Actions. El workflow podría detectar versiones, crear
una propuesta de cambio, construir, firmar y publicar.

Hasta automatizar y probar ese workflow, ninguna actualización se considera
instalada solamente porque exista una nueva versión en la web del proveedor.
