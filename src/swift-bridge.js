const { execFile } = require('child_process');
const { SWIFT_BINARY, SWIFT_EXEC_TIMEOUT_MS } = require('./config');
const log = require('./logger');

function getBluetoothDevices() {
  return new Promise((resolve) => {
    execFile(SWIFT_BINARY, { timeout: SWIFT_EXEC_TIMEOUT_MS }, (err, stdout) => {
      if (err) {
        log.error('Swift bridge failed:', err.message);
        resolve([]);
        return;
      }
      try {
        const devices = JSON.parse(stdout);
        resolve(devices);
      } catch (parseErr) {
        log.error('Failed to parse Swift output:', parseErr.message);
        resolve([]);
      }
    });
  });
}

module.exports = { getBluetoothDevices };
