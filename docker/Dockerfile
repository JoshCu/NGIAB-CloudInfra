FROM rockylinux:9.1 as rocky-base
ENV ROCKY_NGEN_DEPS_REQUIRED="sudo gcc gcc-c++ make cmake tar git gcc-gfortran libgfortran sqlite sqlite-devel \
    python3 python3-devel python3-pip gdal gdal-devel\
    bzip2 expat expat-devel flex bison udunits2 udunits2-devel zlib-devel" \
    BOOST_VERSION="1.79.0" \
    MPICH_VERSION="3.3.2" \
    NETCDF_C_VERSION="4.8.1" \
    NETCDF_CXX_VERSION="4.3.1" \
    NETCDF_FORTRAN_VERSION="4.6.0" \
    HD5_VERSION="1.10.9" \
    NGEN_ACTIVATE_PYTHON="ON" \
    HYDRA_HOST_FILE=/etc/opt/hosts
RUN dnf install -y wget

FROM rocky-base as dnf-update

RUN dnf update -y 
RUN dnf install -y 'dnf-command(config-manager)' 
RUN dnf config-manager --set-enabled crb 
RUN dnf install -y epel-release 
RUN dnf update -y 
RUN dnf -y install sudo bash git wget
# Install security updates
RUN dnf upgrade -y

FROM rocky-base AS downloads

WORKDIR /tmp/downloads

RUN wget https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION//./_}.tar.bz2 -O boost.tar.bz2
RUN wget https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz 
RUN wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-${HD5_VERSION}/src/hdf5-${HD5_VERSION}.tar.gz

RUN curl -L https://api.github.com/repos/Unidata/netcdf-c/tarball/v${NETCDF_C_VERSION} --output netcdf-c.tar.gz
RUN curl -L https://api.github.com/repos/Unidata/netcdf-fortran/tarball/v${NETCDF_FORTRAN_VERSION} --output netcdf-fortran.tar.gz
RUN curl -L https://api.github.com/repos/Unidata/netcdf-cxx4/tarball/v${NETCDF_CXX_VERSION} --output netcdf-cxx.tar.gz

FROM dnf-update as pip_and_dnf_deps

RUN dnf install -y ${ROCKY_NGEN_DEPS_REQUIRED} 
RUN pip3 install --upgrade pip \
    && pip3 install numpy pandas pyyaml bmipy Cython==3.0.3 netCDF4==1.6.3 wheel packaging opencv-contrib-python-headless \
    && pip3 install -v --no-build-isolation tables


