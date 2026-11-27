# `pstack` 完整使用指南与实战手册（v0.15.48）

> 对应本机仓库 `D:\Code\Personal\pstack`（WSL2：`/mnt/d/Code/Personal/pstack`），2026-11-27 从 `backnotprop/pstack` 同步到 **0.15.48**。本仓库保留了 fork 自有的项目挂载脚本、上游同步脚本、项目级模型配置改写和本文件。
>
> 当前规模：**59 个 Skill**（其中 58 个显式触发）、**22 个 Playbook**、**24 条工程原则**。适用 Cursor、Claude Code、Codex、Antigravity、OMP、Pi、OpenCode 等 Agent Skills 宿主，以及 Windows / WSL2 双环境。

---

## 一、本机部署架构与全生命周期维护

pstack 采用**独立仓库 + 按项目挂载**的方式管理，避免把重型工程规则装进每次轻量对话：

| 项目 | 路径 / 值 |
| :--- | :--- |
| Windows 仓库 | `D:\Code\Personal\pstack` |
| WSL2 仓库 | `/mnt/d/Code/Personal/pstack` |
| `origin` | `https://github.com/fwrite0920/pstack.git` |
| `upstream` | `https://github.com/backnotprop/pstack.git` |
| 项目 Skill 目录 | `<项目>\.agents\skills\`、`<项目>\.pi\skills\` |
| 项目模型配置 | `<项目>\.agents\pstack-models.md`（Antigravity / Codex / OMP / Pi 等） |

### 1. 给指定项目挂载 / 卸载 pstack

**Windows PowerShell（NTFS Junction，Windows 与 WSL2 都能直接读取）：**

```powershell
# 挂载全部 59 个 Skill
D:\Code\Personal\pstack\link-project.ps1 -Target D:\Code\你的项目

# 只挂载挑选的几个 Skill
D:\Code\Personal\pstack\link-project.ps1 -Target D:\Code\你的项目 -Only architect,blast-radius,interrogate,tdd

# 安全卸载：只删除指向本仓库 skills 的链接，不碰项目自有 Skill
D:\Code\Personal\pstack\link-project.ps1 -Target D:\Code\你的项目 -Unlink
```

`-Tools` 可改挂载目录，默认 `@(".agents/skills", ".pi/skills")`。`-Only` 同时接受逗号分隔和 PowerShell 数组。

**WSL2 / Linux / macOS：**

```bash
# 挂载全部
/mnt/d/Code/Personal/pstack/link-project.sh ~/Code/你的项目

# 只挂载指定几个
/mnt/d/Code/Personal/pstack/link-project.sh --only architect,blast-radius,interrogate ~/Code/你的项目

