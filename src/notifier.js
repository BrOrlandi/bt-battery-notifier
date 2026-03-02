const { execFile } = require('child_process');
const log = require('./logger');

function escapeAppleScript(str) {
  return str.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function notify(title, body, subtitle) {
  const safeTitle = escapeAppleScript(title);
  const safeBody = escapeAppleScript(body);

  let script = `display notification "${safeBody}" with title "${safeTitle}"`;
  if (subtitle) {
    const safeSub = escapeAppleScript(subtitle);
    script += ` subtitle "${safeSub}"`;
  }

  return new Promise((resolve) => {
    execFile('osascript', ['-e', script], (err) => {
      if (err) {
        log.error('Notification failed:', err.message);
      }
      resolve();
    });
  });
}

module.exports = { notify };
