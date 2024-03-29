# TranscodeBot
Automatically takes files in one directory and transcodes them to another.

## Building
To build TranscodeBot, clone this repository, enter the directory, and build it!

```
git clone https://github.com/lemonjesus/TranscodeBot
cd TranscodeBot
docker build . -t transcodebot
```

This should go quick since it just needs to download FFMPEG, Ruby, and copy some files.

## Usage
TranscodeBot requires two volumes to be mounted for it to be useful.

* `/input` - is your watch directory. This can be mounted as Read-Only. When a file is added to this directory, TranscodeBot will add it to its processing queue. 
* `/output` - Where you want the movie to go. Because TranscodeBot preserves file paths (see below), you can make your output the same place you store and serve your media for a more automated pipeline.
* `/app/config.yml` - **(optional)** Map this volume to your config file, if you have one. See the example file in the repo.

TranscodeBot will not back-transcode, meaning its `/output` directory is basically write-only.

## Configuration
All configuration options are documented in the example `config.yml.example` file with their defaults. In Docker, this file should be mapped as a volume to `/app/config.yml`. If you do not supply one, the defaults are used.

## Operation
TranscodeBot watches its input directory for incoming media and mirrors it into an output directory after transcode. For example:

```
/input/a/b/c.mp4 (H.264) -> /output/a/b/c.mkv (HEVC)
```

There are some rules that TranscodeBot follows to decide how to handle a file.

* If the output file exists, mark is as done and move on.
* If the file is an srt, idx, jpg, jpeg, or png file, it will pass the file through untouched.
* If the file is an mkv, mp4, avi, mpeg, or wmv file, it will treat it as a movie. It will be passed through if it's already HEVC and transcoded if it is not.

All transcoded files result in a `.mkv` file.

## Overriding the FFMPEG command
You can specify your own command to run if you want different options from the default settings. Simply set `force_cmd` to the command you wish to run. **This is the full command, not just the arguments `ffmpeg` is receiving. `ffmpeg` is no longer assumed.** You can use the following internal variables:

* `$input` - translates to the input file transcodebot is focused on
* `$output` - the calculated output path of where the current file is going

## GPU Acceleration
GPU acceleration is supported. Even if you don't have the hardware for it, the image builds with support for CUDA. If you are sporting a GPU with NVENC with HEVC support (the newer the better), you must do two things to enable GPU transcoding:

1. Ensure that you run the image with the NVIDIA Docker runtime.
2. Set TranscodeBot's config variable `force_cmd` to be an FFMPEG command that uses hardware acceleration. Here's an example of the one I use for 480p cartoons:

```
ffmpeg -i $input -c:v hevc_nvenc -preset slow -rc-lookahead 32 -temporal-aq 1 -rc vbr_hq -2pass true -b:v 550k -c:a copy -c:s copy $output
```

Keep in mind that this will always produce inferior results to the default `libx265` transcoding. You are literally trading time for quality. For low quality, high volume transcodes like for old television shows, this is perfectly fine. For movies, stick to software transcoding. You'll be much happier.

## Debugging
The log messages of this application are purposefully short and to the point. You see when something enters the queue and when something is considered done. If you need more information than that (for example, why something is failing), you almost certainly need to see the output of the FFMPEG process. It's messy, but you can do it by setting `ffmpeg_logs` to `true` in the config file. Keep in mind that FFMPEG's output looks really messy on readers that don't properly support carriage returns, so it may behoove you to watch the output live by either attaching to the container or by following the docker logs (`docker logs -F <container name>`).

Pull requests are always welcome.

## Credit
* The FFMPEG image comes from jrottenberg/ffmpeg.
* That image is compiled with libx264 and libx265, both of which are heavily used by this project.
* Uses MRI Ruby 3.0.1
