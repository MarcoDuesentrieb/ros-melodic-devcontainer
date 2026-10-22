# syntax=docker/dockerfile:1
FROM ubuntu:18.04 AS ros-base

ARG USERNAME=jetbot
ARG USER_UID=1000
ARG USER_GID=1000
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=melodic
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Basis-Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release ca-certificates sudo git wget \
    openssh-client iputils-ping net-tools \
    fortune vim \
    build-essential cmake python-pip patchelf \
    && rm -rf /var/lib/apt/lists/*

# VS Code Server requires GLIBC 2.28 or newer. Keep Ubuntu 18's system GLIBC
# intact and provide GLIBC 2.31 privately for the VS Code Server.
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) \
            glibc_multiarch=x86_64-linux-gnu; \
            focal_archive=http://archive.ubuntu.com/ubuntu; \
            focal_security=http://security.ubuntu.com/ubuntu ;; \
        arm64) \
            glibc_multiarch=aarch64-linux-gnu; \
            focal_archive=http://ports.ubuntu.com/ubuntu-ports; \
            focal_security=http://ports.ubuntu.com/ubuntu-ports ;; \
        *) echo "Unsupported architecture for the VS Code GLIBC runtime" >&2; exit 1 ;; \
    esac; \
    printf '%s\n' \
        "deb ${focal_archive} focal main" \
        "deb ${focal_archive} focal-updates main" \
        "deb ${focal_security} focal-security main" \
        > /etc/apt/sources.list.d/focal-glibc.list; \
    apt-get update; \
    cd /tmp; \
    apt-get download "libc6:$(dpkg --print-architecture)"; \
    mkdir -p /opt/glibc-2.31; \
    dpkg-deb -x libc6_*.deb /opt/glibc-2.31; \
    test -x "/opt/glibc-2.31/lib/${glibc_multiarch}/ld-2.31.so"; \
    ln -s "${glibc_multiarch}" /opt/glibc-2.31/lib/glibc; \
    ln -s glibc/ld-2.31.so /opt/glibc-2.31/lib/ld-linux-custom.so; \
    rm -f libc6_*.deb /etc/apt/sources.list.d/focal-glibc.list; \
    rm -rf /var/lib/apt/lists/*

# ROS Repository
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - \
    && echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" \
       > /etc/apt/sources.list.d/ros-latest.list

# ROS Melodic Desktop Full
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-melodic-desktop-full \
    ros-melodic-flexbe-onboard \
    ros-melodic-flexbe-mirror \
    ros-melodic-flexbe-widget \
    ros-melodic-flexbe-msgs \
    libnss3-dev \
    libxtst6 \
    mesa-utils \
    python-catkin-tools \
    python-rosdep \
    python-rosinstall \
    python-rosinstall-generator \
    python-wstool \
    && rm -rf /var/lib/apt/lists/*

# Build the patched FlexBE App and JetBot description as root. The builder
# stage is not part of the final image, so source and intermediate build
# products are not shipped.
FROM ros-base AS flexbe-build
COPY install/flexbe_app /tmp/flexbe_ws/src/flexbe_app
COPY install/jetbot_description /tmp/flexbe_ws/src/jetbot_description
RUN set -eux; \
    /tmp/flexbe_ws/src/flexbe_app/bin/nwjs_install; \
    bash -c 'source /opt/ros/melodic/setup.bash && \
        cd /tmp/flexbe_ws && \
        catkin_make_isolated --install \
            --install-space /opt/ros/melodic \
            --cmake-args \
            -DCMAKE_INSTALL_PREFIX=/opt/ros/melodic \
            -DCATKIN_ENABLE_TESTING=OFF'; \
    chmod +x /opt/ros/melodic/share/flexbe_app/nwjs/nw

FROM ros-base AS devcontainer
COPY --from=flexbe-build /opt/ros/melodic/share/flexbe_app /opt/ros/melodic/share/flexbe_app
COPY --from=flexbe-build /opt/ros/melodic/lib/flexbe_app /opt/ros/melodic/lib/flexbe_app
COPY --from=flexbe-build /opt/ros/melodic/share/jetbot_description /opt/ros/melodic/share/jetbot_description

# rosdep initialisieren
RUN rosdep init || true \
    && rosdep update || true

# User jetbot anlegen
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && usermod -aG sudo $USERNAME \
    && echo "$USERNAME:jetbot" | chpasswd \
    && echo "$USERNAME ALL=(ALL:ALL) ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && mkdir -p /vscode \
    && chown $USERNAME:$USERNAME /vscode

# ROS environment for interactive Bash shells.
RUN cat >> /etc/bash.bashrc <<'EOF'
source /opt/ros/melodic/setup.bash
if [ -f "$HOME/catkin_ws/devel_isolated/setup.bash" ]; then
    source "$HOME/catkin_ws/devel_isolated/setup.bash"
fi

if command -v glxinfo >/dev/null 2>&1; then
    nvidia_glx_info=$(env \
        __NV_PRIME_RENDER_OFFLOAD=1 \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        glxinfo -B 2>&1) || nvidia_glx_info=""
    if printf '%s\n' "$nvidia_glx_info" | grep -Fq "OpenGL vendor string: NVIDIA Corporation" \
        && printf '%s\n' "$nvidia_glx_info" | grep -Fq "OpenGL renderer string: NVIDIA"; then
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        echo "NVIDIA PRIME render offload enabled for this shell."
    fi
    unset nvidia_glx_info
fi
EOF

# Entry-Script
COPY .devcontainer/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER $USERNAME
WORKDIR /home/$USERNAME

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
