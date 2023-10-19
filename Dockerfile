FROM registry.access.redhat.com/ubi8/ubi

ENV PYTHONUNBUFFERED=0
ENV DJANGO_SETTINGS_MODULE=pulpcore.app.settings
ENV PULP_SETTINGS=/etc/pulp/settings.py
ENV _BUILDAH_STARTED_IN_USERNS=""
ENV BUILDAH_ISOLATION=chroot
ENV PULP_GUNICORN_TIMEOUT=${PULP_GUNICORN_TIMEOUT:-90}
ENV PULP_API_WORKERS=${PULP_API_WORKERS:-2}
ENV PULP_CONTENT_WORKERS=${PULP_CONTENT_WORKERS:-2}

ENV PULP_GUNICORN_RELOAD=${PULP_GUNICORN_RELOAD:-false}
ENV PULP_OTEL_ENABLED=${PULP_OTEL_ENABLED:-false}
ENV PULP_WORKERS=2
ENV PULP_HTTPS=false
ENV PULP_STATIC_ROOT=/var/lib/operator/static/

# Install updates & dnf plugins before disabling python36 to prevent errors
COPY images/repos.d/*.repo /etc/yum.repos.d/
RUN dnf -y install dnf-plugins-core && \
    dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    # dnf config-manager --set-enabled powertools && \
    dnf -y update

# use python38
RUN dnf -y module disable python36
RUN dnf -y module enable python38

# glibc-langpack-en is needed to provide the en_US.UTF-8 locale, which Pulp
# seems to need.
#
# The last 5 lines (before clean) are needed until python3-createrepo_c gets an
# RPM upgrade to 0.16.2. Until then, we install & build it from PyPI.
#
# TODO: Investigate differences between `dnf builddep createrepo_c` vs the list
# of dependencies below. For example, drpm-devel.
RUN dnf -y install python38 python38-cryptography python38-devel && \
    dnf -y install openssl openssl-devel && \
    dnf -y install openldap-devel && \
    dnf -y install wget git && \
    dnf -y install python3-psycopg2 && \
    dnf -y install redhat-rpm-config gcc cargo libffi-devel && \
    dnf -y install python3-setuptools && \
    dnf -y install ostree-libs ostree --allowerasing --nobest && \
    dnf -y install cairo-devel cmake gobject-introspection-devel cairo-gobject-devel
RUN dnf clean all

# Needed to prevent the wrong version of cryptography from being installed,
# which would break PyOpenSSL.
# Need to install optional dep, rhsm, for pulp-certguard
RUN pip3 install --upgrade pip setuptools wheel && \
    rm -rf /root/.cache/pip && \
    pip3 install  \
         rhsm \
         setproctitle \
         gunicorn \
         python-nginx \
         django-storages\[boto3,azure]\>=1.12.2 \
         requests\[use_chardet_on_py3] && \
         rm -rf /root/.cache/pip


RUN pip3 install --upgrade \
  pulpcore \
  pulp-certguard \
  pulp-ostree && \
  rm -rf /root/.cache/pip

RUN groupadd -g 700 --system pulp
RUN useradd -d /var/lib/pulp --system -u 700 -g pulp pulp
RUN usermod --add-subuids 100000-165535 --add-subgids 100000-165535 pulp

RUN mkdir -p /etc/pulp/certs \
             /etc/ssl/pulp \
             /var/lib/operator/static \
             /var/lib/pgsql \
             /var/lib/pulp/assets \
             /var/lib/pulp/media \
             /var/lib/pulp/scripts \
             /var/lib/pulp/tmp

RUN chown pulp:pulp -R /var/lib/pulp \
                       /var/lib/operator/static

COPY images/assets/readyz.py /usr/bin/readyz.py
COPY images/assets/route_paths.py /usr/bin/route_paths.py
COPY images/assets/wait_on_postgres.py /usr/bin/wait_on_postgres.py
COPY images/assets/wait_on_database_migrations.sh /usr/bin/wait_on_database_migrations.sh
COPY images/assets/set_init_password.sh /usr/bin/set_init_password.sh
COPY images/assets/add_signing_service.sh /usr/bin/add_signing_service.sh
COPY images/assets/pulp-api /usr/bin/pulp-api
COPY images/assets/pulp-content /usr/bin/pulp-content
COPY images/assets/pulp-resource-manager /usr/bin/pulp-resource-manager
COPY images/assets/pulp-worker /usr/bin/pulp-worker

USER pulp:pulp
RUN PULP_STATIC_ROOT=/var/lib/operator/static/ PULP_CONTENT_ORIGIN=localhost \
       /usr/local/bin/pulpcore-manager collectstatic --clear --noinput --link
USER root:root

RUN chmod 2775 /var/lib/pulp/{scripts,media,tmp,assets}
RUN chown :root /var/lib/pulp/{scripts,media,tmp,assets}

EXPOSE 80
