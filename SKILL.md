---
name: wubc-weeklytask-update
description: 每周自动更新钉钉 AI 表格"每周任务跟进"中本人负责的任务进度。搜索钉钉群消息、钉钉私聊消息、钉钉文档、飞书聊天消息、飞书文档、飞书妙记共6个渠道获取最近一周进展，按日期格式写入"本周任务情况更新"字段。首次使用需要配置 AI 表格信息。每次执行时引导用户为无关键词的任务补充搜索关键词。当用户说"更新本周任务"、"更新周报"、"任务跟进"、"每周更新"等时触发。
---

# 每周任务更新

## 触发条件

用户指令包含以下关键词之一时触发本 Skill：
- 更新本周任务 / 更新周报 / 任务跟进 / 每周更新 / 周报
- 填写任务更新 / 同步本周进展 / 更新AI表格

## 前置条件

使用本 Skill 前，用户需要：
1. 已安装并登录 `dws` CLI 到自己的钉钉组织
2. 已安装并登录 `lark-cli`（使用 `--as user` 身份）
3. AI 表格（钉钉文档 AI 表格）中已有任务数据

如未登录，先执行登录：
```bash
dws auth login --device     # 钉钉登录（扫码）
lark-cli auth login --as user  # 飞书登录（如需要）
```

## 首次配置

首次使用本 Skill 时，需要配置 AI 表格信息。配置存储在 `scripts/config.sh` 中，持续生效。

**配置步骤：**

1. 复制配置模板：
   ```
   cp scripts/config.example.sh scripts/config.sh
   ```

2. 提供你的 AI 表格信息：
   - BASE_ID 和 TABLE_ID：打开 AI 表格，从 URL 中提取
   - 字段 ID：在 AI 表格设计模式下，查看每个字段的属性面板获取

3. 字段 ID 参考（以"每周任务跟进"表格为例）：
   - 任务名称字段：通常为 `01ZM8y7`
   - 任务情况更新字段：通常为 `pMvAy3f`
   - 任务状态字段：通常为 `ar5x47P`
   - 负责人字段：通常为 `KLw3wWD`
   - 所属部门字段：通常为 `2ABVleH`

4. 如果 `scripts/config.sh` 不存在或关键字段为空，在执行 Step 1 之前会引导你完成配置。

## 工作流

### Step 1: 查询用户本人负责的任务

**1a. 确认用户身份**

在执行查询前，先询问用户的姓名：

> 请问你的名字是？（用于筛选 AI 表格中你负责的任务）

用户提供姓名后，尝试通过组织通讯录查找用户 ID：

```bash
# 用姓名搜索组织联系人，获取 userId
dws contact user search --query "<用户姓名>" --format json
```

从返回结果中提取 `userId`（即用户 ID）。如果搜索无结果，可以请用户直接提供 userId：

> 没找到你的信息，请在钉钉「设置 → 账号与安全」中查看你的 userId，告诉我。

**1b. 查询任务列表**

```bash
# 从 config.sh 中读取 BASE_ID 和 TABLE_ID
source scripts/config.sh
dws aitable record query --base-id "<BASE_ID>" --table-id "<TABLE_ID>" --all --format json
```

**1c. 筛选本人负责的任务**

从返回中筛选 `cells.<FIELD_RESPONSIBLE>[].userId === <用户userId>` 的记录，提取每个任务的：
- `recordId` — 更新用
- `<FIELD_TASK_NAME>` — 任务名称
- `<FIELD_TASK_UPDATE>` — 现有更新内容
  - 检查现有内容最后一行是否已包含当天日期（如 `6.14 xxx`），如有则跳过该任务（今天已更新过）
  - 否则保留完整历史，准备追加
- `<FIELD_TASK_STATUS>` — 当前任务状态
- `<FIELD_DEPARTMENT>` — 任务所属部门

**注意**：多负责人任务（负责人字段中有多个 userId）仍然属于你的任务范围，同样需要更新。

### Step 1.5: 收集搜索关键词（必须由用户提供）

**这一步不可跳过，没有搜索关键词的任务必须让用户提供。**

查询完任务后，对每个任务收集搜索关键词。关键词存储在技能目录下的 `scripts/keywords.json` 文件中，跨会话持久化。

**执行逻辑：**

1. 读取 `scripts/keywords.json`（如不存在则创建空对象）
2. 对照 Step 1 查到的任务列表，检查每个任务是否已有关键词
3. **对于没有关键词的任务**，展示给用户，引导用户为每个任务提供 2-4 个搜索关键词
4. 用户提供后，保存到 `scripts/keywords.json`
5. 所有任务都有关键词后，才能进入 Step 2

