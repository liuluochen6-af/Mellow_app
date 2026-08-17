# Mellow

一款用照片、日历和地图记录生活足迹的原生 iOS App。

Mellow 面向喜欢探店、旅行和记录生活的人：你可以为餐厅、饮品、娱乐、购物和景点创建打卡，用四档评分记录感受，并在日历、地图和统计页中回顾自己的探索轨迹。项目同时提供好友动态、评论与收藏等轻社交能力。
idea来源于很多时候和朋友聚餐都要先用手机拍照记录，事后回想起这家店味道不错，想再去吃，发现地址很难寻找。那为什么不直接用一个app来拍照并记录自己对这家店的感受、价格、环境等，同时直接标注地点，方便下次再去打卡。

> iOS 工程和 target 仍使用 `FoodCheckin` 作为内部名称，安装后的 App 名称为 **Mellow**。

## 演示与安装

[▶️ 观看 60 秒中文配音演示](docs/mellow-demo-zh.mp4)

> **iPhone 安装说明：** 当前版本尚未通过 App Store 或 TestFlight 分发，因此 GitHub 上暂时不能直接安装。开发者可以按照下方步骤使用 Xcode 运行；公开 TestFlight 链接发布后会在这里提供一键安装入口。

## 功能亮点

- **快速打卡**：添加照片、地点、分类、评分、标签、备注和可选消费金额。
- **日历回顾**：通过月历、年历、照片墙和月度汇总查看过去的记录。
- **地图足迹**：展示地点图钉、访问过的国家与城市，以及城市级聚合结果。
- **数据统计**：查看类别分布、消费趋势、常去地点和月度数据。
- **轻量社交**：添加好友、浏览公开动态、评论、接收通知和收藏打卡。
- **多种登录方式**：支持手机号验证码和 Sign in with Apple。
- **本地体验优化**：提供草稿、Keychain 登录态和有限的 API 响应缓存。

## 技术栈

| 模块 | 技术 |
| --- | --- |
| iOS | Swift 5.9、SwiftUI、MapKit、PhotosUI、AuthenticationServices、CryptoKit |
| API | Python 3.10–3.12、FastAPI、Pydantic |
| 数据访问 | SQLAlchemy Async、Alembic |
| 数据库 | PostgreSQL（生产）、SQLite（本地开发与测试） |
| 包管理 | uv |
| 第三方服务 | 阿里云短信、Sign in with Apple |
| 部署 | Uvicorn、Nginx、systemd、Let's Encrypt |

## 项目结构

```text
.
├── FoodCheckin/
│   ├── FoodCheckin.xcodeproj/       # Xcode 工程
│   ├── FoodCheckin/
│   │   ├── Models/                  # iOS 数据模型
│   │   ├── Resources/               # 评分图标与地图数据
│   │   ├── Services/                # API、认证、定位和缓存服务
│   │   ├── Utils/                   # Keychain、草稿和分享工具
│   │   └── Views/                   # SwiftUI 页面
│   └── project.yml                  # XcodeGen 配置
├── backend/
│   ├── app/
│   │   ├── models/                  # SQLAlchemy 模型
│   │   ├── routers/                 # FastAPI 路由
│   │   ├── schemas/                 # 请求与响应模型
│   │   └── services/                # Apple、短信、城市和图片服务
│   ├── tests/                       # pytest 测试
│   ├── .env.example                 # 环境变量模板
│   └── pyproject.toml               # Python 项目配置
└── docs/                            # 产品设计、实施计划和原型
```

## 快速开始

### 环境要求

