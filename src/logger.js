function timestamp() {
  return new Date().toISOString();
}

module.exports = {
  info(...args) {
    console.log(`[${timestamp()}] [INFO]`, ...args);
  },
  error(...args) {
    console.error(`[${timestamp()}] [ERROR]`, ...args);
  },
};
