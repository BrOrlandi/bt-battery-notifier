const monitor = require('./monitor');

monitor.start();

process.on('SIGTERM', () => {
  monitor.stop();
  process.exit(0);
});

process.on('SIGINT', () => {
  monitor.stop();
  process.exit(0);
});
