FROM jrottenberg/ffmpeg:4.1-nvidia AS ffmpeg
FROM ruby:3.1.0

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# copy all of the libraries ffmpeg needs to run.
COPY --from=ffmpeg /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=ffmpeg /usr/local/lib/*.so* /usr/local/lib/
COPY --from=ffmpeg /usr/local/lib/*.a* /usr/local/lib/
COPY --from=ffmpeg /usr/local/cuda-11.4/ /usr/local/cuda-11.4/

ENV LD_LIBRARY_PATH /usr/local/cuda-11.4/targets/x86_64-linux/lib/

RUN ldconfig

WORKDIR /transcode-bot
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN bundle install

# copy the app
COPY . .

ENTRYPOINT ["ruby", "app/transcode_bot.rb"]
