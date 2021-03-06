FROM registry.centos.org/centos/centos:7

ENV LANG=en_US.UTF-8 \
    BLACKDUCK_PATH='/opt/blackduck/' \
    JAVANCSS_PATH='/opt/javancss/' \
    OWASP_DEP_CHECK_PATH='/opt/dependency-check/' \
    SCANCODE_PATH='/opt/scancode-toolkit/'

# Cache friendly dependency specifications:
#   - deps are listed in text files or scripts inside the lib/ dir
#   - individual files are copied in during image build
#   - changes in minimum and/or pinned versions will invalidate the cache
RUN mkdir -p /tmp/install_deps

# https://copr.fedorainfracloud.org/coprs/jpopelka/mercator/
# https://copr.fedorainfracloud.org/coprs/jpopelka/python-brewutils/
COPY hack/_copr_jpopelka-mercator.repo hack/_copr_jpopelka-python-brewutils.repo /etc/yum.repos.d/

# Install RPM dependencies
COPY hack/install_deps_rpm.sh /tmp/install_deps/
RUN yum install -y epel-release && \
    /tmp/install_deps/install_deps_rpm.sh && \
    yum clean all

# Work-arounds & hacks:
# 'pip install --upgrade wheel': http://stackoverflow.com/questions/14296531
RUN pip3 install --upgrade pip && pip install --upgrade wheel && \
    pip3 install alembic psycopg2 git+git://github.com/msrb/kombu@sqs-conn#egg=kombu

# Install javascript deps
COPY hack/install_deps_npm.sh /tmp/install_deps/
RUN /tmp/install_deps/install_deps_npm.sh

# Install binwalk, the pip package is broken, following docs from github.com/devttys0/binwalk
#RUN mkdir /tmp/binwalk/ && \
#    curl -L https://github.com/devttys0/binwalk/archive/v2.1.1.tar.gz | tar xz -C /tmp/binwalk/ --strip-components 1 && \
#    python /tmp/binwalk/setup.py install && \
#    rm -rf /tmp/binwalk/

# Languages scanner
# RUN gem install --no-document github-linguist

# Install BlackDuck CLI
#COPY hack/install_bd.sh /tmp/install_deps/
#RUN /tmp/install_deps/install_bd.sh
# Import BlackDuck Hub CA cert
#COPY hack/import_BD_CA_cert.sh /tmp/install_deps/
#RUN /tmp/install_deps/import_BD_CA_cert.sh

# Install JavaNCSS for code metrics
#COPY hack/install_javancss.sh /tmp/install_deps/
#RUN /tmp/install_deps/install_javancss.sh

# Install OWASP dependency-check cli for security scan of jar files
COPY hack/install_owasp_dependency-check.sh /tmp/install_deps/
RUN /tmp/install_deps/install_owasp_dependency-check.sh

# Install ScanCode-toolkit for license scan
COPY hack/install_scancode.sh /tmp/install_deps/
RUN /tmp/install_deps/install_scancode.sh

# Install dependencies required in both Python 2 and 3 versions
COPY ./hack/py23requirements.txt /tmp/install_deps/
RUN pip2 install -r /tmp/install_deps/py23requirements.txt
RUN pip3 install -r /tmp/install_deps/py23requirements.txt

# Import RH CA cert
COPY hack/import_RH_CA_cert.sh /tmp/install_deps/
RUN /tmp/install_deps/import_RH_CA_cert.sh

# A temporary hack to keep tagger up2date
COPY hack/install_tagger.sh /tmp/
RUN sh /tmp/install_tagger.sh

# Not-yet-upstream-released patches
RUN mkdir -p /tmp/install_deps/patches/
COPY hack/patches/* /tmp/install_deps/patches/
# Apply patches here to be able to patch selinon as well
RUN /tmp/install_deps/patches/apply_patches.sh
