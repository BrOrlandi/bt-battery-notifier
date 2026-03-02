const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');

module.exports = {
  SWIFT_BINARY: path.join(PROJECT_ROOT, 'swift', 'bt_battery'),
  POLL_INTERVAL_MS: 15_000,
  LOW_BATTERY_THRESHOLD: 50,
  SWIFT_EXEC_TIMEOUT_MS: 5_000,
};
