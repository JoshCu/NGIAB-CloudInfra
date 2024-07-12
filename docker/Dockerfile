FROM rockylinux:9.1 AS base

ENV NGEN_ACTIVATE_PYTHON="ON" \
    NGEN_ACTIVATE_C="ON" \
    NGEN_ACTIVATE_FORTRAN="ON" \
    NGEN_NETCDF_ACTIVE="ON" \
    NGEN_ROUTING_ACTIVE="ON" \
    NGEN_WITH_SQLITE="ON" \
    NGEN_UDUNITS_ACTIVE="ON" \
    NGEN_UDUNITS_QUIET="ON" \
    BUILD_NGEN_SERIAL="true" \
    BUILD_NGEN_PARALLEL="true" \
    BOOST_ROOT=/ngen/boost

# Install system dependencies
RUN dnf update -y && \
    dnf install -y epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf install -y \
    sudo gcc gcc-c++ make cmake tar git gcc-gfortran libgfortran sqlite sqlite-devel \
    python3 python3-devel python3-pip gdal gdal-devel \
    bzip2 expat expat-devel flex bison udunits2 udunits2-devel zlib-devel \
    wget mpich mpich-devel hdf5 hdf5-devel netcdf netcdf-devel \
    netcdf-fortran netcdf-fortran-devel netcdf-cxx netcdf-cxx-devel && \
    dnf clean all

FROM base AS boost_build
RUN wget https://archives.boost.io/release/1.79.0/source/boost_1_79_0.tar.gz
RUN tar -xzf boost_1_79_0.tar.gz
WORKDIR /boost_1_79_0
RUN ./bootstrap.sh
RUN ./b2 
RUN ./b2 headers
ENV BOOST_ROOT=/boost_1_79_0

FROM boost_build AS troute_build
# Clone and build T-Route
WORKDIR /ngen
## troute looks for netcdf.mod in the wrong place unless we set this
ENV FC=gfortran NETCDF=/usr/lib64/gfortran/modules/
## it also tries to use python instead of python3
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN pip3 install --upgrade pip
RUN pip install wheel build
RUN git clone --single-branch --branch master https://github.com/NOAA-OWP/t-route.git && \
    cd t-route && \
    git checkout e7eba47dc32ca64b8b087bac14b3c1bb4145fc65 && \
    git submodule update --init --depth 1 && \
    pip3 install -r requirements.txt && \
    ./compiler.sh && \
    cd src/troute-network && python3 setup.py --use-cython bdist_wheel && \
    cd ../troute-routing && python3 setup.py --use-cython bdist_wheel && \
    cd ../troute-config && python3 -m build . && \
    cd ../troute-nwm && python3 setup.py bdist_wheel

FROM troute_build AS ngen_clone
# Clone NGen
WORKDIR /ngen
RUN git clone --single-branch --branch master https://github.com/NOAA-OWP/ngen.git && \
    cd ngen && \
    git checkout f91e2ea && \
    git submodule update --init --recursive --depth 1

RUN dnf install -y vim
FROM ngen_clone AS ngen_build

ENV PATH=${PATH}:/usr/lib64/mpich/bin

WORKDIR /ngen/ngen

# Install T-Route wheels
RUN pip3 install /ngen/t-route/src/troute-*/dist/*.whl


# Define common build arguments
ARG COMMON_BUILD_ARGS="-DNGEN_WITH_EXTERN_ALL=ON \
    -DNGEN_WITH_NETCDF:BOOL=${NGEN_NETCDF_ACTIVE} \
    -DNGEN_WITH_BMI_C:BOOL=${NGEN_ACTIVATE_C} \
    -DNGEN_WITH_BMI_FORTRAN:BOOL=${NGEN_ACTIVATE_FORTRAN} \
    -DNGEN_WITH_PYTHON:BOOL=${NGEN_ACTIVATE_PYTHON} \
    -DNGEN_WITH_ROUTING:BOOL=${NGEN_ROUTING_ACTIVE} \
    -DNGEN_WITH_SQLITE:BOOL=${NGEN_WITH_SQLITE} \
    -DNGEN_WITH_UDUNITS:BOOL=${NGEN_UDUNITS_ACTIVE} \
    -DUDUNITS_QUIET:BOOL=${NGEN_UDUNITS_QUIET} \
    -DNGEN_WITH_TESTS:BOOL=OFF \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=."

# Build NGen (serial and parallel)
RUN cmake -B cmake_build_serial -S . ${COMMON_BUILD_ARGS} -DNGEN_WITH_MPI:BOOL=OFF && \
    cmake --build cmake_build_serial --target all -j $(nproc) && \
    cmake -B cmake_build_parallel -S . ${COMMON_BUILD_ARGS} -DNGEN_WITH_MPI:BOOL=ON && \
    cmake --build cmake_build_parallel --target all -j $(nproc)

FROM ngen_build AS final
# Setup final directories and permissions
RUN mkdir -p /dmod/datasets /dmod/datasets/static /dmod/shared_libs /dmod/bin && \
    cp -a ./extern/*/cmake_build/*.so* /dmod/shared_libs/. || true && \
    find ./extern/noah-owp-modular -type f -iname "*.TBL" -exec cp '{}' /dmod/datasets/static \; && \
    cp -a ./cmake_build_parallel/ngen /dmod/bin/ngen-parallel || true && \
    cp -a ./cmake_build_serial/ngen /dmod/bin/ngen-serial || true && \
    cp -a ./cmake_build_parallel/partitionGenerator /dmod/bin/partitionGenerator || true && \
    cd /dmod/bin && \
    (stat ngen-parallel && ln -s ngen-parallel ngen) || (stat ngen-serial && ln -s ngen-serial ngen)

# Set up library path
RUN echo "/dmod/shared_libs/" >> /etc/ld.so.conf.d/ngen.conf && ldconfig -v

# Without this, routing doesn't work via ngen
# but it works fine if you manually run the python -m nwm_routing etc
RUN pip install netCDF4==1.6.3

# Copy HelloNGEN.sh script
COPY HelloNGEN.sh /ngen/HelloNGEN.sh
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh

WORKDIR /ngen

ENTRYPOINT ["./HelloNGEN.sh"]
CMD [""]