WORKDIR /build_mpich
COPY --from=downloads /tmp/downloads/*mpich* .
RUN tar xfz mpich-${MPICH_VERSION}.tar.gz  \
    && cd mpich-${MPICH_VERSION} \
    && FFLAGS="-w -fallow-argument-mismatch -O2" ./configure \
    && make -j $(nproc) \
    && make install

WORKDIR /build_hdf5
COPY --from=downloads /tmp/downloads/*hdf5* .
RUN tar --strip-components=2 -xzf hdf5-${HD5_VERSION}.tar.gz \
    && ./configure --enable-parallel --prefix=/usr \
    && make -j $(nproc) \
    && make install

WORKDIR /build_netcdf_c
COPY --from=downloads /tmp/downloads/netcdf-c.tar.gz .
RUN tar --strip-components=1 -xzf netcdf-c.tar.gz \
    && ./configure --prefix=/usr \
    && make -j $(nproc) \
    && make install

WORKDIR /build_netcdf_fortran
COPY --from=downloads /tmp/downloads/netcdf-fortran.tar.gz .
RUN tar --strip-components=1 -xzf netcdf-fortran.tar.gz \
    && export NCDIR=/usr NFDIR=/usr \
    && LD_LIBRARY_PATH=/usr/lib CPPFLAGS=-I/usr/include LDFLAGS=-L/usr/lib ./configure --prefix=/usr \
    && make -j $(nproc) \
    && make install

WORKDIR /build_netcdf_cxx
COPY --from=downloads /tmp/downloads/netcdf-cxx.tar.gz . 
RUN tar --strip-components=1 -xzf netcdf-cxx.tar.gz \
    && mkdir build \
    && cd build \
    && ../configure --enable-parallel --prefix=/usr \
    && cmake .. \
    && make -j $(nproc) \
    && make install

ENV BOOST_ROOT=/ngen/boost

WORKDIR $BOOST_ROOT
COPY --from=downloads /tmp/downloads/boost.tar.bz2 .
RUN tar --strip-components=1 -xjf boost.tar.bz2 \
    && rm boost.tar.bz2 

RUN touch ${HYDRA_HOST_FILE} \
    && alias pip='pip3' \
    && echo "alias pip='pip3'" >> /etc/profile \
    && alias python='python3'  \
    && echo "alias python='python3'" >> /etc/profile 

ENV PATH=${PATH}:/usr/lib64/mpich/bin
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/lib:/usr/local/lib64
## TROUTE
FROM pip_and_dnf_deps as build_troute
ARG TROUTE_REPO_URL="https://github.com/NOAA-OWP/t-route.git" \
    TROUTE_BRANCH="master" \
    TROUTE_COMMIT="e7eba47dc32ca64b8b087bac14b3c1bb4145fc65"

WORKDIR /ngen
RUN dnf install git -y
RUN git clone --single-branch --branch $TROUTE_BRANCH $TROUTE_REPO_URL \
    && cd t-route \
    && if [ -n "$TROUTE_COMMIT" ]; then git reset --hard $TROUTE_COMMIT; fi \
    && git submodule update --init --depth 1

WORKDIR /ngen/t-route

RUN cp -s /usr/bin/python3 /usr/bin/python \
    && pip install build \
    && mkdir wheels \
    && pip3 install -r ./requirements.txt \
    && pip3 install wheel deprecated dask pyarrow geopandas

ENV FC=gfortran NETCDF=/usr/include

RUN ./compiler.sh \
    && cd src/troute-network \
    && python3 setup.py --use-cython bdist_wheel \
    && cp dist/*.whl /ngen/t-route/wheels/ \
    && cd ../troute-routing \
    && python3 setup.py --use-cython bdist_wheel \
    && cp dist/*.whl /ngen/t-route/wheels/ \
    && cd ../troute-config \
    && python3 -m build . \
    && cp dist/*.whl /ngen/t-route/wheels/ \
    && cd ../troute-nwm \
    && python3 setup.py bdist_wheel \
    && cp dist/*.whl /ngen/t-route/wheels/

### NGEN
FROM pip_and_dnf_deps as clone_ngen

ENV NGEN_ACTIVATE_C="ON" \
    NGEN_ACTIVATE_FORTRAN="ON" \
    NGEN_ACTIVATE_PYTHON="ON" \
    NGEN_NETCDF_ACTIVE="ON" \
    NGEN_ROUTING_ACTIVE="ON" \
    NGEN_WITH_SQLITE="ON" \
    NGEN_UDUNITS_ACTIVE="ON" \
    NGEN_UDUNITS_QUIET="ON" \
    BUILD_NGEN_SERIAL="true" \
    BUILD_NGEN_PARALLEL="true" \
    BOOST_ROOT=/ngen/boost

ENV REPO_URL=https://github.com/NOAA-OWP/ngen.git \
    BRANCH=master \
    COMMIT=f91e2ea

WORKDIR /ngen

RUN if [ -n "$COMMIT"]; then \
    git clone --single-branch --depth 1 --branch $BRANCH $REPO_URL \
    && cd ./ngen ; \
    else \
    git clone --single-branch --branch $BRANCH $REPO_URL \
    && cd ./ngen \
    && git checkout $COMMIT; \
    fi \
    && git submodule update --init --depth 1 test/googletest \
    && git submodule update --init --recursive --depth 1

FROM clone_ngen as build_ngen
COPY --chown=root --from=build_troute /ngen/t-route/wheels /tmp/t-route-wheels
COPY --chown=root --from=build_troute /ngen/t-route/requirements.txt /tmp/t-route-requirements.txt


WORKDIR /ngen/ngen

RUN if [ "${NGEN_ACTIVATE_PYTHON}" == "ON" ]; then \
    pip3 install -r extern/test_bmi_py/requirements.txt; \
    if [ "${NGEN_ROUTING_ACTIVE}" == "ON" ] ; then \
    pip3 install /tmp/t-route-wheels/*.whl; \
    pip3 install -r /tmp/t-route-requirements.txt; \
    pip3 install deprecated geopandas ; \
    fi; \
    fi 

RUN if [ "${NGEN_ROUTING_ACTIVE}" == "ON" ]; then \
    # These packages install command line tools, which try to go in /usr/local/bin \
    pip3 install pyarrow pyproj fiona; \
    fi

RUN sed -i 's/#define CFE_DEBUG 1/#define CFE_DEBUG 0/g' extern/cfe/cfe/src/bmi_cfe.c
#COPY bmi_cfe.c extern/cfe/cfe/src/bmi_cfe.c
COPY Formulation_Manager.hpp include/realizations/catchment/Formulation_Manager.hpp
COPY NGen.cpp src/NGen.cpp
#RUN sed -i 's/std::regex/boost::regex/g' include/realizations/catchment/Formulation_Manager.hpp

# RUN sed -i 's|#include <regex>|#include <re2/re2.h>|g' include/realizations/catchment/Formulation_Manager.hpp
# RUN sed -i 's/std::regex pattern(filepattern);/RE2 pattern(filepattern);/g' include/realizations/catchment/Formulation_Manager.hpp
# RUN sed -i 's/std::regex_match/RE2::FullMatch/g' include/realizations/catchment/Formulation_Manager.hpp

# RUN dnf install -y epel-release
# RUN dnf install -y re2-devel

# COPY CMakeLists.txt CMakeLists.txt
# ENV RE2_DIR=/usr/lib64/cmake/re2

# RUN if [ "${NGEN_ACTIVATE_PYTHON}" == "ON" ]; then \
#     chgrp -R root /usr/local/lib*/python3.* ; \
#     chmod -R g+sw /usr/local/lib*/python3.* ; \
#     fi 

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
    #    -DNGEN_QUIET:BOOL=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=. "


