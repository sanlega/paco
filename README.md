# paco

Instalador y runner de [Francinette](https://github.com/xicodomingues/francinette) (el tester
de proyectos de 42: `libft`, `get_next_line`, `printf`, `minitalk`, `pipex`...), reescrito a
partir de [francinette-image](https://github.com/WaRtr0/francinette-image) para resolver su
mayor problema: la imagen Docker original pesaba **2.5 GB**.

## Qué cambia respecto a francinette-image

**Tamaño.** La imagen Docker original instalaba `ghc` (el compilador de Haskell), `cmake`,
`postgresql`/`libpq-dev` y `libxext-dev` — ninguno de ellos usado por ningún tester del
repositorio (se verificó con grep sobre todo el árbol de francinette y sus submódulos). Sumado
a eso, el `venv` que creaba nunca se activaba de verdad (cada `RUN` de Docker es un shell nuevo,
así que el `source venv/bin/activate` no sobrevivía a la siguiente capa) y el `git clone`
arrastraba el historial completo de 9 submódulos. Quitando todo eso, aplicando
`--no-install-recommends`, limpiando la caché de `apt` y usando un build multi-stage (para que
lo que se borra en una capa no siga pesando en las de abajo), la imagen baja a **~1.1 GB**
manteniendo exactamente el mismo compilador (`gcc` + `clang`), `valgrind` y `norminette` que usa
un `42-Session-Ubuntu` real — nada de eso se toca, porque es justamente lo que hace que los
resultados del tester sean fiables.

**Cero overhead cuando se puede.** `install.sh` primero intenta instalar francinette
directamente en el sistema (sin Docker) si ya tenés `gcc`, `clang`, `valgrind`, `libbsd-dev` y
`libncurses-dev` instalados — típicamente el caso en Linux. Ahí el "tamaño" de paco es cero: no
hay imagen que construir. Docker queda como *fallback* para macOS, Windows/WSL sin el toolchain,
o cualquier sistema sin esos paquetes.

**Multiplataforma de verdad.** El instalador original solo tocaba `.zshrc` e inyectaba lógica
de shell que dependía de `systemctl` (que no existe en macOS) para arrancar el contenedor en
cada shell nuevo. Acá:
- se configura tanto `.bashrc` como `.zshrc`, los que existan;
- el contenedor se arranca (o se reusa) de forma perezosa, la primera vez que corrés `paco`, no
  en cada apertura de terminal;
- se eliminó el path hardcodeado a `/sgoinfre/goinfre/Perso/mmorot/share` (específico del campus
  de Lyon del autor original);
- `docker build` compila para la arquitectura nativa del host automáticamente (amd64 o arm64),
  sin manifests ni `buildx` de por medio — funciona igual en un Mac de Apple Silicon que en un
  Linux x86.

**Bonus obligatorio en `get_next_line`.** Como ahora el bonus es obligatorio y los archivos ya
no llevan sufijo `_bonus` (es decir, la implementación completa vive directamente en
`get_next_line.c` / `get_next_line.h` / `get_next_line_utils.c`), se parcheó
`testers/get_next_line/GetNextLine.py` (ver `overlay/`) para que:
1. trate el bonus como parte obligatoria salvo que se pase `-m`/`--mandatory` explícitamente;
2. cree alias de esos archivos con los nombres `_bonus` históricos (`get_next_line_bonus.c`,
   `get_next_line_bonus.h`, `get_next_line_utils_bonus.c`) en el directorio de trabajo temporal,
   así los testers de terceros vendorizados (el `gnlTester` de Tripouille en C++, que los
   referencia por nombre fijo) siguen compilando sin tocar ese código de terceros.

Esto se validó de punta a punta: build real de la imagen, y una corrida real del tester contra
un `get_next_line` de prueba sin archivos `_bonus`, confirmando que el bonus se compila y
ejecuta igual con ambos testers (`gnlTester` y `fsoares`).

## Instalación

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/claude/kind-noether-mvlfze/install.sh)"
```

(si más adelante cambiás la rama por defecto del repo, por ejemplo a `main`, actualizá esa URL
para que apunte ahí). El instalador pregunta el directorio de instalación (por defecto `$HOME`), decide automáticamente
entre modo nativo y modo Docker, y deja disponibles los comandos `paco` y `francinette` (alias
del mismo script) en tu shell.

## Uso

Adentro de la carpeta de un proyecto (`libft`, `get_next_line`, etc.):

```shell
paco
```

Acepta los mismos flags que francinette (`-m`/`--mandatory`, `-b`/`--bonus`, `-s`/`--strict`,
`-in`/`--ignore-norm`, `-t`/`--testers`, etc. — `paco --help` los lista todos).

En modo Docker, el proyecto tiene que estar bajo `$HOME` (o `/goinfre`, `/sgoinfre` si existen)
para que el contenedor pueda verlo.

## Desinstalación / actualización / rebuild

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/claude/kind-noether-mvlfze/uninstall.sh)"
```

Ya instalado, `update.sh` trae la última versión (de paco y, en modo nativo, de francinette) y
`rebuild.sh` fuerza una reconstrucción limpia (sin caché) de la imagen o del checkout nativo.

## Estructura del repo

```
Dockerfile        build multi-stage: clona francinette + aplica overlay/, instala solo lo
                  que realmente usan los testers, sin venv ni caché de apt/pip.
overlay/          archivos que se copian encima del francinette clonado (mismo mecanismo
                  en Docker y en instalación nativa) - hoy, el parche de bonus obligatorio.
paco              CLI: arranca/reusa el contenedor en modo Docker, o ejecuta
                  francinette/main.py directo en modo nativo.
install.sh        detecta modo nativo vs Docker, clona/actualiza, configura el shell.
uninstall.sh       / update.sh / rebuild.sh
```

## Créditos

- [xicodomingues](https://github.com/xicodomingues) y [arsalas](https://github.com/arsalas),
  creadores de [francinette](https://github.com/xicodomingues/francinette).
- [WaRtr0](https://github.com/WaRtr0), autor de
  [francinette-image](https://github.com/WaRtr0/francinette-image), la base de este proyecto.
- [Tripouille](https://github.com/Tripouille), [jtoty](https://github.com/jtoty) /
  [y3ll0w42](https://github.com/y3ll0w42), [alelievr](https://github.com/alelievr),
  [cacharle](https://github.com/cacharle), [vfurmane](https://github.com/vfurmane) y
  [gmarcha](https://github.com/gmarcha), autores de los distintos testers que usa francinette.

`paco` no reemplaza tus propios tests.
