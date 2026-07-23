# PoC: OpenRV CY2025 Windows Build via Docker

## TL;DR:

This repository documents a proof of concept for building OpenRV CY2025 for Windows from a Linux host using Windows running inside a Docker container.

Or

It's like a taco wrapped in "guacamolito", wrapped in a pizza:  running Windows inside QEMU, inside a Linux Docker container… so I can run Windows in Docker and build OpenRV.

The actual build instructions are located in the `docs/` directory. This README provides an overview of the project and its design. 


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
- do not want to maintain a dedicated Windows development workstation

## What this project is

- Documentation  
- Scripts  
- Docker Compose files  
- Reproducible build environment

This repository documents a proof of concept for building OpenRV CY2025 on Windows from a Linux host using a Windows build container.  The goal is to allow Linux users who do not have a dedicated Windows workstation to create a reproducible Windows build environment for OpenRV development and testing.


## What this project is NOT

This repository is not

- an official OpenRV build environment  
- an official Windows build environment  
- a replacement for the OpenRV documentation  
- a source of prebuilt OpenRV binaries  
- a redistribution of Autodesk, Qt, Visual Studio, or other third-party software  
- intended to replace Windows testing


## Workflow at a glance

1. Build and start the Windows build container.
2. The setup script automatically installs all prerequisites, including Qt 6.5.3 via aqtinstall.
3. Connect to the Windows desktop using the browser console or Remote Desktop (RDP).
4. Build OpenRV.


## Directory tree
```
poc-windows-openrv-cy2025/
└── openrv-build/
    ├── docker-compose.yml
    ├── oem/
    │   ├── install.bat
    │   ├── install-openrv-cy2025.ps1
    │   ├── msys2-packages.txt
    │   └── openrv-cy2025.vsconfig
    └── win11/
```


### Notes:

The contents of the `oem/` directory are copied into the Windows environment and executed during the initial setup.

For the tested software versions and environment used to validate this proof of concept, see `docs/03.notes.md`.

This proof of concept prepares the build environment but does not automatically build OpenRV. Continue with the official OpenRV documentation: [Building Open RV](https://aswf-openrv.readthedocs.io/en/latest/build_system/config_common_build.html#building-open-rv)

## Why Docker

*"Why not just use a VM?"*  You can; initially I did:  VMware, XCP-NG, Hyper-V.  But I wanted to try it out in Docker.  VMs have the same advantages, albeit without the extra (not special) sauce.

Advantages

- [dockur/windows](https://github.com/dockur/windows) does the ISO downloading and installation
- repeatable environment  
- infrastructure as code  
- easy rebuild after dependency changes  
- version-controlled build scripts  
- no long-lived Windows development workstation to maintain


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
                └── OpenRV build
```

Docker manages the surrounding Linux container, including its storage mounts, networking, configuration, and lifecycle. Inside that container, QEMU provides the virtual computer on which Windows is installed.

Therefore, Windows is technically a **virtual machine managed from within a Docker container**, rather than a Windows process sharing the Linux host kernel. A taco wrapped inside a pizza.


## Before you begin

Detailed instructions for creating the Windows build environment and building OpenRV are available under the `docs/` directory.

This proof of concept **does not eliminate the need for Windows.** It automates the creation of a reproducible Windows build environment using Docker, but an initial Windows setup is still required.


## Why Qt is installed using aqtinstall

Qt is installed using aqtinstall, the same approach used by the Linux OpenRV build environment. This removes the requirement for an interactive Qt installer, making the Windows build fully reproducible and suitable for unattended Docker builds.


## Why no binaries

This project intentionally does not provide:

- OpenRV executables  
- Qt binaries  
- FFmpeg binaries  
- Visual Studio components  
- other third-party dependencies

The intent is to document a reproducible build process rather than redistribute software owned by other projects.


## Limitations

Current limitations:

- GUI testing must still be performed on Windows with graphics.  
- This is not an officially supported OpenRV build environment.  
- Some dependencies may change over time as OpenRV evolves.


## References

- https://github.com/dockur/windows

- https://github.com/AcademySoftwareFoundation/OpenRV

- https://aswf-openrv.readthedocs.io/en/latest/build_system/config_common_build.html

- https://docs.docker.com/reference/

- https://doc.qt.io/qt-6.5/get-and-install-qt.html


## Licensing

This repository contains only original documentation, helper scripts, and patch files. All third-party software must be obtained from their respective projects under their own licenses.

