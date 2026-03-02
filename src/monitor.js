const { getBluetoothDevices } = require('./swift-bridge');
const { notify } = require('./notifier');
const { POLL_INTERVAL_MS, LOW_BATTERY_THRESHOLD } = require('./config');
const log = require('./logger');

// deviceAddress -> { name, connected, battery, batteryLeft, batteryRight, batteryCase, isMultiBattery }
const state = new Map();
let firstPoll = true;

function formatBattery(device) {
  if (device.isMultiBattery) {
    const parts = [];
    if (device.batteryLeft > 0) parts.push(`E: ${device.batteryLeft}%`);
    if (device.batteryRight > 0) parts.push(`D: ${device.batteryRight}%`);
    if (device.batteryCase > 0) parts.push(`Estojo: ${device.batteryCase}%`);
    if (parts.length > 0) return parts.join(' | ');
  }
  if (device.battery > 0) return `Bateria: ${device.battery}%`;
  return null;
}

function getMainBattery(device) {
  if (device.isMultiBattery) {
    const values = [device.batteryLeft, device.batteryRight, device.batteryCase].filter(v => v > 0);
    return values.length > 0 ? Math.min(...values) : 0;
  }
  return device.battery;
}

async function poll() {
  const devices = await getBluetoothDevices();

  // Deduplicate by address (keep last entry, which may have fresher data)
  const byAddress = new Map();
  for (const d of devices) {
    byAddress.set(d.address, d);
  }

  for (const [address, raw] of byAddress) {
    const prev = state.get(address);

    const current = {
      name: raw.name,
      connected: raw.connected,
      battery: raw.batteryPercentSingle,
      batteryLeft: raw.batteryPercentLeft,
      batteryRight: raw.batteryPercentRight,
      batteryCase: raw.batteryPercentCase,
      isMultiBattery: raw.isMultiBatteryDevice,
    };

    // Cache battery: only update if new value > 0 (battery reads 0 when disconnected)
    if (prev && current.connected) {
      if (current.battery === 0) current.battery = prev.battery;
      if (current.batteryLeft === 0) current.batteryLeft = prev.batteryLeft;
      if (current.batteryRight === 0) current.batteryRight = prev.batteryRight;
      if (current.batteryCase === 0) current.batteryCase = prev.batteryCase;
    }

    // Detect disconnection: was connected, now disconnected
    if (prev && prev.connected && !current.connected && !firstPoll) {
      const batteryText = formatBattery(prev);
      const mainBattery = getMainBattery(prev);

      const title = `${prev.name} desconectado`;
      const body = batteryText || 'Bateria: desconhecida';
      const subtitle = mainBattery > 0 && mainBattery < LOW_BATTERY_THRESHOLD
        ? 'Bateria baixa - coloque para carregar!'
        : undefined;

      log.info(`Disconnected: ${prev.name} (${address}) - ${body}`);
      await notify(title, body, subtitle);
    }

    // Log connections
    if ((!prev || !prev.connected) && current.connected && !firstPoll) {
      log.info(`Connected: ${current.name} (${address}) - Battery: ${current.battery}%`);
    }

    state.set(address, current);
  }

  if (firstPoll) {
    const connected = [...state.values()].filter(d => d.connected);
    log.info(`Initial poll: ${state.size} devices found, ${connected.length} connected`);
    for (const d of connected) {
      log.info(`  - ${d.name}: ${d.battery}%`);
    }
    firstPoll = false;
  }
}

let intervalId;

function start() {
  log.info('Monitor started');
  poll();
  intervalId = setInterval(poll, POLL_INTERVAL_MS);
}

function stop() {
  if (intervalId) {
    clearInterval(intervalId);
    intervalId = null;
  }
  log.info('Monitor stopped');
}

module.exports = { start, stop };
