# Agent LLM Wiki

一个轻量的 Markdown 外部知识库，让不同 Agent、不同会话共享项目背景、长期知识和决策记录。

仓库采用 Karpathy 所说的 LLM Wiki 思路：知识以普通文件保存，Agent 通过统一的 Skill 读取、整理和维护。核心功能不依赖数据库、向量服务或特定编辑器。

## 把仓库链接发给 Agent

把本仓库链接发给 Codex、Trae、OpenCode、Pi 或 Claude Code，然后告诉它：

> 安装这个仓库里的 llm-wiki Skill，通过对话帮我初始化 Wiki schema。

Agent 会检出仓库并执行：

```sh
./install.sh --harness <codex|trae|opencode|pi|claude>
```

安装后，Agent 会询问知识库名称、用途、语言、主题区域和额外字段，再调用 `llm-wiki init` 创建 Wiki。

## 手动初始化

```sh
llm-wiki init --root ~/Knowledge/MyWiki \
  --name "My Wiki" \
  --purpose "保存项目背景、技术结论和长期记忆" \
  --language "中文" \
  --areas "projects,engineering,decisions"
```

初始化会生成：

```text
MyWiki/
├── LLM-WIKI.md              # 可读、可修改的 schema
├── AGENTS.md                # Agent 维护规则
├── wiki/                    # 整理后的长期知识
│   ├── index.md
│   ├── log.md
│   └── memory/              # 审核后的长期记忆
├── raw/                     # 原始来源
│   ├── documents/
│   ├── repositories/
│   ├── memories/
└── .llm-wiki/
    ├── sources.tsv          # 来源登记表
    └── private-inbox/       # Hook 捕获、Git 默认忽略的候选记忆
```

已有 `AGENTS.md` 会保留原文，只追加带标记的 Wiki 维护规则。

## 导入资料

```sh
# 本地文件或网页
llm-wiki import document ./notes/design.md --root ~/Knowledge/MyWiki
llm-wiki import document https://example.com/spec.md --root ~/Knowledge/MyWiki

# 本地或远程 Git 仓库，只保留 HEAD 中受版本控制的文件
llm-wiki import repo https://github.com/org/project.git --root ~/Knowledge/MyWiki

# 其他 Agent 的记忆，只接收 .md、.json、.jsonl
llm-wiki import memory ~/.codex/memories --root ~/Knowledge/MyWiki --name codex-memory
```

导入命令只保存来源并登记 provenance，不会擅自改写原文。Agent 随后读取 `raw/` 中的材料，把可复用内容整理进 `wiki/`。提交前仍应检查记忆文件里是否含有隐私或密钥。

查看状态：

```sh
llm-wiki status --root ~/Knowledge/MyWiki
```

## 通过 Skill 管理记忆

```sh
# 写入审核后的长期记忆
llm-wiki memory remember api-choice \
  --root ~/Knowledge/MyWiki \
  --content "项目统一使用 Responses API。" \
  --summary "项目 API 选型" \
  --topics "project,decision"

# 新证据出现后修改原记忆
llm-wiki memory update api-choice \
  --root ~/Knowledge/MyWiki \
  --content "项目默认使用 Responses API，旧服务暂时保留 Chat Completions。"

# 根据当前问题召回相关记忆
llm-wiki memory recall "项目 API 选型" --root ~/Knowledge/MyWiki --limit 5 --max-bytes 16384
```

## 通过 Hook 自动捕获和召回

安装脚本还会安装 `llm-wiki-hook`：

```sh
# 会话开始或提交提示词时，把相关长期记忆输出给 Agent
LLM_WIKI_ROOT=~/Knowledge/MyWiki llm-wiki-hook session-start
LLM_WIKI_ROOT=~/Knowledge/MyWiki llm-wiki-hook prompt

# 会话结束时，把 transcript 放入待审核 inbox
LLM_WIKI_ROOT=~/Knowledge/MyWiki \
LLM_WIKI_CAPTURE=1 \
LLM_WIKI_TRANSCRIPT=/path/to/session.jsonl \
llm-wiki-hook session-end
```

会话捕获默认关闭，只有显式设置 `LLM_WIKI_CAPTURE=1` 才启用。Hook 会限制输入大小、脱敏常见凭证，并以 `0600` 权限写入 Git 默认忽略的 `.llm-wiki/private-inbox/`。它不会把原始对话直接升级为长期记忆；`llm-wiki` Skill 仍需审核候选内容，再调用 `memory remember` 或 `memory update`。

Claude Code 的完整 Hook 配置，以及 Codex、Trae、OpenCode、Pi 的通用适配协议，见 `skills/llm-wiki/references/hooks.md`。

## 卸载

```sh
./uninstall.sh --harness <codex|trae|opencode|pi|claude>
```

卸载只移除 Skill、`llm-wiki` 和 `llm-wiki-hook` 命令，不会删除任何 Wiki 数据，也不会修改 harness 自己的 Hook 配置。

## 设计边界

- 数据使用 Markdown、原始文件和一份 TSV 来源登记表。
- 核心命令使用 POSIX shell。远程文档按需调用 `curl`，代码仓库按需调用 `git`。
- `raw/` 保存不可变的原始资料，`wiki/` 保存整理后的长期知识。
- Skill 使用通用 `SKILL.md` 结构，可以安装到多个 Agent harness。
- 初始化和导入默认拒绝覆盖已有目标，并清洗导入名称以阻止路径穿越。

## 测试

```sh
sh -n install.sh uninstall.sh skills/llm-wiki/scripts/llm-wiki \
  skills/llm-wiki/scripts/llm-wiki-hook tests/test_llm_wiki.sh
./tests/test_llm_wiki.sh
```

## License

MIT
