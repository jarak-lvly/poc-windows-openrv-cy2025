# PoC: OpenRV CY2025 Windows Build via Docker

## TL;DR:

It's like a taco wrapped in "guacamolito", wrapped in a pizza:  running Windows inside QEMU, inside a Linux Docker container… so I can run windows in docker and build OpenRV.

The actual build instructions are located in the `docs/` directory. This README provides an overview of the project and its design. 

For the tested software versions and environment used to validate this proof of concept, see `docs/04.notes.md`.

## My goals:

1. This is a proof of concept, not a supported build environment.  
2. This is documentation, not a redistribution of OpenRV or its dependencies.  
3. Users are expected to obtain all required software themselves.  
4. I am not maintaining a Windows build system; this is documentation of my process.

## Intended audience

This proof of concept is primarily intended for users who:

- normally work on Linux  
- need to build the Windows version of OpenRV  
- want a reproducible build environment  
- do not want to maintain a dedicated Windows development workstation/vm

## What this project is

- Documentation  
- Scripts  
- Docker Compose files  
- Reproducible build environment

This repository documents a proof of concept for building OpenRV CY2025 inside a Windows Docker container from a Linux host. The goal is to allow Linux users who do not have a dedicated Windows workstation/vm to create a repeatable Windows build environment for OpenRV development and testing.

## What this project is NOT

This repository is not

- an official OpenRV build environment  
- Official Windows build environment  
- a replacement for the OpenRV documentation  
- a source of prebuilt OpenRV binaries  
- a redistribution of Autodesk, Qt, Visual Studio, or other third-party software  
- intended to replace Windows testing


# Workflow at a glance
```
        Stage 1                      Stage 2

+----------------------+      +----------------------+
|      qt-prereq       | ---> |    openrv-build      |
|----------------------|      |----------------------|
| Install Qt           |      | Extract Qt zip       |
| Export Qt zip        |      | Build OpenRV         |
+----------------------+      +----------------------+
           \                         /
            \                       /
             +---------------------+
             |       shared        |
             +---------------------+
```

1. Build the Qt prerequisite container
2. Connect to Windows using the browser console or RDP
3. Install Qt
4. Export the Qt zip to “shared”.  Do not delete “shared” in step 5.
5. Manually delete the temp Qt container
6. Build the OpenRV container
7. Build OpenRV

## Directory tree
```
poc-windows-openrv-cy2025/  
├── openrv-build  
│   ├── docker-compose.yml  
│   ├── oem  
│   │   ├── install.bat  
│   │   ├── install-openrv-cy2025.ps1  
│   │   ├── msys2-packages.txt  
│   │   └── openrv-cy2025.vsconfig  
│   └── win11  
├── qt-prereq  
│   ├── docker-compose.yml  
│   ├── oem  
│   │   ├── export-qt.ps1  
│   │   ├── install.bat  
│   │   └── install-qt.ps1  
│   └── windows  
└── shared

```

## Repository layout

| Directory | Purpose |
| ----- | ----- |
| qt-prereq | Temporary Windows VM used to install Qt and create the Qt zip archive. |
| shared | Shared directory used to transfer the Qt zip between the two Windows containers. |
| openrv-build | Windows development environment used to build OpenRV. |

### Note:

The contents of the `oem/` directory are copied into the Windows VM and executed during the initial setup.

The Qt installer is a GUI application. Connect to the Windows desktop using either the built-in browser console or RDP.  See docs for more info.


## Two-container workflow (overview)

### Container 1

**Qt preparation**

Purpose:

- install Qt  
- login  
- accept license  
- zip Qt directory  
- throw container away

### Container 2

**OpenRV build**

Purpose:

- install build tools  
- unpack Qt zip  
- build OpenRV

Simple flow:

```
Qt Container  
      │  
      ▼  
 Qt zip archive  
      │  
      ▼  
OpenRV Build Container  
      │  
      ▼  
 Build OpenRV
```

Container 2 is then ready for YOU to build OpenRV.  Please see [Building Open RV](https://aswf-openrv.readthedocs.io/en/latest/build_system/config_common_build.html#building-open-rv) documentation.

## Why Docker

*"Why not just use a VM?"*  You can; initially I did:  VMWare, XCP-NG, Hyper-V.  But I wanted to try it out in docker.  VMs have the same advantages, albeit without the extra (not special) sauce.

Advantages

- [dockur/windows](https://github.com/dockur/windows) does the ISO downloading and installation
- repeatable environment  
- infrastructure as code  
- easy rebuild after dependency changes  
- version-controlled build scripts  
- no long-lived Windows development VM to maintain


## Why is this called "Windows in Docker"

Although this project refers to a "Windows Docker container," Windows is not running directly as a normal Docker container.

Ordinary containers share the host operating system’s kernel. Because a Windows application requires the Windows kernel, Docker cannot normally run a native Windows container directly on a Linux kernel.

The [dockur/windows](https://github.com/dockur/windows) project solves this by running **QEMU inside a Linux container**:

```
Linux host  
└── Docker Engine  
    └── Linux container  
        └── QEMU virtual machine  
            └── Windows  
                └── Qt installation or OpenRV build
```

Docker manages the surrounding Linux container, including its storage mounts, networking, configuration, and lifecycle. Inside that container, QEMU provides the virtual computer on which Windows is installed.

Therefore, Windows is technically a **virtual machine managed from within a Docker container**, rather than a Windows process sharing the Linux host kernel. A taco wrapped inside a pizza.


## Before you begin

Detailed setup instructions for the Qt prerequisite container and the OpenRV build container are available under the `docs/` directory. 

This proof of concept **does not eliminate the need for Windows.** It automates the creation of a reproducible Windows build environment using Docker, but an initial Windows setup is still required.


## Why Qt is packaged as a zip

- Create your own zip file from your own local Qt open source installation.  
- Users are responsible for obtaining Qt themselves under the appropriate license.  
- This repository does not provide a Qt archive or automate acceptance of Qt’s license terms.

Each user must obtain Qt directly from the official Qt installer, authenticate as required, review the applicable license terms, and create the zip archive from their own installation.

The zip file is only a method of transferring the installed Qt directory from the temporary preparation container into the reproducible OpenRV build container. It is not a modified Qt distribution or a binary package supplied by this project.

Only the expected archive layout and directory tree are documented in this repository. No Qt binaries are included.


## Why no binaries

### Why aren't there any binaries?

This project intentionally does not provide:

- OpenRV executables  
- Qt binaries  
- FFmpeg binaries  
- Visual Studio components  
- other third-party dependencies

The intent is to document a reproducible build process rather than redistribute software owned by other projects.


## Limitations

Current limitations

- GUI testing must still be performed on Windows with graphics.  
- This is not an officially supported OpenRV build environment.  
- Some dependencies may change over time as OpenRV evolves.


## References

https://github.com/dockur/windows

https://github.com/AcademySoftwareFoundation/OpenRV

https://aswf-openrv.readthedocs.io/en/latest/build\_system/config\_common\_build.html

https://docs.docker.com/reference/

https://doc.qt.io/qt-6.5/get-and-install-qt.html


## Licensing

This repository contains only original documentation, helper scripts, and patch files. All third-party software must be obtained from their respective projects under their own licenses.

