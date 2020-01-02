# Now we're going to build our actual application, but not the actual production
# image that it gets deployed into.
FROM python:3.7-slim-buster as build

# Define whether we're building a production or a development image. This will
# generally be used to control whether or not we install our development and
# test dependencies.
ARG DEVEL=no

ARG ZOPE_VERSION=4.1.2

ARG PLONE_ROOT=/opt/plone
RUN mkdir $PLONE_ROOT

# Install System level build requirements, this is done before
# everything else because these are rarely ever going to change.
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        dpkg-dev \
        gcc \
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
RUN pip --no-cache-dir --disable-pip-version-check install --upgrade pip setuptools wheel

# We copy this into the docker container prior to copying in the rest of our
# application so that we can skip installing requirements if the only thing
# that has changed is the Warehouse code itself.
COPY requirements /tmp/requirements

# Install our development dependencies if we're building a development install
# otherwise this will do nothing.
RUN set -x \
    && if [ "$DEVEL" = "yes" ]; then pip --no-cache-dir --disable-pip-version-check install -r /tmp/requirements/dev.txt; fi

# Install the Python level requirements, this is done after copying
# the requirements but prior to copying zope? itself into the container so
# that code changes don't require triggering an entire install of all of
# Warehouse's dependencies.
RUN set -x \
    && pip --no-cache-dir --disable-pip-version-check install \
        -r /tmp/requirements/main.txt \
            $(if [ "$DEVEL" = "yes" ]; then echo '-r /tmp/requirements/tests.txt'; fi) \
    && find $PLONE_ROOT -name '*.pyc' -delete


# Now we're going to build our actual application image, which will eventually
# pull in the static files that were built above.
FROM python:3.7-slim-stretch

# Setup some basic environment variables that are ~never going to change.
ENV PYTHONUNBUFFERED 1
ENV PATH="${PLONE_ROOT}/bin:${PATH}"

# Define whether we're building a production or a development image. This will
# generally be used to control whether or not we install our development and
# test dependencies.
ARG DEVEL=no

# This is a work around because otherwise postgresql-client bombs out trying
# to create symlinks to these directories.
RUN set -x \
    && mkdir -p /opt/plone/var/log \
    && mkdir -p /opt/plone/var/blobstorage \
    && mkdir -p /opt/plone/var/filestorage \
    && mkdir -p /usr/share/man/man1 \
    && mkdir -p /usr/share/man/man7

# Install System level Warehouse requirements, this is done before everything
# else because these are rarely ever going to change.
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

# Copy the directory into the container, this is done last so that changes to
# Warehouse itself require the least amount of layers being invalidated from
# the cache. This is most important in development, but it also useful for
# deploying new code changes.
COPY --from=build /opt/plone/ /opt/plone/
COPY etc /opt/plone/etc

# Need to add an inituser to the /opt/plone directory with the new user and pass
# TODO: refactor this to randomly gen a password or take from the environment
RUN echo "admin:admin" > /opt/plone/inituser

EXPOSE 8080
WORKDIR /opt/plone
ENV Z3C_AUTOINCLUDE_DEPENDENCIES_DISABLED True
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD [ "bin/runwsgi", "etc/wsgi.ini" ]