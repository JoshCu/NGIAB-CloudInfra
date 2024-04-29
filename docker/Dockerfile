ARG VERSION
FROM ngen-${VERSION} as ngen

ARG DATASET_DIRECTORIES
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

COPY   HelloNGEN.sh /ngen/HelloNGEN.sh
RUN chown -R root /dmod /ngen /root
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh /root
#RUN rm -rf tmp var opt 
WORKDIR /ngen

ENTRYPOINT ["./HelloNGEN.sh"]
CMD [""]
