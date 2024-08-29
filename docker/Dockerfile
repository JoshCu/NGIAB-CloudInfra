FROM rockylinux:9.1 AS base

ENV BOOST_ROOT=/ngen/boost

# Install system dependencies
RUN dnf update -y && \
    dnf install -y epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf install -y \
    sudo vim gcc gcc-c++ make cmake ninja-build tar git gcc-gfortran libgfortran sqlite sqlite-devel \
    python3 python3-devel python3-pip python3-numpy gdal gdal-devel \
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
RUN git clone --depth 1 --single-branch --branch remove_geopandas https://github.com/JoshCu/t-route.git && \
    cd t-route && \
    git submodule update --init --depth 1 && \
    pip3 install -r requirements.txt && \
    ./compiler.sh no-e && \
    cd src/troute-network && python3 setup.py --use-cython bdist_wheel && \
    cd ../troute-routing && python3 setup.py --use-cython bdist_wheel && \
    cd ../troute-config && python3 -m build . && \
    cd ../troute-nwm && python3 -m build .

FROM troute_build AS ngen_clone
# Clone NGen
WORKDIR /ngen
RUN git clone --single-branch --branch master https://github.com/NOAA-OWP/ngen.git && \
    cd ngen && \
    git submodule update --init --recursive --depth 1

RUN cd /ngen/ngen/extern && rm -rf pybind11 && git clone https://github.com/pybind/pybind11.git && cd pybind11 && git checkout v2.12.0
FROM ngen_clone AS ngen_build

ENV PATH=${PATH}:/usr/lib64/mpich/bin

WORKDIR /ngen/ngen

# Install T-Route wheels
RUN pip3 install /ngen/t-route/src/troute-*/dist/*.whl

# PATCH
# Define common build arguments
ARG COMMON_BUILD_ARGS="-DNGEN_WITH_EXTERN_ALL=ON \
    -DNGEN_WITH_NETCDF:BOOL=ON \
    -DNGEN_WITH_BMI_C:BOOL=ON \
    -DNGEN_WITH_BMI_FORTRAN:BOOL=ON \
    -DNGEN_WITH_PYTHON:BOOL=ON \
    -DNGEN_WITH_ROUTING:BOOL=ON \
    -DNGEN_WITH_SQLITE:BOOL=ON \
    -DNGEN_WITH_UDUNITS:BOOL=ON \
    -DUDUNITS_QUIET:BOOL=ON \
    -DNGEN_WITH_TESTS:BOOL=OFF \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=."

# Build NGen (serial and parallel)
RUN cmake -G Ninja -B cmake_build_serial -S . ${COMMON_BUILD_ARGS} -DNGEN_WITH_MPI:BOOL=OFF && \
    cmake --build cmake_build_serial --target all -- -j $(nproc)
RUN cmake -G Ninja -B cmake_build_parallel -S . ${COMMON_BUILD_ARGS} -DNGEN_WITH_MPI:BOOL=ON && \
    cmake --build cmake_build_parallel --target all -- -j $(nproc)

FROM ngen_build AS restructure_files
# Setup final directories and permissions
RUN mkdir -p /dmod/datasets /dmod/datasets/static /dmod/shared_libs /dmod/bin && \
    cp -a ./extern/*/cmake_build/*.so* /dmod/shared_libs/. || true && \
    find ./extern/noah-owp-modular -type f -iname "*.TBL" -exec cp '{}' /dmod/datasets/static \; && \
    cp -a ./cmake_build_parallel/ngen /dmod/bin/ngen-parallel || true && \
    cp -a ./cmake_build_serial/ngen /dmod/bin/ngen-serial || true && \
    cp -a ./cmake_build_parallel/partitionGenerator /dmod/bin/partitionGenerator || true && \
    cd /dmod/bin && \
    (stat ngen-parallel && ln -s ngen-parallel ngen) || (stat ngen-serial && ln -s ngen-serial ngen)

FROM restructure_files AS dev

COPY  HelloNGEN.sh /ngen/HelloNGEN.sh
# Set up library path
RUN echo "/dmod/shared_libs/" >> /etc/ld.so.conf.d/ngen.conf && ldconfig -v
# Add mpirun to path
ENV PATH=$PATH:/usr/lib64/mpich/bin
# Set permissions
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh
RUN mv /ngen/ngen /ngen/ngen_src
WORKDIR /ngen
ENTRYPOINT ["./HelloNGEN.sh"]


FROM rockylinux:9.1 AS final

# Install only necessary runtime dependencies
RUN dnf update -y && \
    dnf install -y epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf install -y \
    vim libgfortran sqlite python3 gdal \
    bzip2 expat udunits2 zlib python3-pip \
    mpich hdf5 netcdf netcdf-fortran netcdf-cxx 
#&& \
#    dnf clean all 

# Copy necessary files from build stages
COPY  HelloNGEN.sh /ngen/HelloNGEN.sh
COPY --from=restructure_files /dmod /dmod
COPY --from=restructure_files /ngen/t-route/src/troute-*/dist/*.whl /tmp/

# Without this specific netCDF4 version, routing doesn't work via ngen
# but it works fine if you manually run the python -m nwm_routing etc
# Install T-Route wheels and other Python dependencies
RUN pip install --no-cache-dir /tmp/*.whl netCDF4==1.6.3 numpy==1.26.4 && \
    rm -rf /tmp/*.whl

# Set up library path
RUN echo "/dmod/shared_libs/" >> /etc/ld.so.conf.d/ngen.conf && ldconfig -v

# Add mpirun to path
ENV PATH=$PATH:/usr/lib64/mpich/bin

# Set permissions
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh

WORKDIR /ngen

ENTRYPOINT ["./HelloNGEN.sh"]
CMD [""]
