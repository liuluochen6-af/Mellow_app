# Mellow

Mellow 是一款以个人地点记录为核心的 iOS 打卡应用。用户可以记录餐厅、饮品店、娱乐场所、购物地点和景点，通过日历、地图和统计页面回顾自己的探索足迹，也可以与好友分享动态。

当前 iOS 工程内部仍沿用 `FoodCheckin` target 名称，安装到设备后显示名称为 **Mellow**。

## 主要功能

- **手机号登录**：支持中国大陆手机号和带国家区号的国际号码。
- **Apple ID 登录**：使用随机 nonce，并由后端验证 Apple identity token 的签名、签发方、Bundle ID 和有效期。
- **地点打卡**：选择照片和地点，填写类别、评分、标签、备注及可选消费金额。
- **四档评分**：夯、不错、一般、拉，使用自定义黑色圆形图标。
- **日历回顾**：按日期查看打卡记录、照片墙和年度汇总。
- **地图足迹**：显示打卡图钉、已访问区域和城市级聚合。
- **城市归类**：后端统一负责城市名称规范化；墨尔本都市圈内地点统一显示为“墨尔本”，包括历史打卡数据。
- **数据统计**：类别分布、消费统计、最佳地点及月度汇总。
- **好友与收藏**：好友申请、好友动态、评论、通知和收藏。
- **个人中心**：修改头像与昵称、查看记录和删除账号。
- **缓存优化**：限制内存与磁盘缓存大小，并缓存部分 API 响应，减少重复加载。

## 技术栈

| 模块 | 技术 |
| --- | --- |
| iOS | Swift 5.9、SwiftUI、MapKit、PhotosUI、AuthenticationServices、CryptoKit |
| 后端 | Python 3.10–3.12、FastAPI、SQLAlchemy Async |
| 数据库 | PostgreSQL（生产）、SQLite（本地开发与测试） |
| Python 包管理 | uv |
| 短信 | 阿里云国内短信 SendSms、国际短信 SendMessageToGlobe |
| 登录 | 手机验证码、Sign in with Apple |
| 部署 | Ubuntu、systemd、Nginx、Let’s Encrypt |

## 项目结构

```text
food-main/
├── FoodCheckin/
│   ├── FoodCheckin.xcodeproj/       # Xcode 工程
│   ├── FoodCheckin/
│   │   ├── Assets.xcassets/         # App 图标
│   │   ├── Models/                  # iOS 数据模型
│   │   ├── Resources/               # 评分图标与地图数据
│   │   ├── Services/                # API、认证、位置、缓存等服务
│   │   └── Views/
│   │       ├── Auth/                # Apple/手机号登录
│   │       ├── Calendar/            # 日历与照片墙
│   │       ├── CheckIn/             # 创建和编辑打卡
│   │       ├── Map/                 # 地图与城市区域
│   │       ├── Profile/             # 个人中心
│   │       ├── Social/              # 好友动态
│   │       └── Stats/               # 数据统计
│   └── project.yml                  # XcodeGen 配置
├── backend/
│   ├── app/
│   │   ├── models/                  # SQLAlchemy 模型
│   │   ├── routers/                 # FastAPI 路由
│   │   ├── schemas/                 # 请求/响应结构
│   │   └── services/                # Apple、短信、城市、图片服务
│   ├── tests/                       # 后端测试
│   ├── nginx.conf                   # 生产反向代理与 HTTPS
│   └── foodcheckin.service          # systemd 服务
└── docs/                            # 原型和设计资料
```

## 本地运行

### 环境要求

