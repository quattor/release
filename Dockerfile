# Use an official centos image as a parent image
FROM centos:7

# Set the working directory to install dependencies to /quattor
WORKDIR /quattor

# install library core in /quattor, tests need it
ADD https://codeload.github.com/quattor/template-library-core/tar.gz/master /quattor/template-library-core-master.tar.gz
RUN tar xvfz template-library-core-master.tar.gz

# Copy the current directory contents into the container at /ncm-metaconfig
#TODO: use docker volumes here to mount the current directory contents, no no need to rebuild every time to test
ADD . /ncm-metaconfig/

# Install dependencies
RUN yum groupinstall 'Development Tools' -y
RUN yum-config-manager --add-repo http://yum.quattor.org/current
RUN yum-config-manager --add-repo http://yum.quattor.org/externals/noarch/el7/
RUN yum install maven wget epel-release -y

RUN wget http://yum.quattor.org/devel/quattor-release-1-1.noarch.rpm
RUN yum localinstall --nogpgcheck quattor-release-1-1.noarch.rpm -y
RUN yum install --nogpgcheck panc ncm-ncd perl-Test-Quattor -y
# needed by some tests, not a dependency from perl-Test-Quattor
RUN yum install perl-JSON-Any -y

# these are not by default in centos7, but quattor tests assume they are
RUN touch /usr/sbin/selinuxenabled /sbin/restorecon
RUN chmod +x /usr/sbin/selinuxenabled /sbin/restorecon

# Define environment variable
ENV QUATTOR_TEST_SUITE_FILTER simple
# point library core to where we downloaded it
ENV QUATTOR_TEST_TEMPLATE_LIBRARY_CORE /quattor/template-library-core-master

# set workdir to where we'll run the tests
WORKDIR /ncm-metaconfig

# when running the container, by default run the tests 
# you can run any command in the container from the cli.
CMD . /usr/bin/mvn_test.sh && mvn_test