**关键词的作用**：任务名称在聊天/文档中往往不会被完整提到（如"进店转化系统性策略（与零管对接）"），但"引客进店""碰一碰"反而高频出现。关键词填得准，搜索到的信息就多。

**keywords.json 格式：**
```json
{
  "<recordId_xxx>": ["关键词1", "关键词2"],
  "<recordId_yyy>": ["关键词A", "关键词B", "关键词C"]
}
```

**引导用户的示例话术：**
```
以下任务还没有搜索关键词，请为每个任务提供 2-4 个关键词，
这些关键词会在聊天、文档、会议纪要中搜索，用来找任务进展。

任务1：xxx → 你觉得别人一般怎么称呼这个任务？
任务2：yyy → 搜哪些词能找到相关进展？
```

### Step 2: 用搜索关键词全面搜索6个渠道

对每个需要更新的任务，用 Step 1.5 收集的搜索关键词逐一搜索以下 6 个渠道最近 7 天的信息。
所有渠道同等重要，每个关键词 × 每个渠道都必须搜索，不可跳过。

**搜索时间范围**：`<今天-7天>T00:00:00+08:00` 到 `<今天>T23:59:59+08:00`

**搜索逻辑（三层嵌套，逐层执行，不可遗漏）：**

```
for each 任务 T in 待更新任务列表:
  source scripts/config.sh    # 加载配置
  for each 关键词 K in T.keywords[]:
    # --- 渠道1+2: 钉钉所有消息（群聊+私聊）---
    dws chat message search --query K --start "<7天前T>" --end "<今天T>" --limit 100
    # --- 渠道3: 钉钉文档 ---
    dws doc search --query K --limit 30
    对返回的 adoc 文档 → dws doc read 读取内容
    # --- 渠道4: 飞书聊天消息 ---
    lark-cli im +messages-search --query K --chat-type group --start "<7天前T>" --end "<今天T>"
    lark-cli im +messages-search --query K --chat-type p2p --start "<7天前T>" --end "<今天T>"
    # --- 渠道5: 飞书文档 ---
    lark-cli docs +search --query K
    对返回的 DOCX/WIKI 文档 → lark-cli docs +fetch 读取内容
    # --- 渠道6: 飞书妙记 ---
    lark-cli minutes +search --query K --start "<今天-7天>" --end "<今天>"
```

#### 渠道 1+2：钉钉群消息 + 私聊消息

```bash
dws chat message search --query "<关键词>" --start "<7天前T>" --end "<今天T>" --limit 100 --format json
```

搜索所有钉钉会话（群聊 + 私聊）。`dws chat message search` 没有 `--conversation-type` 参数区分群聊/私聊，如需精准区分，可先用 `dws chat search --query "<群名>"` 查出群 ID 再传 `--group`。

**结果判断**：看返回的消息列表是否有内容。有内容则提取每条消息的文本，判断是否与任务进展相关。

#### 渠道 3：钉钉文档

```bash
dws doc search --query "<关键词>" --limit 30 --format json
```

对返回结果中 `contentType === "ALIDOC"` 的条目，读取内容：
```bash
dws doc read --node "<nodeId>" --format json
```
提取 `markdown` 字段。空文档跳过。根据 `createTime` 判断时效性（近 7 天内才保留）。

#### 渠道 4：飞书聊天消息

分别搜索群聊和私聊：
```bash
lark-cli im +messages-search --query "<关键词>" --chat-type group --start "<7天前T>" --end "<今天T>" --format json
lark-cli im +messages-search --query "<关键词>" --chat-type p2p --start "<7天前T>" --end "<今天T>" --format json
```

**结果判断**：看 `data.messages[]` 是否为空。提取每条消息的 `content` 文本和 `create_time`。

**信息源参考**：
- 与 AI 助手的私聊对话可能包含周待办汇总、催办记录等
- 工作群聊消息可能包含进度同步
- 发送人如果是用户自己，说明是主动记录的进展

#### 渠道 5：飞书文档

```bash
lark-cli docs +search --query "<关键词>" --format json
```

对返回结果中 `entity_type === "DOC"` 或 `"WIKI"` 的条目，且 `update_time_iso` 在最近 7 天内，读取内容：
```bash
lark-cli docs +fetch --doc "<token>" --doc-format markdown --format json
```

**注意**：`+search` 不支持指定时间范围，通过返回的 `update_time_iso` 自行筛选。`+fetch` 不支持多维表（bitable），遇到报错跳过。

