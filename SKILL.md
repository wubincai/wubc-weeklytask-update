---
name: wubc-weeklytask-update
description: 每周自动更新钉钉 AI 表格"每周任务跟进"中本人负责的任务进度。搜索钉钉聊天记录、钉钉文档、飞书聊天记录、飞书文档获取最近一周进展，按日期格式写入"本周任务情况更新"字段。当用户说"更新本周任务"、"更新周报"、"任务跟进"、"每周更新"等时触发。
---

# 每周任务更新

## 触发条件

用户指令包含以下关键词之一时触发本 Skill：
- 更新本周任务 / 更新周报 / 任务跟进 / 每周更新 / 周报
- 填写任务更新 / 同步本周进展 / 更新AI表格

## 前置条件

确认用户已登录非油品处组织（`dws auth login` 成功且组织正确）。如未登录，先执行登录。

## 配置信息

配置常量在 [scripts/config.sh](./scripts/config.sh) 中定义，包括：
- BASE_ID / TABLE_ID — AI 表格标识
- TARGET_USER_ID — 当前用户（吴斌才）的 userId
- FIELD_IDS — 各字段 ID 映射

## 工作流

### Step 1: 查询本人负责的任务

```bash
dws aitable record query --base-id <BASE_ID> --table-id <TABLE_ID> --all --format json
```

从返回中筛选 `cells.KLw3wWD[].userId === TARGET_USER_ID` 的记录，提取每个任务的：
- `recordId` — 更新用
- `01ZM8y7` — 任务名称
- `pMvAy3f` — 现有更新内容（需保留并追加）
- `ar5x47P` — 当前任务状态

### Step 2: 并行搜索 4 个渠道获取进展信息

对每个需要更新的任务，用其名称作为关键词，搜索最近 7 天内的信息。

#### 2a. 搜索钉钉聊天记录
```bash
dws chat message search --query "<任务名>" --start "<7天前T>" --end "<今天T>" --limit 30 --format json
```

#### 2b. 搜索钉钉文档
```bash
dws doc search --query "<任务名>" --format json
```
对返回的 `adoc` 文档，读取内容：
```bash
dws doc read --node <dentryUuid> --format json
```

#### 2c. 搜索飞书聊天记录
```bash
lark-cli im +search-message --query "<任务名>" --format json
```

#### 2d. 搜索飞书文档
```bash
lark-cli docs +search --query "<任务名>" --format json
```
对返回的 DOCX/WIKI 文档，读取内容：
```bash
lark-cli docs +fetch --doc <token> --doc-format markdown --format json
```

提取与任务进展相关的关键信息，按以下规范整理。

### Step 3: 按规范格式构造更新内容

**格式规范**（参考现有记录格式）：
```
月.日 进度总结 + 本周具体推进内容
```

**示例**：
```
6.7 demo版本持续优化中
6.8 6月工作计划确认：AI智能导购启动试点，由何萍负责推进
6.10 AI导购6站落地试点确认（延期），完成修改后测试并反馈最新修改需求
```

**规则**：
- 每条记录以 `月.日` 开头
- 每天一条最新进展（合并同一日期的多条信息为一条）
- 追加到现有内容末尾，**保留历史记录**（`现有内容\n新内容`）
- 如任务在某渠道无信息，跳过该渠道；如所有渠道均无信息，**留空并提醒用户**

### Step 4: 批量更新 AI 表格

```bash
dws aitable record update --base-id <BASE_ID> --table-id <TABLE_ID> \
  --records '<JSON_ARRAY>' --format json
```

`JSON_ARRAY` 格式（单次最多 30 条）：
```json
[
  {
    "recordId": "<RECORD_ID>",
    "cells": {
      "pMvAy3f": "现有内容\n新增推进内容"
    }
  }
]
```

### Step 5: 输出更新摘要

执行完成后，输出结构化的更新报告：

```markdown
## ✅ 本周任务更新完成

### 已更新任务
| 任务 | 最新进展 |
|------|---------|
| xxx | 6.10 ... |

### ⚠️ 未找到近期信息的任务
| 任务 | 说明 |
|------|------|
| xxx | 所有渠道均未找到近期进展，需要你补充 |
```

## 注意事项

- **时间范围**：搜索最近 7 天（`<今天-7天>T00:00:00+08:00` 到 `<今天>T23:59:59+08:00`）
- **跨组织访问**：当前用户登录在"非油品处"组织，不要切换组织
- **搜索无结果**：标记为"未找到信息"的任务需留空并告知用户
- **保留历史**：更新时保留原内容，新内容追加在末尾
- **并发限制**：批量更新单次不超过 30 条
