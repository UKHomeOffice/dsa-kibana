FROM kibana:7.17.8

# add our custom script(s)
COPY --chown=kibana:root [ "scripts/start_kibana.sh", "/usr/local/bin/" ]

RUN chmod 755 /usr/local/bin/start_kibana.sh

# update underlying OS
USER root
RUN apt-get update -y && apt-get upgrade -y && apt-get autoclean

# run as the kibana user (1000:1000)
USER 1000

CMD [ "/usr/local/bin/start_kibana.sh" ]
