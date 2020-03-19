FROM ubuntu:rolling

ENV DEBIAN_FRONTEND noninteractive

# Timezone
ENV TZ=Europe/Berlin
RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && \
    printf "%s" "$TZ" > /etc/timezone

# Prohibit /usr/doc files from being installed
ADD 01_nodoc /etc/dpkg/dpkg.cfg.d/01_nodoc

# Install packages
RUN apt-get upgrade
RUN apt-get update
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get install -y apt-utils lsb-release
RUN apt-get install -y wget curl git
RUN apt-get install -y build-essential automake autoconf gfortran gdb
RUN apt-get install -y sudo
RUN apt-get install -y openmpi-bin

# Install required dependencies
RUN apt-get install -y libparmetis-dev

ARG DEP_DIR=/usr/local
RUN cd "$DEP_DIR" && mkdir -p src

ARG NJOBS=1

## CMake
RUN apt-get install libssl-dev
RUN cd "$DEP_DIR/src" && curl -LO https://github.com/Kitware/CMake/releases/download/v3.16.5/cmake-3.16.5.tar.gz && tar -xf cmake-3.16.5.tar.gz && cd cmake-3.16.5 && ./bootstrap --parallel=$NJOBS --prefix="$DEP_DIR" && make -j$NJOBS && make install

## KD-Part
RUN cd "$DEP_DIR/src" && git clone https://github.com/hirschsn/kdpart && cd kdpart && make CXXFLAGS="-std=c++14 -O3" -j$NJOBS && make install PREFIX="$DEP_DIR"

## P4est
RUN apt-get install -y libblas-dev liblapack-dev
RUN cd "$DEP_DIR/src" && git clone --recursive https://github.com/lahnerml/p4est --branch p4est-ESPResSo-integration && cd p4est && ./bootstrap && ./configure --enable-mpi --prefix="$DEP_DIR" && make -j$NJOBS install

## Boost
RUN cd "$DEP_DIR/src" && curl -LO https://dl.bintray.com/boostorg/release/1.67.0/source/boost_1_67_0.tar.gz && tar -xf boost_1_67_0.tar.gz && cd boost_1_67_0 && ./bootstrap.sh --prefix="$DEP_DIR" --with-libraries=all && echo "using mpi ;" >> project-config.jam && ./b2 -j$NJOBS install

## CGAL
RUN apt-get install -y libgmp-dev libmpfr-dev
RUN cd "$DEP_DIR/src" && curl -LO https://github.com/CGAL/cgal/releases/download/releases%2FCGAL-5.0.2/CGAL-5.0.2.tar.xz && tar -xf CGAL-5.0.2.tar.xz && cd CGAL-5.0.2 && cmake . -DCMAKE_INSTALL_PREFIX="$DEP_DIR" && make -j$NJOBS install

## Clang-format for style checking
RUN apt-get install -y clang-format

# Cleanup
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
RUN rm -rf $DEP_DIR/src

# Create user
ARG USER_NAME=u
ARG USER_HOME=/home/u
ARG USER_ID=1000
ARG GROUP_ID=1001

RUN groupadd -g $GROUP_ID "$USER_NAME"
RUN adduser \
    --home "$USER_HOME" \
    --uid $USER_ID \
    --gid $GROUP_ID \
    --disabled-password \
    "$USER_NAME"

RUN echo "$USER_NAME" ALL=\(root\) NOPASSWD:ALL > "/etc/sudoers.d/$USER_NAME" && \
    chmod 0440 "/etc/sudoers.d/$USER_NAME"

USER "$USER_NAME"
WORKDIR "$USER_HOME"

CMD ["bash"]

# Reset frontend for interactive use
ENV DEBIAN_FRONTEND=