- macOS 和 Xcode（最低支持 iOS 17）
- Python 3.10–3.12
- [uv](https://docs.astral.sh/uv/)

### 1. 运行后端

```bash
git clone https://github.com/liuluochen6-af/food.git
cd food/backend
cp .env.example .env
```

本地开发建议将 `.env` 调整为：

```env
DATABASE_URL=sqlite+aiosqlite:///./foodcheckin.db
APP_ENV=development
SMS_DEBUG_RETURN_CODE=true
APPLE_CLIENT_ID=com.foodcheckin.app
SECRET_KEY=replace-with-a-random-local-secret
```

安装依赖并启动 API：

```bash
uv sync
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

检查服务是否可用：

```bash
curl http://localhost:8000/health
```

预期返回 `{"status":"ok"}`。启动后可访问 [Swagger API 文档](http://localhost:8000/docs)。

在开发环境中，如果没有配置阿里云短信密钥，验证码会打印在后端终端；开启 `SMS_DEBUG_RETURN_CODE` 后，客户端也可自动填入开发验证码。生产环境必须关闭此选项。

### 2. 运行 iOS App

1. 使用 Xcode 打开 `FoodCheckin/FoodCheckin.xcodeproj`。
2. 选择 iOS 17 或更高版本的模拟器。
3. 确认本地 API 已在 `8000` 端口运行。
4. 运行 `FoodCheckin` scheme。

模拟器默认连接 `http://localhost:8000`。真机地址配置位于 `FoodCheckin/FoodCheckin/Services/APIClient.swift`；部署到自己的环境时，请改成对应的 HTTPS API 地址。

## 环境变量

| 变量 | 使用场景 | 说明 |
| --- | --- | --- |
| `DATABASE_URL` | 必填 | SQLAlchemy 异步数据库连接字符串 |
| `APP_ENV` | 推荐 | `development`、`test` 或 `production` |
| `SECRET_KEY` | 必填 | Token 签名密钥，生产环境应使用足够长的随机值 |
| `APPLE_CLIENT_ID` | Apple 登录 | 必须与 App Bundle ID `com.foodcheckin.app` 一致 |
| `SMS_ACCESS_KEY_ID` | 短信 | 阿里云 AccessKey ID |
| `SMS_ACCESS_KEY_SECRET` | 短信 | 阿里云 AccessKey Secret |
| `SMS_SIGN_NAME` | 国内短信 | 已审核的短信签名 |
| `SMS_TEMPLATE_CODE` | 国内短信 | 已审核的验证码模板代码 |
| `SMS_INTERNATIONAL_SENDER_ID` | 国际短信 | 目标国家允许的 Sender ID |
| `SMS_INTERNATIONAL_MESSAGE_TEMPLATE` | 国际短信 | 国际短信模板，必须包含 `{code}` |
| `SMS_DEBUG_RETURN_CODE` | 仅本地 | 是否在响应中返回开发验证码；生产环境必须为 `false` |

请勿提交 `.env`、数据库密码、短信密钥、Apple 私钥或 SSH 私钥。

## 登录配置

### 手机号登录

- 中国大陆号码支持 11 位格式和 `+86` 格式。
- 国际号码应使用 E.164 格式，例如 `+61412345678`。
- 国内号码调用阿里云 `SendSms`，国际号码调用 `SendMessageToGlobe`。
- 验证码有效期为 5 分钟，同一号码的发送间隔为 60 秒。

### Sign in with Apple

项目已包含 Sign in with Apple entitlement。正式使用前还需要：

1. 加入 Apple Developer Program。
2. 为 App ID `com.foodcheckin.app` 启用 Sign in with Apple。
3. 在 Xcode 的 **Signing & Capabilities** 中选择开发团队并配置签名。
4. 保持后端 `APPLE_CLIENT_ID` 与 Bundle ID 一致。
5. 使用 HTTPS API；后端会验证 Apple identity token 的签名、签发方、audience、有效期和 nonce。

## API 概览

| 模块 | 主要接口 |
| --- | --- |
| 认证 | `/api/auth/send-code`、`/phone-login`、`/apple-login`、`/me` |
| 打卡 | `/api/checkins`、`/mine`、`/search`、`/calendar`、`/map-pins` |
| 统计 | `/api/stats/overview`、`/category-breakdown`、`/spending`、`/top-places` |
| 社交 | `/api/social/friends`、`/feed`、`/comments/{checkin_id}`、`/notifications` |

完整的请求参数和响应结构以运行时的 `/docs` 为准。

## 测试与构建

运行后端测试：

```bash
cd backend
uv run pytest -q
```

测试涵盖手机号与短信、Apple token 验证、认证和资料、打卡与统计，以及城市归类规则。

验证 iOS 工程可编译：

```bash
xcodebuild \
  -project FoodCheckin/FoodCheckin.xcodeproj \
  -scheme FoodCheckin \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 部署说明

仓库提供了基础的 Linux 生产部署配置：

- `backend/foodcheckin.service`：运行 FastAPI/Uvicorn 的 systemd 服务。
- `backend/nginx.conf`：HTTPS、API 反向代理和上传文件配置。
- `backend/mellow-certbot-renew.service`：Let's Encrypt 证书续期服务。
- `backend/mellow-certbot-renew.timer`：证书续期定时器。
- `backend/certbot-reload-nginx.sh`：证书更新后的 Nginx 校验与重载脚本。

推荐的请求链路为：`iOS App → HTTPS/Nginx → Uvicorn/FastAPI → PostgreSQL`。部署前请根据自己的域名、证书路径、服务器用户和数据库连接修改示例配置。

## 城市归类

`backend/app/services/city.py` 是城市名称规范化的最终规则来源。当前会将墨尔本都市圈内的 suburb 统一归类为“墨尔本”，读取统计和区域数据时也会规范化历史记录。新增城市规则时，请同步补充 `backend/tests/test_city.py`。

## License

本仓库暂未声明开源许可证。未经项目所有者许可，请勿公开分发或用于商业用途。
