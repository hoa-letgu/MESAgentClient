const { windowManager } = require('node-window-manager');
const psList = require('ps-list').default;
const os = require('os');
const axios = require('axios');
const { io } = require('socket.io-client');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const API_ENDPOINT = 'http://10.30.3.50:6677/api/mes-agent-report';
const SOCKET_ENDPOINT = 'http://10.30.3.50:6677'; // Socket server URL
let lastSentPayload = null;
let mesUsercode = null;
const cachedInfo = {
  user: os.userInfo().username,
  ip: null,
  lastIpCheck: 0,
};
let isMESRunningLastCheck = null;
function getIPAddress() {
  const now = Date.now();
  if (cachedInfo.ip && now - cachedInfo.lastIpCheck < 3600000) {
    return cachedInfo.ip;
  }
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        cachedInfo.ip = net.address;
        cachedInfo.lastIpCheck = now;
        return net.address;
      }
    }
  }
  return 'Unknown';
}

function getCurrentUsername() {
  return cachedInfo.user;
}
function getMESClientPathViaWMIC(callback) {
  exec('wmic process where "name=\'SJeMESClient.exe\'" get ExecutablePath /format:list', (error, stdout, stderr) => {
    if (error) {
      console.error('Lỗi khi chạy wmic:', error);
      return;
    }

    const lines = stdout.trim().split(/\r?\n/);
    for (let line of lines) {
      if (line.startsWith('ExecutablePath=')) {
        const exePath = line.split('=')[1];
        //console.log('📂 Đường dẫn MES:', exePath);
        callback(exePath);
        return;
      }
    }

    console.log('❌ Không tìm thấy ExecutablePath');
  });
}

function findAndReadConfig(exePath) {
  const exeDir = path.dirname(exePath);
  const configPath = path.join(exeDir, 'Config.json');

  if (!fs.existsSync(configPath)) {
    console.log('❌ Không tìm thấy Config.json trong:', configPath);
    return;
  }

  try {
    const content = fs.readFileSync(configPath, 'utf-8');
    const json = JSON.parse(content);

    if (json.usercode) {
      mesUsercode = json.usercode; // ✅ Lưu lại usercode
      //console.log('👤 Đã lấy usercode:', mesUsercode);

      // Sau khi có usercode, bắt đầu chạy theo dõi MES
      setInterval(watchMESOpenState, 1000);
    } else {
      console.log('⚠️ Không tìm thấy "usercode" trong Config.json');
    }
  } catch (err) {
    console.error('❌ Lỗi đọc hoặc parse Config.json:', err.message);
  }
}



async function sendToAPI(data) {
  try {
    //const response = await axios.post(API_ENDPOINT, data, { timeout: 5000 });
    //console.log('📡 Gửi thành công:', response.status);
    // 🔁 Gửi qua socket nếu có
    socket?.emit('mes-report', data);
  } catch (err) {
    console.error('❌ Gửi API thất bại:', err.message);
  }
}
function formatDateProgress() {
  const now = new Date();
  const dd = String(now.getDate()).padStart(2, '0');
  const mm = String(now.getMonth() + 1).padStart(2, '0'); // Tháng bắt đầu từ 0
  const yyyy = now.getFullYear();

  let hh = now.getHours();
  const min = String(now.getMinutes()).padStart(2, '0');
  const sec = String(now.getSeconds()).padStart(2, '0');
  const ampm = hh >= 12 ? 'PM' : 'AM';
  hh = hh % 12 || 12; // chuyển về 12h format

  const hour = String(hh).padStart(2, '0');

  return `${dd}/${mm}/${yyyy} ${hour}:${min}:${sec} ${ampm}`;
}
async function monitorMES() {
  try {
    const freeMemMB = os.freemem() / 1024 / 1024;
    if (freeMemMB < 100) {
      console.warn('🚫 Thiếu RAM, bỏ qua...');
      return;
    }

    const windows = windowManager.getWindows();

    const mesWindows = windows.filter(win => {
      const exeName = win.path?.split('\\').pop()?.toLowerCase();
      const title = win.getTitle()?.trim();
      return (
        exeName === 'sjemesclient.exe' &&
        title &&
        win.isVisible() &&
        !title.toLowerCase().includes('ime') &&
        !title.toLowerCase().includes('broadcast') &&
        !title.toLowerCase().includes('gdi')
      );
    });

    const mesWindowData = mesWindows.map(win => ({
      title: win.getTitle(),
      pid: win.processId,
    }));

    const payloadToCompare = {
      info: {
        user: getCurrentUsername(),
        ip: getIPAddress(),
        usercode: mesUsercode || '',
      },
      numMES: mesWindowData.length > 0
        ? `${mesWindowData.length}`
        : '0',
      detailProgress: mesWindowData,
    };


    const fullPayload = {
      ...payloadToCompare,
      dateProgress: formatDateProgress(),
    };

    const currentPayloadJson = JSON.stringify(payloadToCompare);
    const lastPayloadJson = JSON.stringify(lastSentPayload);

    if (currentPayloadJson !== lastPayloadJson) {
      //console.log('📤 Có thay đổi, gửi mới');
      console.log(JSON.stringify(fullPayload, null, 2));
      await sendToAPI(fullPayload);
      lastSentPayload = payloadToCompare;
    } else {
      //console.log('Không thay đổi, bỏ qua gửi');
    }
  } catch (err) {
    console.error('monitorMES lỗi:', err);
  }
}

// 🔌 Kết nối socket
const socket = io(SOCKET_ENDPOINT, {
  reconnection: true,
  transports: ['websocket']
});

// 📥 Lắng nghe sự kiện từ server
socket.on('connect', () => {
  //console.log('Đã kết nối Socket.IO server');
});

socket.on('ping-client', (msg) => {
  //console.log('Nhận lệnh từ server:', msg);
  //if (msg === 'force-report') {
  //monitorMES();
  //}
});

socket.on('disconnect', () => {
  //console.log('⚠️ Mất kết nối tới Socket.IO server');
});
async function watchMESOpenState() {
  try {
    const windows = windowManager.getWindows();

    const mesWindows = windows.filter(win => {
      const exeName = win.path?.split('\\').pop()?.toLowerCase();
      const title = win.getTitle()?.trim();
      return (
        exeName === 'sjemesclient.exe' &&
        title &&
        win.isVisible() &&
        !title.toLowerCase().includes('ime') &&
        !title.toLowerCase().includes('broadcast') &&
        !title.toLowerCase().includes('gdi')
      );
    });

    const isRunningNow = mesWindows.length > 0;

    await monitorMES();

    isMESRunningLastCheck = isRunningNow;
  } catch (err) {
    //console.error('❌ watchMESOpenState lỗi:', err);
  }
}

// 🔁 Theo dõi mỗi 1 giây
getMESClientPathViaWMIC(findAndReadConfig);
setInterval(watchMESOpenState, 1000);



