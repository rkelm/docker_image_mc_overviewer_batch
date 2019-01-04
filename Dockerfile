FROM ubuntu:18.10

ARG DEBIAN_FRONTEND=noninteractive
ENV APP_NAME Overviewer for Minecraft for aws batch
ARG APP_VERSION
ENV MC_VERSION ${APP_VERSION}

RUN echo *** Building for Minecraft Version ${MC_VERSION} ***

# Setup local environment vars.
ENV map_data_dir /root/map_data
ENV worlds_dir ${map_data_dir}/worlds
ENV render_output /root/render_output
ENV tmp_dir /tmp
ENV map_id MinecraftMap

# ENV DATE = $(date -Idate)
RUN apt-get -q update && apt-get -qy install wget gnupg apt-transport-https
RUN apt-get -qy install --no-install-recommends apt-utils
RUN echo "deb https://overviewer.org/debian ./" >> /etc/apt/sources.list
RUN wget -nv -O - https://overviewer.org/debian/overviewer.gpg.asc | apt-key add -
RUN apt-get -q update && apt-get -qy install minecraft-overviewer
RUN wget -nv https://launcher.mojang.com/v1/objects/3737db93722a9e39eeada7c27e7aca28b144ffa7/server.jar -P ~/.minecraft/versions/${
MC_VERSION}/

# aws cli installieren.
RUN wget -nv https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py --user
RUN rm get-pip.py
RUN /root/.local/bin/pip install awscli --upgrade --user

# Add pip + aws binary paths to PATH
ENV PATH ${PATH}:/root/.local/bin:/root/bin

ADD rootfs/ /
COPY render_map.sh /root/bin/

RUN echo -e ' ************************************************** \n' \
  'Docker Image to run app ${APP_NAME} ${MC_VERSION}. \n' \
  ' \n' \
  'Usage: \n' \
  '   Run overviewer:	docker run -e map_id=<map title> -v <host-world-dir>:${worlds_dir}/world \\ \n' \
  '                             -v <host-config-&-texture-dir>:${map_data_dir}/overviewer_config \\ \n' \
  '                             -v <host-render-output-dir>:${render_output} \\ \n' \
  '                             <image_name> overviewer.py --config=${map_data_dir}/overviewer_config/<config file> \n' \
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
VOLUME ["/root/map_data/worlds/world","/root/map_data/worlds/world_nether","/root/map_data/worlds/world_the_end","/root/map_data/overviewer_config","/root/render_output"]

CMD ["/bin/cat", "/image_info.txt"]
