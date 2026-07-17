# 吃喝玩乐打卡 (FoodCheckIn)

一款以个人记录 + 游戏化成就为核心的 iOS 打卡 App。记录去过的餐厅、咖啡店、景点等地点，通过日历和地图两个维度回顾探索足迹。

## 项目结构

```
food/
├── FoodCheckin/          # iOS SwiftUI 前端
│   └── FoodCheckin/
│       └── Views/
│           ├── Auth/         # 登录注册
│           ├── Calendar/     # 日历视图 + 照片墙 + 月度统计
│           ├── CheckIn/      # 打卡页面
│           ├── Map/          # 地图 + 区域填色 + 图钉标记
│           ├── Profile/      # 个人中心 + 统计
│           └── Social/       # 好友动态
├── backend/              # Python FastAPI 后端
│   ├── app/
│   │   ├── routers/      # API 路由 (auth/checkin/stats/social)
│   │   ├── models/       # SQLAlchemy 数据模型
│   │   └── ...
│   └── pyproject.toml
└── docs/
    ├── prototype.html    # 交互式 HTML 原型（可直接浏览器打开）
    └── superpowers/      # 产品设计文档
```

## 技术栈

| 层 | 技术 |
|----|------|
| iOS 前端 | SwiftUI + MapKit + PhotosUI |
| 后端 | Python FastAPI + SQLAlchemy (async) |
| 数据库 | SQLite (aiosqlite)，可切换 PostgreSQL |
| 包管理 | uv (Python) |
| 地图 | Apple MapKit + MKPolygon 区域填色 |

## 快速开始

### 后端

```bash
cd backend

# 安装 uv（如果没有）
curl -LsSf https://astral.sh/uv/install.sh | sh

# 安装依赖并启动
uv sync
uv run uvicorn app.main:app --reload --port 8000
```

API 文档：http://localhost:8000/docs

### iOS 前端

用 Xcode 打开 `FoodCheckin/FoodCheckin.xcodeproj`，选择模拟器运行。

### HTML 原型

直接浏览器打开 `docs/prototype.html`，可预览所有页面交互。

## 功能模块

- **打卡**：拍照 → 选地点 → 评分(夯/不错/一般/拉) → 标签 → 发布
- **日历**：月视图打卡日期标记、年月跳转、照片墙（按日期降序）、月度统计
- **地图**：已打卡区域填色、照片图标图钉、点击缩放到街道级、区域菜单跳转
- **统计**：按年月筛选，探索足迹/类别分布/消费统计/最佳推荐
- **社交**：好友动态、评论、@提醒

## API 接口

| 路由 | 说明 |
|------|------|
| `POST /api/auth/login` | 登录 |
| `POST /api/checkins` | 创建打卡 |
| `GET /api/checkins` | 获取打卡列表 |
| `GET /api/stats/overview?year=&month=` | 探索足迹统计 |
| `GET /api/stats/category-breakdown?year=&month=` | 类别分布 |
| `GET /api/stats/spending?year=&month=` | 消费统计 |
| `GET /api/stats/top-places?year=&month=` | 最佳推荐 |
| `GET /api/stats/monthly-summary?year=&month=` | 月度汇总 |

## 设计风格

- 暖色米黄/奶油色背景 (`#FAF5EE`)
- 深棕色文字 (`#594026`)
- 金色高亮 (`#C29A6B`)
- 圆角卡片式 UI
