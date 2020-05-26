FROM jrottenberg/ffmpeg:4.1-nvidia

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt-get update

RUN apt-get install -y openssl
#RUN \curl -L https://get.rvm.io | bash -s stable

RUN \
  apt-get update && apt-get install -y --no-install-recommends --no-install-suggests curl bzip2 build-essential libssl-dev libreadline-dev zlib1g-dev && \
  rm -rf /var/lib/apt/lists/* && \
  curl -L https://github.com/rbenv/ruby-build/archive/v20200224.tar.gz | tar -zxvf - -C /tmp/ && \
  cd /tmp/ruby-build-* && ./install.sh && cd / && \
  ruby-build -v 2.6.5 /usr/local && rm -rfv /tmp/ruby-build-*

RUN gem install rb-inotify

WORKDIR /app
COPY TranscodeBot.rb /app/TranscodeBot.rb

ENTRYPOINT ["ruby", "TranscodeBot.rb"]
