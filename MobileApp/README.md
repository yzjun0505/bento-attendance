# 境图移动端

境图移动端是打卡、定位、审批、消息和离线同步的 Flutter 客户端，对接 `BackEnd/server` 提供的 API，并在聊天能力可用时连接 OpenIM。

## 运行前准备

1. 启动后端服务，默认 API 地址为 `http://127.0.0.1:3000/api`。
2. Android 模拟器默认访问 `http://10.0.2.2:3000/api`。
3. 真机调试时可以在登录页点“后端服务地址 -> 修改”，填电脑局域网 IP，例如 `http://192.168.1.10:3000/api`。

```bash
flutter pub get
flutter run \
  --dart-define=SERVER_IP=192.168.1.10 \
  --dart-define=AMAP_WEB_KEY=你的高德WebJSKey \
  --dart-define=AMAP_KEY=你的高德Web服务Key
```

也可以直接指定完整地址：

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.10:3000/api \
  --dart-define=OPENIM_API_URL=http://192.168.1.10:10002 \
  --dart-define=OPENIM_WS_URL=ws://192.168.1.10:10001 \
  --dart-define=AMAP_WEB_KEY=你的高德WebJSKey \
  --dart-define=AMAP_KEY=你的高德Web服务Key
```

## 默认账号

账号由后端数据库初始化和管理后台创建。若本地库是新建的，先启动后端并在管理端创建人员，或查看 `BackEnd/server/models/db.js` 中默认管理员初始化逻辑。

## 环境诊断

App 内进入 `我的 -> 设置 -> 服务诊断` 可以查看当前 API/OpenIM 地址，并检测后端与 OpenIM HTTP 服务是否可访问。

登录页也可以直接修改和测试后端服务地址。保存后的地址会缓存在手机本地，下次启动继续使用。

## 常用命令

```bash
flutter analyze
flutter test
flutter build apk \
  --dart-define=SERVER_IP=192.168.1.10 \
  --dart-define=AMAP_WEB_KEY=你的高德WebJSKey \
  --dart-define=AMAP_KEY=你的高德Web服务Key
```

## 常见网络配置

- Android 模拟器：不传参数时默认使用 `10.0.2.2`。
- iOS 模拟器、macOS、Windows、Linux：不传参数时默认使用 `127.0.0.1`。
- Android 真机 USB：可执行 `adb reverse tcp:3000 tcp:3000` 后使用 `--dart-define=SERVER_IP=127.0.0.1`。
- 同一 Wi-Fi 真机：使用电脑局域网 IP，例如 `--dart-define=SERVER_IP=192.168.1.10`。
- 打卡页地图使用高德 Web JS API，必须传 `AMAP_WEB_KEY`；地址解析和周边地点使用高德 Web 服务 API，建议同时传 `AMAP_KEY`。
