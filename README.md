# TranscodeBot
Automatically takes files in one directory and transcodes them to another.

## Building
To build TranscodeBot, clone this repository, enter the directory, and build it!

```
git clone https://github.com/lemonjesus/TranscodeBot
cd TranscodeBot
docker build . -t transcodebot
```

This should go quick since it just needs to download FFMPEG and copy some files.

## Usage
TranscodeBot requires two volumes to be mounted for it to be useful.

* `/input` - is your watch directory. This can be mounted as Read-Only. When a file is added to this directory, TranscodeBot will add it to its processing queue.
* `/output` - Where you want the movie to go. Because TranscodeBot preserves file paths (see below), you can make your output the same place you store and serve your media for a more automated pipeline.

TranscodeBot will not back-transcode, meaning its `/output` directory is basically write-only.

## Operation
TranscodeBot watches its input directory for incoming media and mirrors it into an output directory after transcode. For example:

```
/input/a/b/c.mp4 (H.264) -> /output/a/b/c.mkv (HEVC)
```

There are some rules that TranscodeBot follows to  decide how to handle a file.

* If the output file exists, mark is as done and move on.
* If the file is an srt, idx, jpg, jpeg, or png file, it will pass the file through untouched.
* If the file is an mkv, mp4, avi, mpeg, or wmv file, it will treat it as a movie. It will be passed through if it's already HEVC and transcoded if it is not.

All transcoded files result in a `.mkv` file.

## GPU Acceleration (Untested)
GPU acceleration is technically supported. Even if you don't have the hardware for it, the image builds with support for CUDA. If you are sporting a GPU with NVENC with HEVC support (the newer the better), you must do two things to enable GPU transcoding:

1. Ensure that you run the image with the NVIDIA Docker runtime.
2. Set TranscodeBot's environment variable `FORCE_GPU` to `true`

Keep in mind that this will always produce inferior results to the default `libx265` transcoding. You are literally trading time for quality. For low quality, high volume transcodes like for old television shows, this is perfectly fine. For movies, stick to software transcoding. You'll be much happier.

## Debugging
The log messages of this application are purposefully short and to the point. You see when something enters the queue and when something is considered done. If you need more information than that (for example, why something is failing), you almost certainly need to see the output of the FFMPEG process. It's messy, but you can do it by setting `FFMPEG_LOGS` to `true` in the container's environment. Keep in mind that FFMPEG's output looks really messy on readers that don't properly support carriage returns, so it may behoove you to watch the output live by either attaching to the container or by following the docker logs (`docker logs -F <container name>`).

## To Do (pull requests welcome)
* Configuration files (specifically for what files are passed through and the FFMPEG commands that are run)
* Configurable CPU Cap because it currently uses 100% of the processor and it makes my closet *very* warm.
* Add an option to delete input files when they are successfully processed (the default would be false).
* ARM version of the Dockerfile so that people that use low power embedded processors who think they're *so much better than us power hungry super users* can also play along in their log cabins.

## Credit
* The FFMPEG image comes from jrottenberg/ffmpeg.
* That image is compiled with libx264 and libx265, both of which are heavily used by this project.