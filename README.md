# One Container to rule them all

This repository contains a development container setup for **ROS Melodic**, *aiming* to be compatible with **Windows**, **Linux**,  and **Mac**. Furthermore, it supports both amd64 and arm64 architectures.

The container is configured to provide a complete development environment with necessary tools and extensions for ROS development in VS Code.

> [!IMPORTANT]
> Currently, the Dev Container has *only* been tested on **Ubuntu 26.04** on **amd64** architecture with NVIDIA GeForce RTX 5050 GPU. There were no issues observed in this setup. 
>
> Other operating systems, architectures, or GPU configurations may require additional testing and adjustments.

## Features

- Supports both amd64 and arm64 architectures
- Pre-configured ROS Melodic environment
- VS Code extensions for ROS, C++, Python, and CMake
- X11 forwarding for GUI applications

## Usage

1. Clone this repository to your local machine

```bash
https://github.com/MarcoDuesentrieb/ros-melodic-devcontainer.git
```

2. Open the cloned repository in VS Code.
3. Open the Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P` on Mac) and select `Remote-Containers: Open Folder in Container...`. Wait for the container to build and start. This may take a few minutes depending on your system and network speed.
4. Once the container is running, you can open a terminal in VS Code and start developing with the pre-configured ROS Melodic environment. To verify the setup, you can try the `roswtf`command, which should give the following output:

```bash
Loaded plugin tf.tfwtf
No package or stack in the current directory
================================================================================
Static checks summary:

No errors or warnings
================================================================================

ROS Master does not appear to be running.
Online graph checks will not be run.
ROS_MASTER_URI is [http://localhost:11311]
```

## Container build and configuration

The Dockerfile is the reproducible recipe for the preinstalled system; build it when changing system software. `flexbe_app` and `jetbot_description` are compiled and installed as root with `catkin_make_isolated --install` in a builder stage, then only their installed files are copied into the final image. The source/build workspace is not shipped in the runtime image.

The container root filesystem is mounted read-only. `/home/jetbot` is a temporary writable filesystem, so the user can download and upload files there while the container exists. `catkin_ws` is inside this temporary home; the entrypoint creates a fresh workspace and runs `catkin_make_isolated` to generate `devel_isolated/setup.bash`. Changes under the home directory are lost when the container is removed or recreated. Disconnecting VS Code alone does not remove or reset the container.

For ROS Melodic editor support, `devcontainer.json` selects `/usr/bin/python` (Python 2.7) and adds ROS plus workspace Python package directories to `python.analysis.extraPaths`. This is needed because Pylance does not automatically search ROS Melodic's `python2.7/dist-packages` path.

## GPU support for Gazebo

The Dev Container requests all NVIDIA GPUs (`--gpus=all`) and enables the NVIDIA graphics, display, and utility driver capabilities. The host must have working NVIDIA drivers and NVIDIA Container Toolkit support configured for its Docker engine. On Windows, this means Docker Desktop with WSL 2 GPU support; on Jetson, use the JetPack-provided NVIDIA container runtime.

Rebuild the Dev Container after changing its configuration. Verify GPU access inside the container with `nvidia-smi` where supported, and check that Gazebo is using hardware OpenGL (for example, with `glxinfo -B`). GPU passthrough enables hardware rendering, but reaching decent (>30) FPS still depends on the host GPU, display forwarding, world complexity, and Gazebo workload. On NVIDIA PRIME laptops, the interactive `jetbot` Bash shell checks `glxinfo` on startup and exports the PRIME offload variables only if the NVIDIA OpenGL renderer is available.

## Container files and runtime package installs

The root filesystem is read-only. The temporary home filesystem is writable, but its contents are lost when the container is removed. Runtime `apt` installs cannot persist in this setup; add system dependencies to the Dockerfile and rebuild the image.

Temporary runtime directories `/tmp`, `/run`, and `/var/tmp` use in-memory filesystems. The Dev Containers extension also mounts a named `/vscode` volume for its server and extensions; this volume survives container recreation. The preinstalled ROS environment is loaded from the image's system Bash configuration.

GPU access is provided with `--gpus=all`; NVIDIA OpenGL and X11 rendering were verified without `--privileged`. `--network=host` is still enabled for ROS networking and gives the container access to the host network namespace.

## install directory

The Docker build installs additional ROS packages located in the `install` directory, including the patched package in `flexbe_app` and the `jetbot_description` package, and runs `catkin_make_isolated --install` as root to install both into `/opt/ros/melodic`.

The FlexBE UI patch removes the upstream release-notification banner, and `bin/run_app` uses a quoted, executable-checked NW.js launch.

> [!CAUTION]
> NW.js 0.42.3 is available for x86_64 and x86; its upstream release does not provide a Linux ARM64 binary, so the installer stops with a clear error on ARM64 rather than trying to run an x86 binary. The NW.js runtime must be replaced with a Jetson-compatible build before this package can be installed on Jetson.

## VS Code Server on Ubuntu 18.04

The image provides a private GLIBC 2.31 runtime for the VS Code Server while keeping Ubuntu 18.04's system GLIBC unchanged. The `vscode` Docker volume must be writable by `jetbot` so VS Code can patch its server binaries. The image prepares `/vscode` with the correct ownership for new volumes. If the volume already exists and is owned by root, repair it once (replace `1000:1000` if using different `USER_UID`/`USER_GID` build arguments):

```bash
docker run --rm --user 0 \
  --mount type=volume,source=vscode,target=/vscode \
  ubuntu:18.04 chown -R 1000:1000 /vscode
```