RUN if [ "${BUILD_NGEN_SERIAL}" == "true" ]; then \
    cmake -B cmake_build_serial -S . \
    ${COMMON_BUILD_ARGS} \
    -DNGEN_WITH_MPI:BOOL=OFF; \
    cmake --build cmake_build_serial --target all -j $(nproc); \
    fi 
RUN if [ "${BUILD_NGEN_PARALLEL}" == "true" ]; then \
    cmake -B cmake_build_parallel -S . \
    ${COMMON_BUILD_ARGS} \
    -DNGEN_WITH_MPI:BOOL=ON; \
    cmake --build cmake_build_parallel --target all -j $(nproc); \
    fi 
WORKDIR /ngen/ngen
# run the serial tests \
# && cmake --build cmake_build_serial --target test \ 
# have to remove the output from the previous tests runs for routing test to be run again... \
# RUN rm -f ./test/data/routing/*.parquet \
#     # run the parallel tests \
#     # && cmake --build cmake_build_parallel --target test \
#     # clean these up again... \
#     # && rm -f ./test/data/routing/*.parquet \
#     #Run the MPI tests manually, they don't play well with ctest and are skipped in the above tests \
#     && mpirun -n 2 cmake_build_parallel/test/test_remote_nexus \
#     && mpirun -n 3 cmake_build_parallel/test/test_remote_nexus \
#     && mpirun -n 4 cmake_build_parallel/test/test_remote_nexus \
#     && find cmake_build* -type f -name "*" ! \( -name "*.so" -o -name "ngen" -o -name "partitionGenerator" \) -exec rm {} + 

FROM build_ngen as ngen
# Remove the boost headers now that ngen is compiled; also update path and make sure dataset directory is there
RUN rm -rf ${BOOST_ROOT} && echo "export PATH=${PATH}" >> /etc/profile \
    && mkdir -p /dmod/datasets && chown root /dmod/datasets \
    && mkdir -p /dmod/datasets/static && chown root /dmod/datasets/static \
    && mkdir -p /dmod/shared_libs && chown root /dmod/shared_libs \
    && mkdir -p /dmod/bin && chown root /dmod/bin 


WORKDIR /ngen


# Change permissions for entrypoint and make sure dataset volume mount parent directories exists
# chmod +x ./entrypoint.sh \
RUN for d in iso_c_fortran_bmi noah-owp-modular topmodel cfe sloth 'evapotranspiration/evapotranspiration'; do \
    if [ -d ./ngen/extern/${d}/cmake_build ]; then \
    cp -a ./ngen/extern/${d}/cmake_build/*.so* /dmod/shared_libs/.; \
    fi; \
    done \
    && find ./ngen/extern/noah-owp-modular -type f -iname "*.TBL" -exec cp '{}' /dmod/datasets/static  \; \
    && ( cp -a ./ngen/cmake_build_parallel/ngen /dmod/bin/ngen-parallel || true ) \
    && ( cp -a ./ngen/cmake_build_serial/ngen /dmod/bin/ngen-serial || true ) \
    && ( cp -a ./ngen/cmake_build_parallel/partitionGenerator /dmod/bin/partitionGenerator || true ) \
    && pushd /dmod/bin \
    && ( ( stat ngen-parallel && ln -s ngen-parallel ngen ) || ( stat ngen-serial && ln -s ngen-serial ngen ) ) \
    && popd 

ENV PATH=${WORKDIR}:$PATH

################################################################################################################
##### Final stage for image
FROM rockylinux:9.1-minimal

########################################Copy over the NGEN artifacts############################################
COPY --chown=root --from=ngen /dmod/ /dmod/
COPY --chown=root --from=ngen /usr/ /usr/
########################################Relink the files########################################################
RUN echo "/dmod/shared_libs/" >> /etc/ld.so.conf.d/ngen.conf && ldconfig -v

RUN wget https://raw.githubusercontent.com/JoshCu/t-route/parallel_csv_to_parquet/src/troute-network/troute/AbstractNetwork.py
RUN cp AbstractNetwork.py /usr/local/lib64/python3.9/site-packages/troute/AbstractNetwork.py
COPY   HelloNGEN.sh /ngen/HelloNGEN.sh
#RUN chown -R root /dmod /ngen /root
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh /root
#RUN rm -rf tmp var opt 
WORKDIR /ngen

ENTRYPOINT ["./HelloNGEN.sh"]
CMD [""]
