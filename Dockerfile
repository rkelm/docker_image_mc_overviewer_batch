FROM debian:10

ARG DEBIAN_FRONTEND=noninteractive
ENV APP_NAME Overviewer for Minecraft for aws batch
ARG APP_VERSION
ENV MC_VERSION ${APP_VERSION}

RUN echo *** Building for Minecraft Version ${MC_VERSION} ***

# Setup local environment vars.
ENV map_data_dir /root/map_data
ENV worlds_dir ${map_data_dir}
ENV render_output /root/render_output
ENV default_config /root/overviewer_default.config
ENV tmp_dir /tmp
ENV map_id MinecraftMap
ENV overviewer_repo_name Minecraft-Overviewer
ENV local_src_dir /usr/local/src
ENV overviewer_src_dir ${local_src_dir}/${overviewer_repo_name}
ENV overviewer_git_url https://github.com/overviewer/Minecraft-Overviewer.git

# ENV DATE = $(date -Idate)
RUN apt-get -q update
RUN apt-get -qy install wget gnupg apt-transport-https 
RUN apt-get -qy install --no-install-recommends apt-utils

# Overviewer Installation via apt is broken.
#RUN echo "deb https://overviewer.org/debian ./" >> /etc/apt/sources.list
#RUN wget -nv -O - https://overviewer.org/debian/overviewer.gpg.asc | apt-key add -
#RUN apt-get -q update && apt-get -qy install minecraft-overviewer

# Install overviewer by git download and build.
RUN apt-get -qy install python3 python3-distutils python3-pip python3-pil python3-dev python3-numpy
RUN apt-get -qy install curl git
# RUN apt-get -qy install build-essential
RUN cd ${local_src_dir} && git clone ${overviewer_git_url}
RUN cd ${overviewer_src_dir} && python3 setup.py build
RUN ln -s ${overviewer_src_dir}/overviewer.py /usr/local/bin/overviewer.py

# Install minecraft textures for overviewer
RUN mkdir -p /root/.minecraft/versions/${MC_VERSION}
# RUN wget -nv https://launcher.mojang.com/v1/objects/3737db93722a9e39eeada7c27e7aca28b144ffa7/server.jar -P ~/.minecraft/versions/${MC_VERSION}/
# RUN wget -nv https://launcher.mojang.com/v1/objects/bb2b6b1aefcd70dfd1892149ac3a215f6c636b07/server.jar -P ~/.minecraft/versions/${MC_VERSION}/
# Get mc 1.16.3 server.jar.
RUN wget -nv https://launcher.mojang.com/v1/objects/f02f4473dbf152c23d7d484952121db0b36698cb/server.jar -P ~/.minecraft/versions/${MC_VERSION}/
RUN wget https://overviewer.org/textures/${MC_VERSION} -O ~/.minecraft/versions/${MC_VERSION}/${MC_VERSION}.jar


# aws cli installieren.
#RUN wget -nv https://bootstrap.pypa.io/get-pip.py
#RUN python get-pip.py --user
#RUN rm get-pip.py
#RUN /root/.local/bin/pip install awscli --upgrade --user

# install aws cli 
RUN pip3 install --upgrade pip
RUN pip3 install --upgrade awscli

# Add pip + aws binary paths to PATH
ENV PATH ${PATH}:/root/.local/bin:/root/bin

ADD rootfs/ /
COPY render_map.sh /root/bin/
COPY overviewer_default.config ${default_config}

RUN echo -e ' ************************************************** \n' \
  'Docker Image to run app ${APP_NAME} ${MC_VERSION}. \n' \
  ' \n' \
  'Usage: \n' \
  '   Run overviewer:	docker run -e map_id=<map title> -v <host-world-dir>:${worlds_dir}/world \\ \n' \
  '                             -v <host-config-&-texture-dir>:${map_data_dir}/overviewer_config \\ \n' \
  '                             -v <host-render-output-dir>:${render_output} \\ \n' \
  '                             <image_name> overviewer.py --config=${map_data_dir}/overviewer_config/<config file> \n' \
  "   Default config file: $default_config \n" \
  '  \n' \
  '   Simple run without config: \' \
  '   	  	  	docker run -v <host-world-dir>:${worlds_dir}/world \\ \n' \
  '                             -v <host-render-output-dir>:${render_output} \\ \n' \
  '                             <image_name> overviewer.py ${worlds_dir}/world ${render_output} \n' \
  '   Configure overviewer: \n' \
  '			Put configuration file(s) in volume mounted to /root/config. \n' \
  '			Output will be rendered in /root/render_output. \n' \
  '   Run as Task: \n' \
  '                     docker run --env-file environment.env /root/bin/render_map <map_id> \n' \
  '                     environment.env should set the following environment variables: \n' \
  '                        region=eu-central-1                  aws region to use \n' \
  '                        bucket=mc-maps-logs                  name of s3 bucket containing maps and logs \n' \
  '                        bucket_map_dir=maps                  path to s3 objects with maps \n' \
  '                        pub_bucket=maps.mydomain.de          name of s3 target bucket for uploading rendered picture files for viewing \n' \
  '                        pub_bucket_maps_dir=maps             path to s3 objects for uploading rendered picture files for viewing \n' \
  '                        bucket_render_cache=render-cache     name of s3 bucket for caching rendered pictures \n' \
  '                        bucket_render_cache_dir=cached       cache path to s3 objects containing \n' \
  '                        google_api_key=ADC2345DEABC          google maps api key to insert into created google maps index.html \n' \
 '**************************************************' > /image_info.txt

# Path to map files. Path to config file. Path to render output.
VOLUME ["/root/map_data/","/root/render_output"]

CMD ["/usr/bin/cat", "/image_info.txt"]
