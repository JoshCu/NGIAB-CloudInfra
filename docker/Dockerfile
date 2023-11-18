################################################################################################################
################################################################################################################
##### Penultimate stage for image
FROM local/ngen as ngen-dev

# Remove the boost headers now that ngen is compiled; also update path and make sure dataset directory is there
RUN rm -rf ${BOOST_ROOT} && echo "export PATH=${PATH}" >> /etc/profile \
    && mkdir -p /dmod/datasets && chown root /dmod/datasets \
    && mkdir -p /dmod/datasets/static && chown root /dmod/datasets/static \
    && mkdir -p /dmod/shared_libs && chown root /dmod/shared_libs \
    && mkdir -p /dmod/bin && chown root /dmod/bin 

# Change permissions for entrypoint and make sure dataset volume mount parent directories exists
RUN for d in iso_c_fortran_bmi noah-owp-modular topmodel cfe sloth 'evapotranspiration/evapotranspiration'; do \
    if [ -d /ngen/extern/${d}/cmake_build ]; then \
    cp -a /ngen/extern/${d}/cmake_build/*.so* /dmod/shared_libs/.; \
    fi; \
    done \
    && find /ngen/extern/noah-owp-modular -type f -iname "*.TBL" -exec cp '{}' /dmod/datasets/static  \; \
    #&& ( cp -a ${WORKDIR}/ngen/cmake_build_parallel/ngen /dmod/bin/ngen-parallel || true ) \
    && ( cp -a /ngen/ngen /dmod/bin/ngen-serial || true ) \
    #&& ( cp -a ${WORKDIR}/ngen/cmake_build/partitionGenerator /dmod/bin/partitionGenerator || true ) \
    && pushd /dmod/bin \
    && ln -s ngen-serial ngen \
    #&& ( ( stat ngen-parallel && ln -s ngen-parallel ngen ) || ( stat ngen-serial && ln -s ngen-serial ngen ) ) \
    && popd 

ENV PATH=/ngen/:$PATH

RUN echo "/dmod/shared_libs/" >> /etc/ld.so.conf.d/ngen.conf && ldconfig -v

RUN mv /ngen /ngen-dev


COPY   HelloNGEN.sh /ngen/HelloNGEN.sh
RUN chown -R root /dmod /ngen /root
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh /root
#RUN rm -rf tmp/* var/* opt/*
WORKDIR /ngen
RUN mkdir /info/ && rpm -qa | sort > /info/rpm-qa.txt \
    && cp /tmp/requirements.txt /info/requirements.txt

ENTRYPOINT ["./HelloNGEN.sh"]
CMD [""]

FROM rockylinux:9.2-minimal as ngen-minimal

COPY --chown=root --from=ngen-dev /dmod/ /dmod/
COPY --chown=root --from=ngen-dev /usr/ /usr/
COPY --chown=root --from=ngen-dev /info/ /info/
COPY --chown=root --from=ngen-dev /tmp/requirements.txt /t-route/requirements.txt
COPY --chown=root --from=ngen-dev /t-route/wheels/ /t-route/wheels/
# copy troute.config
COPY --chown=root --from=ngen-dev /opt/venv/lib/python3.9/site-packages/troute /usr/local/lib/python3.9/site-packages/troute
RUN pip install /t-route/wheels/*.whl
RUN pip install $(grep -v "file://" /t-route/requirements.txt)

RUN echo "/dmod/shared_libs/" >> /etc/ld.so.conf.d/ngen.conf && ldconfig -v


COPY   HelloNGEN.sh /ngen/HelloNGEN.sh
RUN chown -R root /dmod /ngen /root
RUN chmod a+x /dmod/bin/* /ngen/HelloNGEN.sh /root
#RUN rm -rf tmp/* var/* opt/*
WORKDIR /ngen

ENTRYPOINT ["./HelloNGEN.sh"]
CMD [""]