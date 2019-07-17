const chokidar = require('chokidar');
const { Worker } = require('worker_threads');

const queue = [];
let currentTask = {isFulfilled: () => true};

function startMoreWorkIfReady() {
  if(currentTask.isFulfilled() && queue.length) {
    currentTask = launchWorker(queue.shift());
  }
}

function makeQueryablePromise(promise) {
  // Don't modify any promise that has been already modified.
  if (promise.isResolved) return promise;

  // Set initial state
  var isPending = true;
  var isRejected = false;
  var isFulfilled = false;

  // Observe the promise, saving the fulfillment in a closure scope.
  var result = promise.then(
      function(v) {
          isFulfilled = true;
          isPending = false;
          return v; 
      }, 
      function(e) {
          isRejected = true;
          isPending = false;
          throw e; 
      }
  );

  result.isFulfilled = function() { return isFulfilled; };
  result.isPending = function() { return isPending; };
  result.isRejected = function() { return isRejected; };
  return result;
}

function enqueueJob(path) {
  queue.push(path);
  console.log("enqueued", path, "making the queue", queue.length, "long.");
}

//This method launches the worker if there isn't already a worker.
function launchWorker(path) {
  console.log(path);
  return makeQueryablePromise(new Promise((resolve, reject) => {
    const worker = new Worker('./ffmpeg-worker.js', { workerData: path });
    worker.on('message', x => {
      console.log(`${x}\n`);
      resolve(x);
    });
    worker.on('error', reject);
    worker.on('exit', (code) => {
      if (code !== 0)
        reject(new Error(`Worker stopped with exit code ${code}`));
    });
  }));
}

//At the top level, all we have to do is instantiate a watcher on /input
chokidar.watch('/input', {
  ignored: /(^|[\/\\])\../,
  awaitWriteFinish: true
}).on('add', (path) => {
  enqueueJob(path);
});

setInterval(startMoreWorkIfReady, 1000);