#### 渠道 6：飞书妙记

```bash
lark-cli minutes +search --query "<关键词>" --start "<今天-7天>" --end "<今天>" --format json
```

提取妙记标题和摘要，判断是否与任务进展相关。

#### 信息汇总与去重

所有渠道、所有关键词搜索完成后，对每个任务汇总结果：

1. 同一个关键词在多个渠道搜到同一进展 → 只取一次
2. 同一个任务在不同关键词搜到同一进展 → 只取一次
3. 合并同一日期的多条信息为一条
4. 如果所有渠道都搜不到进展 → **留空，Step 5 提醒用户**

**进展判断规则**：
- 提到具体推进动作 → 提取为进展
- 只提到任务名无具体动作 → 不作为进展
- 用户自己的待办规划文档中的计划内容 → 可作为进展
- 系统自动催办消息 → 不作为进展（只是提醒）

### Step 3: 按规范格式构造更新内容

**格式规范**：
```
月.日 进度总结 + 本周具体推进内容
```

**示例**：
```
6.7 demo版本持续优化中
6.8 6月工作计划确认：AI智能导购启动试点，由何萍负责推进
6.10 AI导购6站落地试点确认（延期），完成修改后测试并反馈最新修改需求
6.14 确定海宁试点项目方案，启动引客进店海宁片区试点筹备
```

**规则**：
- 每条记录以 `月.日` 开头
- 每天一条最新进展（合并同日信息为一条）
- 追加到现有内容末尾，**保留历史记录**（`现有内容\n新内容`）
- 如果现有记录最后一行已是当天日期，跳过该任务

### Step 4: 批量更新 AI 表格

```bash
source scripts/config.sh
dws aitable record update --base-id "<BASE_ID>" --table-id "<TABLE_ID>" \
  --records '<JSON_ARRAY>' --format json
```

`JSON_ARRAY` 格式（单次最多 30 条）：
```json
[
  {
    "recordId": "<RECORD_ID>",
    "cells": {
      "<FIELD_TASK_UPDATE>": "现有内容\n新增推进内容"
    }
  }
]
```

### Step 5: 输出更新摘要

```markdown
## ✅ 本周任务更新完成（X月X日-X月X日）

### 已更新任务
| 任务 | 最新进展 |
|------|---------|
| xxx | 6.14 ... |

### ⚠️ 未找到近期信息的任务
| 任务 | 说明 |
|------|------|
| xxx | 所有渠道均未找到近期进展，需要你补充 |

### 搜索统计
| 渠道 | 搜索关键词数 | 命中任务数 |
|------|-------------|-----------|
| 钉钉群消息 | N | N |
| 钉钉私聊消息 | N | N |
| 钉钉文档 | N | N |
| 飞书聊天消息 | N | N |
| 飞书文档 | N | N |
| 飞书妙记 | N | N |
```

## 注意事项

- **时间范围**：搜索最近 7 天
- **当天重复更新跳过**：如现有记录最后一行已是当天日期，跳过该任务
- **多关键词搜索**：一个任务有多个关键词时逐个搜索，结果合并去重
- **6个渠道缺一不可**：每个关键词必须搜索全部 6 个渠道
- **并发限制**：批量更新单次不超过 30 条
- **搜索关键词必须用户提供**：没有关键词的任务不能跳过，需先让用户补充

## 已知问题与处理策略

### 搜索通道可靠性

| 通道 | 可靠性 | 典型问题 | 处理方式 |
|------|--------|---------|---------|
| `lark-cli docs +search` | 高 | 偶尔 DNS 失败 | 重试 1-2 次 |
| `lark-cli docs +fetch` | 中 | `docs_ai` 端点易 DNS 失败；不支持 bitable | 重试；失败仅用摘要 |
| `lark-cli im +messages-search` | 高 | — | 正常使用 |
| `lark-cli minutes +search` | 高 | — | 正常使用 |
| `dws doc search` | 中 | 返回旧文档多、`--page-size` 上限 30 | 关注 createTime 时效性 |
| `dws doc read` | 中 | 空文档返回空 markdown | 空内容跳过 |
| `dws chat message search` | 低 | 实战中几乎总是返回空结果 | 仍须搜索，空则跳过 |

### Go CLI 间歇性 DNS 失败

Go 编写的 CLI（lark-cli, dws）在 Codex 沙箱中可能出现间歇性 DNS 解析失败，表现为 `dial tcp: lookup xxx: no such host`。处理策略：
- 失败后等待 1-2 秒重试一次
- 重试仍失败则跳过该通道
- 不要因此中断整体流程