- macOS 与 Xcode（项目最低支持 iOS 17）
- Python 3.10–3.12
- [uv](https://docs.astral.sh/uv/)

### 1. 启动后端

```bash
cd backend
cp .env.example .env
```

本地开发可将 `.env` 中的数据库改成 SQLite：

```env
DATABASE_URL=sqlite+aiosqlite:///./foodcheckin.db
APP_ENV=development
SMS_DEBUG_RETURN_CODE=true
APPLE_CLIENT_ID=com.foodcheckin.app
SECRET_KEY=replace-with-a-random-local-secret
```

不配置阿里云短信 AccessKey 时，开发环境会在后端终端打印验证码；当 `SMS_DEBUG_RETURN_CODE=true` 时，iOS 登录页会自动填入开发验证码。生产环境不会返回验证码。

安装依赖并启动：

```bash
uv sync
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

验证服务：

```bash
curl http://localhost:8000/health
```

预期响应：

```json
{"status":"ok"}
```

API 文档地址：<http://localhost:8000/docs>

### 2. 启动 iOS App

1. 用 Xcode 打开 `FoodCheckin/FoodCheckin.xcodeproj`。
2. 选择 iOS 17 或更高版本的模拟器。
3. 启动本地后端。
4. Run 工程。

模拟器使用 `http://localhost:8000`，真机使用 `https://8.137.156.254`。地址定义在：

```text
FoodCheckin/FoodCheckin/Services/APIClient.swift
```

## 环境变量

| 变量 | 必填范围 | 说明 |
| --- | --- | --- |
| `DATABASE_URL` | 全部环境 | SQLAlchemy 异步数据库连接 |
| `APP_ENV` | 推荐 | `development`、`test` 或 `production` |
| `SECRET_KEY` | 生产必填 | 应使用足够长的随机值 |
| `APPLE_CLIENT_ID` | Apple 登录 | 必须等于 `com.foodcheckin.app` |
| `SMS_ACCESS_KEY_ID` | 生产短信 | 阿里云 AccessKey ID |
| `SMS_ACCESS_KEY_SECRET` | 生产短信 | 阿里云 AccessKey Secret |
| `SMS_SIGN_NAME` | 国内短信 | 已审核的短信签名 |
| `SMS_TEMPLATE_CODE` | 国内短信 | 已审核的验证码模板代码 |
| `SMS_INTERNATIONAL_SENDER_ID` | 国际短信 | 目标国家允许的 Sender ID |
| `SMS_INTERNATIONAL_MESSAGE_TEMPLATE` | 国际短信 | 必须包含 `{code}` |
| `SMS_DEBUG_RETURN_CODE` | 仅本地 | 生产环境必须为 `false` |

不要提交真实 `.env`、短信密钥、数据库密码、Apple 私钥或 SSH 私钥。

## 登录配置

### 手机号登录

- 中国大陆号码可输入 11 位手机号，也支持 `+86`。
- 国际号码必须使用 E.164 格式，例如 `+61412345678`。
- 国内号码调用阿里云 `SendSms`。
- 国际号码调用阿里云 `SendMessageToGlobe`。
- 验证码有效期为 5 分钟，同一号码发送间隔为 60 秒。

### Apple ID 登录

iOS target 已包含 `Sign in with Apple` entitlement。后端从 Apple JWKS 地址获取并缓存公钥，不接受客户端自行声明的 Apple 用户 ID。

上线前必须完成：

1. 加入付费 Apple Developer Program；免费的 Personal Team 不支持 Sign in with Apple。
2. 为 App ID `com.foodcheckin.app` 启用 **Sign in with Apple**。
3. 在 Xcode 的 **Signing & Capabilities** 中选择付费 Team，并开启自动签名。
4. 保持服务器 `APPLE_CLIENT_ID=com.foodcheckin.app`。
5. 真机 API 必须使用 HTTPS。

## 城市级聚合

客户端只负责提交地理编码结果，后端 `backend/app/services/city.py` 是城市归类的最终规则来源。

当前规则：

- 墨尔本都市圈坐标范围内的地点统一归类为“墨尔本”。
- Glen Waverley、Richmond、Box Hill 等 suburb 不会作为独立城市展示。
- 读取统计和区域数据时也会规范化历史记录。
- 其他国家和地区默认使用地理编码返回的城市值，不回退到区、县或 suburb。

新增特殊都市圈规则时，应同时增加 `backend/tests/test_city.py` 测试。

## API 概览

### 认证

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/send-code` | 发送手机验证码 |
| POST | `/api/auth/phone-login` | 手机验证码登录 |
| POST | `/api/auth/apple-login` | Apple identity token 登录 |
| GET | `/api/auth/me` | 获取当前用户 |
| PUT | `/api/auth/profile` | 修改昵称或头像 |
| DELETE | `/api/auth/delete-account` | 删除账号 |

### 打卡

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/checkins` | 创建打卡 |
| GET | `/api/checkins/mine` | 当前用户打卡列表 |
| GET | `/api/checkins/search` | 搜索打卡 |
| GET | `/api/checkins/calendar` | 日历数据 |
| GET | `/api/checkins/year-summary` | 年度汇总 |
| GET | `/api/checkins/map-pins` | 地图图钉 |
| GET | `/api/checkins/visited-regions` | 已访问国家与城市 |
| GET/PUT/DELETE | `/api/checkins/{checkin_id}` | 查看、修改或删除打卡 |

### 统计与社交

- `/api/stats/*`：总览、类别、消费、最佳地点和月度统计。
- `/api/social/*`：好友、申请、动态、评论、通知及收藏。

完整请求结构和调试入口以 FastAPI 的 `/docs` 为准。

## 测试

运行全部后端测试：

```bash
cd backend
uv run pytest -q
```

当前测试覆盖：

- 国内及国际手机号规范化
- 短信发送错误与开发模式
- Apple JWT 签名、audience 和 nonce 验证
- 认证、账号删除和个人资料
- 打卡创建、查询和统计
- 墨尔本城市归类及历史数据聚合

验证 iOS 编译：

```bash
xcodebuild \
  -project FoodCheckin/FoodCheckin.xcodeproj \
  -scheme FoodCheckin \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 生产部署

当前生产结构：

```text
iOS App
   │ HTTPS
   ▼
Nginx :443
   │
   ▼
Uvicorn/FastAPI 127.0.0.1:8000
   │
   ▼
PostgreSQL
```

仓库包含：

- `backend/foodcheckin.service`：FastAPI systemd 服务
- `backend/nginx.conf`：HTTP 跳转 HTTPS、API 反向代理和上传文件
- `backend/mellow-certbot-renew.service`：证书续期服务
- `backend/mellow-certbot-renew.timer`：每天两次检查续期
- `backend/certbot-reload-nginx.sh`：续期后验证并重载 Nginx

生产 API 当前使用 Let’s Encrypt 公网 IP 短期证书。该证书约 6 天有效，因此自动续期 timer 和续期后的 Nginx reload hook 都必须保持启用。

常用检查命令：

```bash
sudo systemctl status foodcheckin --no-pager
sudo systemctl status nginx --no-pager
sudo systemctl status mellow-certbot-renew.timer --no-pager
curl https://8.137.156.254/health
```

## 数据与安全说明

- 用户、打卡、好友、评论、通知和收藏数据保存在后端数据库。
- 登录 token 保存在 iOS Keychain，重新打开 App 不需要再次输入手机号。
- 上传图片保存在服务器 `uploads` 目录，通过 Nginx 提供访问。
- Apple identity token 只通过 HTTPS 发送，并在后端验签。
- 生产环境禁止返回短信验证码。
- 删除账号会删除当前后端用户记录；发布前仍应根据最终隐私政策确认关联数据清理和第三方授权撤销要求。

## License

当前仓库尚未声明开源许可证。未经项目所有者许可，请勿将代码用于公开分发或商业用途。
