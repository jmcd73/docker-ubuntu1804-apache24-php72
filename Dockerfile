FROM ubuntu:18.04
LABEL maintainer="James McDonald <james@toggen.com.au>"
LABEL description="Ubuntu 18.04+, Apache 2.4+, PHP 7.3+"

# docker build -t toggen/tgn-img:20190614.2

# Environments vars
ENV TERM=xterm

# set a default root password
RUN echo "root:HeartMindSoul" | chpasswd

RUN apt-get clean all
RUN apt-get update
RUN apt-get update && apt-get -y dist-upgrade
RUN apt-get -y install software-properties-common
RUN add-apt-repository ppa:ondrej/php
RUN sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
RUN apt-get update

# Packages installation
RUN DEBIAN_FRONTEND=noninteractive apt-get -y --fix-missing install apache2 \
    supervisor \
    php7.4 \
    php7.4-cli \
    php7.4-gd \
    php7.4-json \
    php7.4-mbstring \
    php7.4-opcache \
    php7.4-xml \
    php7.4-mysql \
    php7.4-curl \
    libapache2-mod-php7.4 \
    curl \
    apt-transport-https \
    vim \
    cpanminus \
    cups \
    cups-bsd \
    cups-client \
    printer-driver-cups-pdf \
    libfcgi-perl \
    mysql-client \
    nmap \
    iproute2 \
    hplip \
    locales \
    git \
    unzip \
    php-xdebug \
    xz-utils \
    cmake

RUN apt-get -y build-dep glabels

RUN apt-get clean all
RUN a2enmod rewrite
RUN a2enmod cgi
RUN a2enmod headers
RUN mkdir /build && cd /build && \
    wget https://downloads.sourceforge.net/project/zint/zint/2.6.3/zint-2.6.3_final.tar.gz && tar -xvf zint-2.6.3_final.tar.gz && \
    cd zint-2.6.3.src/ && mkdir build && cd build && cmake .. && make && make install


RUN cd /build && wget http://ftp.gnome.org/pub/GNOME/sources/glabels/3.4/glabels-3.4.1.tar.xz && tar xvf glabels-3.4.1.tar.xz && \
    cd glabels-3.4.1/ && ./configure && make && make install && ldconfig

RUN rm -rf /build

# RUN phpenmod mcrypt

# Composer install
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# supervisord
RUN mkdir -p /var/log/supervisor

COPY config/supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# Update the default apache site with the config we created.
COPY config/apache/apache-virtual-hosts.conf /etc/apache2/sites-enabled/000-default.conf
COPY config/apache/apache2.conf /etc/apache2/apache2.conf
COPY config/apache/ports.conf /etc/apache2/ports.conf
COPY config/apache/envvars /etc/apache2/envvars

# locale
RUN touch /usr/share/locale/locale.alias
RUN sed -i -e 's/# \(en_AU\.UTF-8 .*\)/\1/' /etc/locale.gen && \
    locale-gen
ENV LANG en_AU.UTF-8
ENV LANGUAGE en_AU:en
ENV LC_ALL en_AU.UTF-8

# Update php.ini
COPY config/php/php.conf /etc/php/7.0/apache2/php.ini

# COPY phpinfo script for INFO purposes
RUN echo "<?php phpinfo();" >> /var/www/index.php

RUN sed -ibak -e s+/usr/lib/cgi-bin+/var/www/cgi-bin+g /etc/apache2/conf-enabled/serve-cgi-bin.conf

RUN service apache2 restart

RUN chown -R www-data:www-data /var/www

#RUN sed -i.bak '1i ServerAlias *' /etc/cups/cupsd.conf

COPY config/cups/cupsd.conf /etc/cups/
COPY config/cups/printers.conf /etc/cups/
COPY config/cups/PDF.ppd /etc/cups/ppd/

RUN sed -i.bak -e 's+Out.*+Out /var/www/PDF+g' /etc/cups/cups-pdf.conf


#RUN /usr/sbin/cupsd -f && cupsctl --remote-admin --remote-any --share-printers

WORKDIR /var/www/

# Volume
VOLUME /var/www

# Ports: apache2
EXPOSE 80
EXPOSE 631

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
