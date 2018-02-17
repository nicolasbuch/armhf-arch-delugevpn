FROM ledokun/armhf-arch-openvpn
MAINTAINER LedoKun

# additional files
##################

# add supervisor conf file for app
ADD build/*.conf /etc/supervisor/conf.d/

# add bash scripts to install app
ADD build/root/*.sh /root/

# add bash script to setup iptables
ADD run/root/*.sh /root/

# add bash script to run deluge
ADD run/nobody/*.sh /home/nobody/

# add python script to configure deluge
ADD run/nobody/*.py /home/nobody/

# add pre-configured config files for deluge
ADD config/nobody/ /home/nobody/

# add modified makepkg file which does not check for root user
ADD config/makepkg /usr/bin/

# install app
#############

# For cross compile on dockerhub
RUN ["docker-build-start"]

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh /home/nobody/*.sh /home/nobody/*.py && \
	/bin/bash /root/install.sh

# For cross compile on dockerhub
RUN ["docker-build-end"]

# docker settings
#################

# map /config to host defined config path (used to store configuration from app)
VOLUME /config

# map /data to host defined data path (used to store data from app)
VOLUME /data

# expose port for deluge webui
EXPOSE 8112

# expose port for privoxy
EXPOSE 8118

# expose port for deluge daemon (used in conjunction with LAN_NETWORK env var)
EXPOSE 58846

# expose port for deluge incoming port (used only if VPN_ENABLED=no)
EXPOSE 58946
EXPOSE 58946/udp

# install jdk8 and filebot
#################
RUN mkdir -p /tmp/package/ && chown nobody /tmp/package

RUN cd /tmp/package && \
    curl https://aur.archlinux.org/cgit/aur.git/snapshot/jdk-arm.tar.gz -o jdk8.tar.gz && \
    tar -xvzf jdk8.tar.gz && \
    cd jdk-arm && \
    makepkg -s --noconfirm --clean

RUN pacman -U --noconfirm /tmp/package/jdk-arm/*.tar.xz

RUN cd /tmp/package && \
    curl https://aur.archlinux.org/cgit/aur.git/snapshot/filebot.tar.gz -o filebot.tar.gz && \
    tar -xvzf filebot.tar.gz && \
    cd filebot && \
    makepkg -s --noconfirm --clean

RUN pacman -U --noconfirm /tmp/package/filebot/filebot-*-armv7h.pkg.tar.xz

# set permissions
#################

# run script to set uid, gid and permissions
CMD ["/bin/bash", "/root/init.sh"]