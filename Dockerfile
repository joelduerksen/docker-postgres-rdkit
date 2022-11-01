FROM postgres:12 AS build

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    wget \
    libboost-all-dev \
    libcairo2-dev \
    libeigen3-dev \
    python3-dev \
    python3-numpy \
    postgresql-server-dev-12 \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

ARG RDKIT_VERSION=Release_2022_03_4
RUN wget --quiet https://github.com/rdkit/rdkit/archive/refs/tags/${RDKIT_VERSION}.tar.gz \
 && tar -xzf ${RDKIT_VERSION}.tar.gz \
 && mv rdkit-${RDKIT_VERSION} rdkit \
 && rm ${RDKIT_VERSION}.tar.gz

WORKDIR /rdkit

RUN cmake -Wno-dev \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D RDK_BUILD_PGSQL=ON \
    -D RDK_PGSQL_STATIC=OFF \
    -D PostgreSQL_CONFIG_DIR=/usr/lib/postgresql/12/bin \
    -D PostgreSQL_INCLUDE_DIR=/usr/include/postgresql \
    -D PostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/12/server \
    -D PostgreSQL_LIBRARY_DIR=/usr/lib/postgresql/12/lib \
    -D Boost_NO_BOOST_CMAKE=ON \
    -D PYTHON_EXECUTABLE=/usr/bin/python3 \
    -D RDK_BUILD_AVALON_SUPPORT=ON \
    -D RDK_BUILD_CAIRO_SUPPORT=ON \
    -D RDK_BUILD_CPP_TESTS=OFF \
    -D RDK_BUILD_INCHI_SUPPORT=ON \
    -D RDK_BUILD_FREESASA_SUPPORT=ON \
    -D RDK_INSTALL_INTREE=OFF \
    -D RDK_INSTALL_STATIC_LIBS=OFF \
    .

RUN make -j $(nproc) \
 && make install

# thin docker image, only the minimum required
FROM postgres:12 AS baseimage

# Install runtime dependencies
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    libboost-atomic1.74.0 \
    libboost-chrono1.74.0 \
    libboost-date-time1.74.0 \
    libboost-iostreams1.74.0 \
    libboost-python1.74.0 \
    libboost-regex1.74.0 \
    libboost-serialization1.74.0 \
    libboost-system1.74.0 \
    libboost-thread1.74.0 \
    libcairo2-dev \
    python3-dev \
    python3-numpy \
    python3-cairo \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Copy rdkit installation from build
COPY --from=build /usr/lib/libRDKit* /usr/lib/
COPY --from=build /usr/lib/cmake/rdkit/* /usr/lib/cmake/rdkit/
COPY --from=build /usr/share/RDKit /usr/share/RDKit
COPY --from=build /usr/include/rdkit /usr/include/rdkit
COPY --from=build /usr/lib/python3/dist-packages/rdkit /usr/lib/python3/dist-packages/rdkit

# # Copy rdkit postgres extension from build
COPY --from=build /usr/share/postgresql/12/extension/rdkit--4.2.0.sql /usr/share/postgresql/12/extension
COPY --from=build /usr/share/postgresql/12/extension/rdkit.control /usr/share/postgresql/12/extension
COPY --from=build /usr/lib/postgresql/12/lib/rdkit.so /usr/lib/postgresql/12/lib/rdkit.so
