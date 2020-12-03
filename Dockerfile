# Plone build and runtime using piptools instead of buildout.
ARG PLONE_ROOT=/opt/plone

# Phase one, Build:
FROM python:3.8-slim-buster as build

ARG PLONE_ROOT

# Define whether we're building a production or a development image. This will
# generally be used to control whether or not we install our development and
# test dependencies.
ARG DEVEL=no

RUN mkdir $PLONE_ROOT

# Install System level build requirements
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        dpkg-dev \
        gcc \
        git \
        libbz2-dev \
        libc6-dev \
        libffi-dev \
        libjpeg62-turbo-dev \
        libpcre3-dev \
        libpng-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev

# We create an /opt directory with a virtual environment in it to store our
# application in.
RUN set -x \
    && python3 -m venv $PLONE_ROOT

# Now that we've created our virtual environment, we'll go ahead and update
# our $PATH to refer to it first.
ENV PATH="${PLONE_ROOT}/bin:${PATH}"

# Next, we want to update pip, setuptools, and wheel inside of this virtual
# environment to ensure that we have the latest versions of them.
# TODO: We use --require-hashes in our requirements files, but not here, making
#       the ones in the requirements files kind of a moot point. We should
#       probably pin these too, and update them as we do anything else.
RUN pip --no-cache-dir --disable-pip-version-check install --upgrade -r https://dist.plone.org/release/5.2.3/requirements.txt

# Install the Python level requirements, this is done after copying
# the requirements but prior to copying zope itself into the container so
# that code changes don't require triggering an entire install of all of
# Plone's dependencies.
RUN set -x \
    && pip --no-cache-dir --disable-pip-version-check install \
        Plone Paste -c https://dist.plone.org/release/5.2.3/constraints3.txt  \
    && find $PLONE_ROOT -name '*.pyc' -delete

# Install our deploy and optionally our development dependencies if we're building a development install
# otherwise this will do nothing.

COPY requirements /tmp/
RUN ls -al /tmp
RUN set -x \
    && pip --no-cache-dir --disable-pip-version-check install -r /tmp/deploy.txt \
    && if [ "$DEVEL" = "yes" ]; then pip --no-cache-dir --disable-pip-version-check install -r /tmp/dev.txt; fi

# Phase Two: the Runtime image

# Now we're going to build our actual application image, which will eventually
# pull in the static files that were built above.
FROM python:3.8-slim-buster
ARG PLONE_ROOT

# Setup some basic environment variables that are ~never going to change.
ENV PYTHONUNBUFFERED 1
ENV PATH="${PLONE_ROOT}/bin:${PATH}"
ENV PLONE_ROOT $PLONE_ROOT

# Define whether we're building a production or a development image. This will
# generally be used to control whether or not we install our development and
# test dependencies.
ARG DEVEL=no

# pre-create directories for plone's logs and assets.
RUN set -x \
    && mkdir -p ${PLONE_ROOT}/var/log \
    && mkdir -p ${PLONE_ROOT}/var/blobstorage \
    && mkdir -p ${PLONE_ROOT}/var/filestorage

# This is a work around because otherwise postgresql-client bombs out trying
# to create symlinks to these directories.
RUN set -x \
    && mkdir -p /usr/share/man/man1 \
    && mkdir -p /usr/share/man/man7

# Install System level requirements
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        dumb-init \
        libjpeg62-turbo \
        libxml2 \
        libxslt1.1 \
        lynx \
        poppler-utils \
        wv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy the build codebase into the Runtime, and add our config file from ./etc
COPY --from=build $PLONE_ROOT $PLONE_ROOT
COPY etc ${PLONE_ROOT}/etc

# Add an inituser to the /opt/plone directory with an admin user and random password 
# TODO: take from the environment or arg
RUN RAND_PASS=$(</dev/urandom tr -dc A-Za-z0-9-_ | head -c 10) \
    && echo "\n\nIMPORTANT!\n\nThe init user and password you'll need is:  admin:${RAND_PASS}\n\n"  \
    && (echo "admin:${RAND_PASS}" > ${PLONE_ROOT}/inituser)

EXPOSE 8080
WORKDIR $PLONE_ROOT
ENV Z3C_AUTOINCLUDE_DEPENDENCIES_DISABLED True
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD [ "bin/runwsgi", "etc/wsgi.ini" ]
