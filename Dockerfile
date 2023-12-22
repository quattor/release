# Use an official RockyLinux image as a parent image
FROM rockylinux:8

# Set the working directory to install dependencies to /quattor
WORKDIR /quattor

# install library core in /quattor, tests need it
ADD https://codeload.github.com/quattor/template-library-core/tar.gz/master template-library-core-master.tar.gz
RUN tar -xzf template-library-core-master.tar.gz

# point library core to where we downloaded it
ENV QUATTOR_TEST_TEMPLATE_LIBRARY_CORE /quattor/template-library-core-master

# Prepare to install dependencies
RUN dnf -y install dnf-plugins-core && \
  dnf config-manager --set-enabled appstream && \
  dnf config-manager --set-enabled powertools && \
  dnf -y install epel-release http://yum.quattor.org/devel/quattor-yum-repo-2-1.noarch.rpm

# The available version of perl-Test-Quattor is too old for mvnprove.pl to
# work, but this is a quick way of pulling in a lot of required dependencies.
# Surprisingly `which` is not installed by default and panc depends on it.
# libselinux-utils is required for /usr/sbin/selinuxenabled
RUN dnf install -y maven which rpm-build panc ncm-lib-blockdevices \
  ncm-ncd git libselinux-utils sudo perl-Crypt-OpenSSL-X509 \
  perl-Data-Compare perl-Date-Manip perl-File-Touch perl-JSON-Any \
  perl-Net-DNS perl-Net-FreeIPA perl-Net-OpenNebula \
  perl-Net-OpenStack-Client perl-NetAddr-IP perl-REST-Client \
  perl-Set-Scalar perl-Text-Glob cpanminus gcc wget \
  perl-Git-Repository perl-Data-Structure-Util \
  perl-Test-Quattor aii-ks

# quattor tests should not be run as root
RUN useradd --user-group --create-home --no-log-init --home-dir /quattor_test quattortest
USER quattortest
WORKDIR /quattor_test

# Default action on running the container is to run all tests
CMD . /usr/bin/mvn_test.sh && mvn_test
