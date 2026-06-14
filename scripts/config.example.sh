# ============================================
# 每周任务更新 Skill - 配置模板
# ============================================
# 使用方式：
#   1. 复制此文件为 config.sh: cp config.example.sh config.sh
#   2. 填写以下配置项
#   3. config.sh 已自动被 .gitignore 排除，不会提交到仓库
#
# 如何获取配置：
#   AI 表格的 BASE_ID 和 TABLE_ID 可以从表格 URL 中提取
#   字段 ID 可以在 AI 表格设计模式下查看每个字段的属性
# ============================================

# AI 表格标识
# 从 AI 表格 URL 中获取，如 https://alidocs.dingtalk.com/i/nodes/xxx?baseId=YOUR_BASE_ID
BASE_ID="{{YOUR_BASE_ID}}"
TABLE_ID="{{YOUR_TABLE_ID}}"

# 字段 ID 映射（打开 AI 表格设计模式查看每个字段的 ID）
FIELD_TASK_NAME="{{YOUR_FIELD_ID}}"      # 任务名称字段
FIELD_TASK_UPDATE="{{YOUR_FIELD_ID}}"    # 任务情况更新字段
FIELD_TASK_STATUS="{{YOUR_FIELD_ID}}"    # 任务状态字段
FIELD_RESPONSIBLE="{{YOUR_FIELD_ID}}"    # 负责人字段
FIELD_DEPARTMENT="{{YOUR_FIELD_ID}}"     # 所属部门字段

# 任务状态选项（如果表格中的选项 ID 不同请修改）
STATUS_COMPLETED="{{YOUR_COMPLETED_ID}}"   # 已完成
STATUS_STARTED="{{YOUR_STARTED_ID}}"       # 刚启动
STATUS_UNFINISHED="{{YOUR_UNFINISHED_ID}}" # 未完成
