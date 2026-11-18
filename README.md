# harvy-arch-packages

Personal Arch Linux `PKGBUILD` recipes for `x86_64`:

- `antigravity`
- `google-chrome`
- `visual-studio-code-bin`

The binary packages are published in
[`harvy-pacman-repo`](https://github.com/HarCar/harvy-pacman-repo/releases).

Detailed maintenance and recovery instructions live in the main workstation
repository: [`harvy-arch-workstation`](https://github.com/HarCar/harvy-arch-workstation).

---

## Actualización automática (`update-packages.sh`)

El repositorio incluye un script para automatizar todo el proceso de verificación, actualización de `PKGBUILD`, cálculo de sumas de verificación, compilación con `makepkg`, firma GPG, regeneración de base de datos de Pacman (`repo-add`), subida a GitHub Releases y limpieza de archivos temporales.

### Uso común

1. **Comprobar si hay versiones nuevas (sin modificar nada):**
   ```bash
   ./update-packages.sh --check
   ```

2. **Actualización interactiva (detecta upstream y pide confirmación):**
   ```bash
   ./update-packages.sh
   ```

3. **Actualizar todo automáticamente sin preguntar:**
   ```bash
   ./update-packages.sh --yes
   ```

4. **Actualizar solo un paquete específico:**
   ```bash
   ./update-packages.sh google-chrome
   ```

5. **Especificar versiones manualmente:**
   ```bash
   ./update-packages.sh --chrome 158.0.8127.36 --vscode 1.147.0 --antigravity 2.33.0:4731201358004224
   ```

6. **Modo simulación (dry-run):**
   ```bash
   ./update-packages.sh --dry-run
   ```