# 安全卸载
/mnt/d/Code/Personal/pstack/link-project.sh --unlink ~/Code/你的项目
```

挂载是**增量**的：已存在的同名条目会跳过，不会覆盖项目自有 Skill；卸载只删除链接目标位于本仓库 `skills/` 下的符号链接或 Junction。

> **防误提交**：挂载到团队仓库时，把 `.agents/`、`.pi/` 写进**本地** `.git/info/exclude`，不改共享的 `.gitignore`：
> ```bash
> printf "\n.agents/\n.pi/\n" >> .git/info/exclude
> ```

### 2. 同步上游更新

```powershell
# Windows：先确保工作区干净
D:\Code\Personal\pstack\sync-upstream.ps1
```

```bash
# WSL2
/mnt/d/Code/Personal/pstack/sync-upstream.sh
```

脚本行为：检查工作区是否干净 → `git fetch upstream` → `git rebase upstream/main` → `git push --force-with-lease origin main`。

- 工作区有未提交改动时直接退出，先 commit 或 stash。
- rebase 冲突时脚本会停止并提示；解决冲突后执行 `git rebase --continue`，再手动 `git push --force-with-lease origin main`。
- 软链挂载的项目会立即看到 Skill 内容更新；只有上游**新增了 Skill 目录**时，才需要在用到的项目里重跑一次挂载脚本。

---

## 二、中文触发规则与跨工具使用技巧

### 1. 为什么必须写 `/英文命令` + 中文描述

59 个 Skill 里有 **58 个**设置了 `disable-model-invocation: true`。自然语言（中文或英文）都不会自动加载它们，必须显式键入 `/skill-name`，或者先进入 `/poteto-mode` 再由它调用。

唯一没有该标志的是 `setup-pstack`，所以它也能被“配置 pstack 模型”这类自然语言命中，但仍建议显式 `/setup-pstack`。

**黄金公式：**

```text
/skill-name <中文写清目标、背景、约束、验收标准>
```

### 2. 让回复稳定使用中文

1. 项目 `AGENTS.md` 加一行：`Always respond to the user in Simplified Chinese unless writing code or identifiers.`
2. 触发消息末尾加：`用中文汇报。`
3. 用 `/automate-me` 生成个人专属 `*-mode` Skill，把中文回复习惯固化进去。

### 3. 各宿主差异

| 宿主 | 子代理映射 | 会话记录位置（`reflect` / `recall` / `automate-me` 用） | 备注 |
| :--- | :--- | :--- | :--- |
| **Cursor** | `Task` | 系统提示给出的 `agent-transcripts/` | pstack 的原始宿主，兼容性最好 |
| **Claude Code** | `Agent`（`subagent_type: general-purpose`） | `~/.claude/projects/<slug>/*.jsonl` | 模型配置走 `~/.claude/rules/pstack-models.md` |
| **Codex** | `spawn_agent` | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | 只读取 `payload.cwd` 等于当前工作区的文件 |
| **Antigravity** | `invoke_subagent` / `swarm` 式并发 | 当前会话上下文；跨会话复盘需手动定位 | 原生也有 `/plan`、`/teamwork`、`/boost`、`/grill-me`，可与 pstack 互补 |
| **OMP** | 内置 subagent 工具 | 按工作区会话目录 | 识别 `.agents/skills/` |
| **Pi** | 无扩展时串行降级 | `~/.pi/agent/sessions/--<slug>--/*.jsonl` | 识别 `.pi/skills/` |
| **OpenCode** | `task`（`subagent_type: general`） | `~/.local/share/opencode/storage/` | 识别 `.agents/skills/` |

### 4. 模型配置写到哪里

| 宿主 | 设置文件 |
| :--- | :--- |
| Cursor | `~/.cursor/rules/pstack-models.mdc`（always-applied） |
| Claude Code | `~/.claude/rules/pstack-models.md` |
| Antigravity / Codex / OMP / Pi / OpenCode 等 | **当前项目根目录** `.agents/pstack-models.md` |

本机 fork 已把 `setup-pstack` 的写入位置改成：非 Cursor / Claude Code 宿主默认写项目级 `.agents/pstack-models.md`，不再污染 `~/.agents/`；`poteto-mode`、`poteto-help`、`arena`、`swarm` 的读取说明同步改为先找项目文件。只有项目文件不存在时才回退 `~/.agents/pstack-models.md`。

---

## 三、`/setup-pstack` 模型与预算配置

### 1. 运行流程

在已挂载 pstack 的项目根目录启动会话，输入：

```text
/setup-pstack
```

它会：

1. 探测当前宿主实际可用的模型 slug（绝不写未确认的模型名）。
2. 读取已有设置文件；没有就从默认值开始。旧版本遗留的无效角色行会被丢弃，并告知你替换了哪些旧默认值。
3. 让你选择预算档位，并按阶梯 `xhigh > high > medium > low` 调整每个角色。
4. 让你逐个确认角色模型，支持 `inherit-parent` / `auto`。
5. 校验所有真实 slug 都在可用集合内，然后**整文件覆盖**写入，保证重复运行幂等。
6. 可选生成 `/create-verification-skill`、`/create-formal-verification-skill`，拒绝不会强推。

### 2. 预算档位（0.15.48 只有三档）

| 档位 | 目标推理深度 | 说明 |
| :--- | :--- | :--- |
| `large — xhigh reasoning` | 保持各角色默认档 | 默认档，多数角色在 `xhigh` |
| `medium — high reasoning` | 默认降一档 | 日常开发更省 |
| `small — medium reasoning` | 默认降两档 | 轻量任务或低成本模型 |

没有任何角色高于 `xhigh`。`unlimited` 档已移除，旧文件里的 `# budget: unlimited` 会被改成 `large`。

### 3. 默认角色表

| 角色行 | 默认模型 |
| :--- | :--- |
| `feature, refactoring` | `claude-opus-5-5-xhigh-fast` |
| `bug-fix` | `claude-opus-5-5-xhigh-fast` |
| `perf-issue` | `claude-opus-5-5-xhigh-fast` |
| `hillclimb` | `claude-opus-5-5-xhigh-fast` |
| `judgment and prose` | `claude-opus-5-5-xhigh-fast` |
| `arena runners` | `claude-fable-5-2-high`, `claude-opus-5-5-high-fast`, `gemini-4-neon-xhigh` |
| `arena cross-judge pool` | `claude-opus-5-5-high-fast`, `gemini-4-neon-xhigh` |
| `swarm workers` | `claude-opus-5-5-high-fast` |
| `interrogate reviewers` | `claude-fable-5-2-high`, `claude-opus-5-5-high-fast`, `gemini-4-neon-xhigh` |

### 4. 设置文件格式

非 Cursor 宿主写入项目 `.agents/pstack-models.md`，内容形如（模型名按实际探测结果替换）：

```text
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model.
# defaults: 3
# budget: large (xhigh)
feature, refactoring: claude-opus-5-5-xhigh-fast
bug-fix: claude-opus-5-5-xhigh-fast
perf-issue: claude-opus-5-5-xhigh-fast
hillclimb: claude-opus-5-5-xhigh-fast
judgment and prose: inherit-parent
arena runners: claude-fable-5-2-high, claude-opus-5-5-high-fast, gemini-4-neon-xhigh
arena cross-judge pool: claude-opus-5-5-high-fast, gemini-4-neon-xhigh
swarm workers: inherit-parent
interrogate reviewers: claude-fable-5-2-high, claude-opus-5-5-high-fast, gemini-4-neon-xhigh
```

规则：

- **面板角色**（`arena runners`、`interrogate reviewers`）：逗号分隔几个条目，就并发派出几个子代理；列表越短越省。
- **`arena cross-judge pool`**：`arena` 只用一个裁判，并跳过与主模型同厂商的条目；`inherit-parent` / `auto` 等同于主模型，因此通常不会被选为异厂商裁判。
- **别名**：`auto` / `inherit-parent` 表示省略 `model`、直接派通用子代理跑在主对话模型上。
- **Codex**：建议把 `model` 与 `reasoning_effort` 分开传；若宿主拒绝某 slug，不要重复重试，改用同族最近可用 slug 或别名。
- 删除某行即回退该角色的 Skill 默认值。

---

## 四、主引擎 `/poteto-mode` 与 22 个 Playbook

### 1. `/poteto-mode` 开启后的硬规则

1. **首条回复先复述**：用自己的话复述目标、要解决的问题、预计最小改动，然后直接推进；只有不可逆操作才停下等确认。
2. **先定数据形状**：跨函数边界 → `/architect`；可并行 → `/swarm`；多方案竞标 → `/arena`；设计有争议 → `/interrogate`。
3. **能跑实验就不问人**：可逆、可观测的分叉先用原型或命令定答案；只把产品偏好和不可实验的取舍留给人。
4. **Playbook 建 Todo**：匹配任务后把步骤逐条抄进 Todo；跳过必须写 `skip: <原因>`。没有合适 Playbook 或任务很大时转 `/figure-it-out`。
5. **不可逆操作暂停**：共享分支 force-push、部署、删数据、给外部用户发消息前确认；本地可逆操作直接做。
6. **用实证结项**：不接受“编译通过”“改完了”，必须给出真实运行、复现对比或截图，并标注 `measured` / `inferred` / `guess`。
7. **文本收尾**：回复与文档分别过 `/unslop` 和 `/technical-writing`；提交前尽量跑 `cursor-team-kit` 的 `/deslop`，没有就自己重读 diff 清 AI 套话。

### 2. 22 个 Playbook 对照

#### A. 研发与架构

| Playbook | 何时触发 | 核心要求 |
| :--- | :--- | :--- |
| **Investigation** | 只读提问：怎么工作、为什么这样、该选 A 还是 B | 不改业务代码，追踪源码 / git 历史 / 运行态，结论带 `file:line` 引用 |
| **Bug fix** | 报告了缺陷或异常行为 | 先在真实表面复现；二分排因找第一现场；跨函数先 `architect`；同表面复测；有低成本测试则先落失败测试；开 PR |
| **Feature** | 新增或修改行为 | 追踪子系统 → `architect` 定形状 → 写 4 维吞吐检查点 → 委派实现（多方案走 `arena`）→ 真实验证 → 小步提交 |
| **Refactoring** | 行为不变的结构整理 | 先钉住行为基线（characterization test / 快照 / 等价脚本），再搬结构；清理须降低读者负担 |
| **Prototype** | UI、交互、布局或技术路线摇摆 | 禁止空洞评审，快速搭 2–3 个抛弃型原型，用真实观测拍板；原型不是产品代码 |
| **Visual parity** | 像素级还原或样式系统迁移 | 先建截图基线，再逐组件迁移；以 image diff 为零判通过，禁止改基线凑绿 |
| **Multi-phase plan** | 跨阶段改造或叠层 PR 规划 | 只交付分阶段 / 叠层 PR 计划与验证门禁，不提前写实现 |

#### B. 性能与取证

| Playbook | 何时触发 | 核心要求 |
| :--- | :--- | :--- |
| **Perf issue** | 某个具体操作慢，一次性排查提速 | 固定 fixture 量基线，Profile / Trace 找真实瓶颈，按“先少做、再做便宜”的顺序修，修后复测 |
| **Hillclimb** | 持续优化单一指标（评分、延迟、命中率） | 冻结测量工具 → 每轮一个假设、改一处、测前后、只保留胜出改动，`decision.tsv` 留痕 |
| **Runtime forensics** | 内存泄漏、CPU 空转、偶发卡顿 | 在运行态抓 profile / heap / trace 取证，只出根因诊断，不混改业务代码 |
| **Trace forensics** | 已有 `cpuprofile`、`trace`、`heapsnapshot`、`spindump` | 解析离线档案，把热点或保留链映射回源码；无符号映射就不算诊断完成 |

#### C. 自动化与长任务

| Playbook | 何时触发 | 核心要求 |
| :--- | :--- | :--- |
| **Autonomous run** | 有明确结束条件的长跑（`run until done`） | 先把完成条件写成可判定谓词，再循环“最小改动 → 验证 → 保留或回滚”，每轮留痕 |
| **Autopilot-full** | 一批独立 PR，全自动到合并 | 每个 PR 一个 Owner 从开发跑到绿灯；独立 swarm 复验后才允许合并 |
| **Autopilot-stack** | 同上，但产出相互依赖的叠层 PR | 全自动开发、压栈、复验，**不自动合并**，整条绿灯栈交给人合并 |
| **Session pickup** | 接手别人或上一会话做到一半的工作 | 先读 transcript、分支、决策日志，确认已完成项绝不返工，再路由到对应 Playbook |
| **Pause safely** | 临近压缩、重启或临时中断 | 提交 `wip:`、写恢复说明与下一步；明确要求“继续跑”时不暂停 |

#### D. 交付与仓库维护

| Playbook | 何时触发 | 核心要求 |
| :--- | :--- | :--- |
| **Babysit** | 盯 PR 到可合并 | 先声明 `drive` / `threads-only` / `check` 模式；处理冲突、评论、CI；babysit 本身从不授权合并，合并要等明确放行 |
| **Shipping** | 合并整条绿灯 PR 栈 | 每个 PR 由未写代码的独立验证者给出 PASS；从栈底连续已验证段向上合并 |
| **Opening a PR** | 其他开发 Playbook 的收尾 | worktree 内小步整理提交，PR 正文写 `## Why`、改动、范围、权衡、爆炸半径、验证 |
| **Worktree cleanup** | 磁盘告急或 worktree 堆积 | 审计后按“已合并 / 废弃 / 使用中 / 有未提交改动”分类；未提交工作删除前必须确认 |
| **Authoring a skill** | 编写或修改 `SKILL.md` | 按 Agent Skills 规范校验 frontmatter、引用和触发边界；能删就删 |
| **Eval** | 改完 Skill / Prompt 想盲测 | 隐藏实验元信息，候选只看自然任务；裁判盲评输出，不看模型名 |

---

## 五、独立 Skill 全览

> 以下 32 个非原则 Skill（`reflect`、`correct`、`automate-me` 见第六节），加 24 个 `principle-*`，共 59 个。

### 1. 理解、对齐与汇报

| Skill | 用途 |
| :--- | :--- |
| `/how` | 搞清“现在怎么跑”：调用链、状态归属、新代码该放哪一层 |
| `/why` | 从提交、PR 讨论和文档还原“当年为什么这样写”，结论带引用 |
| `/teach` | 调用 `how` + `why`，用大白话讲透一个改动或子系统 |
| `/in-your-own-words` | 动工前让 Agent 复述你的目标和问题，确认没理解偏 |
| `/reframe` | **0.15.48 新增**：你说不清自己在做什么时，给出 8–12 个专家术语（按会改变实现的程度排序）、邻近领域的借用概念、每个术语的真实项目链接，最后用新词重写你的描述 |
| `/recall` | 从历史会话、当前状态和共享记录重建近期工作上下文 |
| `/ketchup` | 快速追当前长会话：自你上次发言后改了什么、哪些事等你拍板 |
| `/ketchup-video` | 同 `/ketchup`，但输出带字幕的短视频幻灯片 |
| `/bro` | 把过度学术、啰嗦或满是内部名词的回复翻译成人话 |

### 2. 需求加深、设计与多方案竞速

| Skill | 用途 |
| :--- | :--- |
| `/sharpen` | 只重写提示词，不执行任务：补上顶级专家会做而你没提的事、原始材料、方法与外部校验，产出可直接发送的 Prompt |
| `/architect` | 写代码前给出类型、签名、模块边界两种形状并对比；大型或有争议的设计转 `/arena` |
| `/arena` | 多候选并发竞速 + 异厂商盲评 + 择优嫁接：Frame → Fan out → Cross-judge → Pick base → Graft → Verify |
| `/figure-it-out` | 没有现成 Playbook 时，为大型迁移、多部分改造或离开工位的长任务定制可审计方案 |

### 3. 编码、并行与测试

| Skill | 用途 |
| :--- | :--- |
| `/swarm` | 扇出 N 个并发 Worker 批量检查、复现竞态或多角度巡检，最后汇总成一张表 |
| `/tdd` | 精准节制的 TDD：只有低成本本地单测路径才先写失败测试；重集成问题走真实表面复现 |
| `/typescript-best-practices` | TypeScript 严格类型审查：收紧松散类型、消除 `any` 和不必要断言 |
| `/make-bot-ui` | 构建能通过 webhook 唤醒 Bot 的页面 / 面板，并处理 Tailscale 暴露；发送密钥只留在服务端 |

### 4. 对抗审查、影响面、文档与验证

| Skill | 用途 |
| :--- | :--- |
| `/interrogate` | 对抗式审查：只保留能用命令 / 测试跑出失败实证的问题，不提风格口水，不自动改代码 |
| `/blast-radius` | 找 grep 搜不到的隐蔽破坏面（第三方行为、时序、JSON 契约、跨语言字节流、Feature Flag），并写真实脚本证明核心安全前提 |
| `/no-comments` | 清理“复述代码在干嘛”的废话注释和阶段注释，只留解释原因或外部限制的注释 |
| `/unslop` | 砍掉 AI 套话、滥用破折号和空洞总结 |
| `/technical-writing` | 按 Diátaxis + Google 开发者文档风格写作或审校 README、RFC、PR 描述 |
| `/benchmark-checklist` | 报性能数字前的防造假清单：限流器、冷热缓存、静默失败、样本量、可复现性、是否真的执行了工作 |
| `/create-verification-skill` | 生成项目级 `verify-*` Skill：自动启动应用、按用户路径操作核心流程、留截图 / 日志证据，并保证清理不误删证据 |
| `/maintain-verification-skill` | 定期审计已有验证 Skill：每个 feature 并行读源码 + 真实跑一遍，最多产出一个已证实修正的 PR |
| `/create-formal-verification-skill` | 为并发、重试、状态机、解析器、unsafe 代码生成形式化验证 Skill；并发 / 交错顺序默认 TLA+，并故意注入破坏确认模型能抓到 |
| `/maintain-formal-verification-skill` | 代码变更后更新形式化模型、harness 和性质，重跑并判断失败是模型漂移还是真 Bug |
| `/statechart` | 跑 TLA+ 模型检查，把状态机画成 Mermaid，并给出违反不变量的最短路径；原生 Windows 用 Node 22.18–22.x 或 ≥23.6 直接跑 TypeScript 脚本 |

### 5. 留痕、配置与向导

| Skill | 用途 |
| :--- | :--- |
| `/show-me-your-work` | 维护 append-only `decisions.tsv`，记录每个关键决策的 what / why / evidence / result，收尾时对照会话审计 |
| `/poteto-help` | 不知道该用哪个 Skill 时，根据当前状态推荐并给出可直接粘贴的提示词 |
| `/setup-pstack` | 检测可用模型，按预算写入逐角色模型配置，并可选生成验证 Skill |
| `/poteto-mode` | 主引擎，见上一节 |

---

## 六、自进化与防呆闭环

### 1. `/reflect` — 任务收尾复盘

读取当前工作区本次会话记录，过滤一次性信息（版本号、SHA），输出 **Accepted（问题 / 提案 / 目标 Skill）**、**Rejected**、**Backlog**，**等你确认后才改文件**。

```text
/reflect 复盘这次会话的坑和我的纠正，只保留半年后仍有价值的经验并给出修改提案。
```

### 2. `/correct` — 把重复错误从机制上堵死

假设下一个 Agent 只打开一个文件、照最近例子抄、能编译就提交。按优先级处理：

1. **架构消除**：单一所有权、单一入口，删掉容易抄错的旧接口；
2. **类型系统**：让非法状态写不出来；
3. **带修复提示的 Lint / CI**：报错直接说该改用哪个文件或函数；
4. **行为测试**：删改真实逻辑时测试必挂；
5. **文档 / `AGENTS.md`**：最后兜底，并维护“规则 ↔ 强制检查手段”对照表。

每加一道检查，都要用过去真实犯过的错证明它能拦住。

### 3. `/automate-me` — 从历史习惯提炼个人 `*-mode`

跨近 2–4 周会话切成多片并发挖掘，跨 2 个以上切片重复出现的模式才算高置信，用选择题对齐边界，生成 `<你的名字>-mode/SKILL.md`；以后基于 `git log` 增量更新。

> **软链环境提醒**
> 挂载后的 `.agents/skills/*` 指向本仓库 `skills/*`。
> - 跨项目通用经验，才让 `/reflect` 改本仓库 Skill；
> - 某个项目独有的规范和坑，让 `/correct` 写进该项目的 `AGENTS.md` / Lint / CI 或新建项目专属 Skill，避免污染通用仓库。

---

## 七、24 条工程原则速查

平时不必手动 `/principle-*`，在 `/poteto-mode` 下点名原则即可；Agent 会重读该原则全文并说明它改了哪个决定。

| 分类 | 原则 | 一句话含义 | 纠偏口令 |
| :--- | :--- | :--- | :--- |
| **Core** | `laziness-protocol` | 偏向删代码与最小改动，拒绝多余抽象 | `Apply laziness-protocol. Keep the smallest change.` |
| **Core** | `foundational-thinking` | 动工前想清核心类型、数据结构和共享边界 | `Apply foundational-thinking. Define the data shape first.` |
| **Core** | `redesign-from-first-principles` | 接新需求按第一性原理重构，不打歪补丁 | `Apply redesign-from-first-principles instead of patching.` |
| **Core** | `attack-the-premise` | 同一前提连续失败两次，先写下前提并直接验证 | `Apply attack-the-premise. Test the assumption directly.` |
| **Core** | `subtract-before-you-add` | 重构或新增前先删死代码、废校验和桩引用 | `Apply subtract-before-you-add before adding code.` |
| **Core** | `minimize-reader-load` | 合并单调用方包装层，缩小可变作用域 | `Apply minimize-reader-load. Collapse wrapper layers.` |
| **Core** | `outcome-oriented-execution` | 大迁移直接收敛到终态，不留过渡兼容层 | `Apply outcome-oriented-execution.` |
| **Core** | `experience-first` | 产品 / UX 权衡时优先用户体验 | `Apply experience-first.` |
| **Core** | `exhaust-the-design-space` | 无先例的新设计先做 2–3 个原型横评 | `Apply exhaust-the-design-space. Prototype the options.` |
| **Core** | `build-the-lever` | 批量改动或校验先写可重跑脚本，不纯手工 | `Apply build-the-lever. Write a reusable script.` |
| **Arch** | `model-the-domain` | 用状态机、类型、查表替代散落 `if/else` | `Apply model-the-domain. Replace flags with a state table.` |
| **Arch** | `boundary-discipline` | 校验集中在系统边缘，内部逻辑保持纯粹 | `Apply boundary-discipline.` |
| **Arch** | `type-system-discipline` | 让非法状态在类型上无法表达 | `Apply type-system-discipline.` |
| **Arch** | `make-operations-idempotent` | 命令和生命周期步骤在崩溃重试后收敛到同一终态 | `Apply make-operations-idempotent.` |
| **Arch** | `migrate-callers-then-delete-legacy-apis` | 同一波次迁完旧调用方并删除旧 API | `Apply migrate-callers-then-delete-legacy-apis.` |
| **Arch** | `separate-before-serializing-shared-state` | 并发写冲突优先拆分文件 / 目录，其次才加锁 | `Apply separate-before-serializing-shared-state.` |
| **Verify** | `prove-it-works` | 最常用：拿真实运行、落盘、截图说话，编译不算数 | `Apply prove-it-works. Show real runtime output.` |
| **Verify** | `fix-root-causes` | 追到第一出错源头再修，不靠吞错掩盖症状 | `Apply fix-root-causes. Trace to the origin.` |
| **Verify** | `sequence-verifiable-units` | 每步改完独立验证，再进下一步和提交 | `Apply sequence-verifiable-units.` |
| **Verify** | `test-behavior-not-implementation` | 测外部可观察行为，不锁死私有实现 | `Apply test-behavior-not-implementation.` |
| **Verify** | `explain-the-number` | 报性能数字前先找瓶颈上限并排除测偏 | `Apply explain-the-number before reporting metrics.` |
| **Deleg** | `guard-the-context-window` | 大文件、长日志交给子代理，主线程只留摘要 | `Apply guard-the-context-window. Offload raw logs.` |
| **Deleg** | `never-block-on-the-human` | 可逆操作先做出来给人看，不每步都问 | `Apply never-block-on-the-human for reversible steps.` |
| **Meta** | `encode-lessons-in-structure` | 同样的提醒说第二遍，就写成 Lint / 脚本 / 类型约束 | `Apply encode-lessons-in-structure.` |

---

## 八、端到端实战剧本

### 剧本 1：接手陌生模块并安全加功能

1. `"/how 梳理这个模块的数据流、状态生命周期，以及新代码该放哪一层"`
2. `"/why 为什么缓存上限是 200，且用手动轮询？查提交和 PR 讨论"`
3. `"/architect 加增量同步。先给类型和模块边界两种方案，我确认后再写"`
4. `"/poteto-mode 按确认的设计实现增量同步，保持原有导出结果不变，跑真实场景验证"`
5. `"/interrogate 审查当前分支，只报能用实际运行证明的 Bug"` + `"/no-comments"`

### 剧本 2：修时好时坏的疑难 Bug

```text
/poteto-mode 文件被外部删除后，文件树有时 10 秒都不刷新。
先在真实界面复现，再二分排因定位根因并修复，最后给出修复前后的对比输出。用中文汇报。
```

怀疑会殃及别处时收尾补：

```text
/blast-radius 分析取消 watchFolder 对其他页面的影响，并写真实脚本证明核心安全前提成立。
```

### 剧本 3：说不清需求时先对齐词汇

```text
/reframe 设置页有些字段保存即生效，有些要点提交，用户经常丢编辑。
```

拿到术语表和重写后的描述后，再交给 `/sharpen` 或 `/poteto-mode`。

### 剧本 4：离开工位挂长任务

**离开前：**

```text
/poteto-mode 我要离开几小时。请在基于 main 新建的 git worktree 里完成 <目标>。
完成标准是 `<验证命令>` 全部通过。
用 /show-me-your-work 维护决策日志。可逆提交不用问我。
连续几轮卡住就停下，在总结里写明卡在哪、已排除了什么。
```

**回来后：**

```text
/show-me-your-work 先看 Attention 部分，汇报昨晚的关键决策和最终校验输出。
```

看不懂长对话就发 `/ketchup`。

### 剧本 5：Agent 老在同一个仓库犯同样的错

```text
/correct Agent 在这个仓库总是忘记跑同步脚本就提交。
查最近两次犯错，优先从架构、Lint 或测试堵死，并用过去犯错的状态证明新检查能拦住。
```

工作流程不顺手则用 `/reflect` 调整 Skill 描述或步骤。

### 剧本 6：给重点项目加“真实驱动 + 形式化校验”

```text
/create-verification-skill 给当前 Web/CLI 应用生成 verify-app，能独立启动、走完登录到核心操作并留证。
```

```text
/create-formal-verification-skill 为任务队列抢锁与重试幂等建立 TLA+ 模型，并故意注入一次错误验证模型能抓到。
```

代码变化后，用 `/maintain-verification-skill` 和 `/maintain-formal-verification-skill` 保持模型与真实代码同步。

---

## 九、常见排障 FAQ

| 现象 | 原因 | 解决 |
| :--- | :--- | :--- |
| 自然语言触发不了 Skill | 58 个 Skill 设了 `disable-model-invocation: true` | 用 `/skill-name + 中文内容`，或先 `/poteto-mode` |
| 几轮后 `/poteto-mode` 像失效了 | 上下文稀释或话题切换 | 每个新大任务重新显式触发；换话题写 `New task: ...` |
| `/setup-pstack` 改完不生效 | 旧会话缓存；或文件写到了别的项目 | 新开会话；确认项目根目录有 `.agents/pstack-models.md`（Cursor / Claude Code 用各自全局规则文件） |
| 配置里的模型名宿主不认识 | 该宿主不支持这个 slug | 重跑 `/setup-pstack` 探测真实模型，或把角色设为 `inherit-parent` / `auto` |
| 多个子代理互相覆盖代码 | 多个写操作共享同一工作区 | Prompt 明确要求每个写代码的子代理用独立 `git worktree` |
| Agent 说“改好了、编译通过”但没跑通 | 未触发真实端到端验证 | `/poteto-mode` 下点名 `Apply prove-it-works`，要求真实输出 |
| 过夜长任务空转 | 没有可判定的完成条件 | 先写 PASS/FAIL 断言或命令，再限定最大尝试次数 |
| 同步后找不到新 Skill | 上游新增了 Skill 目录，旧挂载没包含 | 对目标项目重跑 `link-project.ps1` / `.sh` |
| 同步脚本报工作区不干净 | 有未提交改动 | 先 commit 或 stash，再跑 `sync-upstream` |
| rebase 冲突 | 本地修改与上游改到同一文件 | 解决冲突 → `git rebase --continue` → 手动 `git push --force-with-lease origin main` |

---

## 十、延伸阅读

仓库自带的分章指南在 `docs/guide/`：

| 文件 | 内容 |
| :--- | :--- |
| `01-setup.md` | 安装与初始配置 |
| `02-poteto-mode.md` | 主模式与工作方式 |
| `03-understand.md` | 理解代码与历史 |
| `04-design.md` | 设计与方案竞速 |
| `05-build-and-clean.md` | 实现与清理 |
| `06-verify-and-ship.md` | 验证与交付 |
| `07-overnight.md` | 长任务与无人值守 |
| `08-principles.md` | 24 条原则 |
| `09-make-it-yours.md` | 定制与自进化 |
| `10-recipes-and-pitfalls.md` | 配方与坑 |

英文入口见 `README.md`；本文件是本机 fork 的中文补充说明，不随上游同步覆盖。
