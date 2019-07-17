FROM jrottenberg/ffmpeg:4.1-nvidia

RUN apt-get update
RUN apt-get install -y curl
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs

WORKDIR /app
COPY index.js /app/index.js
COPY ffmpeg-worker.js /app/ffmpeg-worker.js
COPY package.json /app/package.json
RUN npm install
