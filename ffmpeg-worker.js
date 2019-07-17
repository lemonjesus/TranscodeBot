const { spawnSync, spawn } = require('child_process');
const { workerData, parentPort } = require('worker_threads');
const fs = require('fs');

const transcodeTypes = ['mkv', 'mp4', 'avi', 'mpeg', 'wmv'];
const passthroughTypes = ['srt', 'idx', 'jpg', 'jpeg', 'png'];

const inputFile = workerData;
console.log(`starting work on ${inputFile}`);
let outputFile = inputFile.split('/');
let isTranscode = false;
outputFile[1] = 'output';
outputFile[outputFile.length-1] = outputFile[outputFile.length-1].split('.');

//is this a transcode type or a passthrough type?
if(transcodeTypes.indexOf(outputFile[outputFile.length-1][outputFile[outputFile.length-1].length -1])!=-1) {
  isTranscode = true;
  outputFile[outputFile.length-1][outputFile[outputFile.length-1].length -1] = 'mkv';
} else if(passthroughTypes.indexOf(outputFile[outputFile.length-1][outputFile[outputFile.length-1].length -1])!=-1) {
  parentPort.postMessage(`file ${inputFile} ignored, not white listed`);
  return;
}

//calculate the output path
outputFile[outputFile.length-1] = outputFile[outputFile.length-1].join('.');
const dir = outputFile.slice(0, -1).join('/');
fs.mkdirSync(dir, { recursive: true });
outputFile = outputFile.join('/');

//does the output path exist?
if(fs.existsSync(outputFile)) {
  parentPort.postMessage(`file ${outputFile} already exists, skipping ${inputFile}`);
  return;
}

//is the file already HEVC?
if(isHEVC(inputFile)) isTranscode = false;

if(isTranscode) {
  //should we do this the gpu way or not?
  let transcodeProcess;
  if(process.env.FORCE_GPU)
    transcodeProcess = spawn('ffmpeg', ['-i', inputFile, '-c:v', 'hevc_nvenc', '-preset', 'slow', '-rc-lookahead:v', '32', '-temporal-aq:v', '1', '-weighted_pred:v', '1', '-rc', 'vbr_hq', '-2pass', 'true', '-c:a', 'copy', '-c:s', 'copy', outputFile]);
  else
    transcodeProcess = spawn('ffmpeg', ['-i', inputFile, '-c:v', 'libx265', '-preset', 'fast', '-x265-params', 'crf=22:qcomp=0.8:aq-mode=1:aq_strength=1.0:qg-size=16:psy-rd=0.7:psy-rdoq=5.0:rdoq-level=1:merange=44', '-c:a', 'copy', '-c:s', 'copy', outputFile]);

  if(process.env.FFMPEG_LOGS) {
    transcodeProcess.stderr.pipe(process.stderr);
    transcodeProcess.stdout.pipe(process.stdout);
  }
  transcodeProcess.on('exit', (code, signal) => {
    if(code==0) {
      parentPort.postMessage(`file ${inputFile} transcoded to ${outputFile}`);
      fs.chownSync(outputFile, process.env.UID, process.env.GID);
      fs.chmodSync(outputFile, process.env.FMODE);
    }
    else {
      if(fs.existsSync(outputFile)) fs.unlinkSync(outputFile);
      parentPort.postMessage(`file ${inputFile} failed with exit code ${code}, signal ${signal}`);
    }
  });
} else {
  fs.copyFileSync(inputFile, outputFile);
  fs.chownSync(outputFile, process.env.UID, process.env.GID);
  fs.chmodSync(outputFile, process.env.FMODE);
  parentPort.postMessage(`file ${inputFile} copied to ${outputFile}`);
}

function isHEVC(file) {
  const output = spawnSync('ffprobe', ['-i', file]);
  if(output.status != 0) return false; //let the transcoder handle the sad path
  if(output.stdout.indexOf('HEVC') == -1 && output.stderr.indexOf('HEVC') == -1) return false;
  return true;
}
