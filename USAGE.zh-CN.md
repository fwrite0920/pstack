# `pstack` 完整使用指南与实战用例手册（v0.15.43 定制版）

> 本文档对应你本机 `D:\Projects\pstack\`（同步自 `backnotprop/pstack` 最新 `0.15.43`，并已包含项目级配置隔离与一键挂载/同步脚本），适用于 **Antigravity、Codex、OMP、Pi** 以及 **Windows / WSL2** 双环境。

---

## 一、本机部署架构与全生命周期维护

为了避免重型工程规则污染日常轻量对话，`pstack` 采用**独立仓库 + 按项目软链挂载**方式管理，全局目录保持极简：

- **本地独立仓库**：
  - Windows：`D:\Projects\pstack\`（`origin` → `https://github.com/fwrite0920/pstack.git`，`upstream` → `https://github.com/backnotprop/pstack.git`）
  - WSL2：`/mnt/d/Projects/pstack/`
- **项目级发现目录**（挂载后由各工具自动识别）：
  - `<项目根目录>/.agents/skills/`（Antigravity、Codex、OMP、OpenCode 共用）
  - `<项目根目录>/.pi/skills/`（Pi 专用）
- **项目级模型配置隔离**：
  - 本仓库已修改 `setup-pstack`、`poteto-mode`、`poteto-help`、`arena`、`swarm` 等 Skill：模型配置会写入**当前项目根目录的 `.agents/pstack-models.md`**，不会污染用户全局 `~/.agents/`。

### 1. 给指定项目挂载 / 卸载 `pstack`

**Windows PowerShell（使用 NTFS Junction，Windows 与 WSL2 均可直接读取）：**
```powershell
# 挂载全套 58 个 Skill 到指定项目
D:\Projects\pstack\link-project.ps1 -Target D:\Projects\你的项目

# 只挂载挑选的几个 Skill（适合轻量项目）
D:\Projects\pstack\link-project.ps1 -Target D:\Projects\你的项目 -Only architect,blast-radius,interrogate,tdd

# 从项目中安全卸载（仅删除指向 D:\Projects\pstack\skills 的链接，不碰项目自有 Skill）
D:\Projects\pstack\link-project.ps1 -Target D:\Projects\你的项目 -Unlink
```

**WSL2 / Linux Bash：**
```bash
# 挂载全套
/mnt/d/Projects/pstack/link-project.sh ~/Projects/你的项目

# 只挂载指定几个
/mnt/d/Projects/pstack/link-project.sh --only architect,blast-radius,interrogate ~/Projects/你的项目

# 安全卸载
/mnt/d/Projects/pstack/link-project.sh --unlink ~/Projects/你的项目
```

> **防误提交小技巧**：挂载到团队 Git 仓库时，建议把 `.agents/` 和 `.pi/` 加进**本地** `.git/info/exclude`（不改共享 `.gitignore`）：
> ```bash
> printf "\n.agents/\n.pi/\n" >> .git/info/exclude
> ```

### 2. 同步上游 `backnotprop/pstack` 更新

```powershell
# Windows
D:\Projects\pstack\sync-upstream.ps1
```
```bash
# WSL2
/mnt/d/Projects/pstack/sync-upstream.sh
```
脚本会执行 `git fetch upstream` → `git rebase upstream/main` → `git push --force-with-lease origin main`（若发生 rebase 冲突会立即中止并提示你解决）。已通过软链挂载的项目会自动生效；仅当上游**新增了全新的 Skill 目录**时，才需要在用到新 Skill 的项目下重跑一次 `link-project`。

---

## 二、中文触发规则与跨工具使用技巧

### 1. 为什么一定要用“`/英文命令` + 中文描述”？
`pstack` 中绝大多数 Skill（`poteto-mode`、`architect`、`interrogate`、`blast-radius`、`sharpen`、`swarm`、`tdd`、`reflect`、`correct` 等）都设置了 **`disable-model-invocation: true`**。这意味着：
- **纯中文（甚至纯英文）自然语言都不会自动加载它们**，必须由你**显式键入 `/skill-name`**（或者先进入 `/poteto-mode`，再由它按步骤调用其他 Skill）。
- 唯一没设该标志的是 `setup-pstack`（也可直接用 `/setup-pstack` 显式调用）。

**黄金触发公式**：
```text
/skill-name <直接用中文写清楚目标、背景、约束和完成校验标准>
```

### 2. 如何保证稳定用中文回复？
`poteto-mode` 和 `unslop` 的部分写作规则默认面向英文。要让它稳定输出中文，有三种方式：
1. 在项目的 `AGENTS.md` 加一行：`Always respond to the user in Simplified Chinese unless writing code or identifiers.`
2. 在触发消息末尾带一句：`用中文汇报。`
3. 通过 `/automate-me` 生成你自己的中文习惯专属 `*-mode` Skill。

### 3. 四端（Antigravity / Codex / OMP / Pi）运行差异
| 工具 | 子代理映射 | 历史会话路径（供 `reflect`/`recall`/`automate-me` 读取） | 注意事项 |
| :--- | :--- | :--- | :--- |
| **Codex** | `spawn_agent` | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | `.agents/pstack-models.md` 里的 slug 与 `reasoning_effort` 建议分开写清楚 |
| **Antigravity** | `invoke_subagent` / `swarm` | 当前会话上下文（外部日志路径不同，跨会话复盘需手指定位） | 原生也有 `/plan`、`/teamwork`、`/boost`、`/grill-me`，与 `pstack` 互补 |
| **OMP** | 内置 subagent 工具 | 按工作区会话目录 | 兼容 `.agents/skills/` |
| **Pi** | 若无 subagent 扩展则串行降级 | `~/.pi/agent/sessions/--<slug>--/*.jsonl` | `.pi/skills/` 与 `.agents/skills/` 均可识别 |

---

## 三、`/setup-pstack` 模型与预算配置详解

### 1. 运行方式
在已挂载 `pstack` 的项目根目录启动会话后输入：
```text
/setup-pstack
```
它会依次完成：
1. 检测当前终端/宿主实际可用的模型 slug（绝不瞎编不存在的模型名）。
2. 若当前项目已有 `.agents/pstack-models.md`，读取既有选择；否则从默认值出发。
3. 让你选定 4 档预算之一，并按阶梯 `max > xhigh > high > medium > low` 自动调整各角色推理深度：
   - `unlimited — max reasoning`（全部升一档至 `max`）
   - `large — xhigh reasoning`（默认档，多数常规角色 `xhigh`、最难任务 `max`）
   - `medium — high reasoning`（降一档至 `high`）
   - `small — medium reasoning`（降两档至 `medium`）
4. 让你确认每个角色绑定的模型（支持设为 `inherit-parent` 或 `auto`，表示直接沿用当前主对话模型，省钱且避免跨厂商报错）。
5. 写入当前项目的 `.agents/pstack-models.md`，并礼貌询问一次是否需要生成 `/create-verification-skill` 或 `/create-formal-verification-skill`（拒绝也不会强推）。

### 2. `.agents/pstack-models.md` 配置格式与角色含义
```text
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# defaults: 2
# budget: large (xhigh)
feature, refactoring: auto/gpt-6.2-sol
bug-fix: auto/gpt-6.2-sol
perf-issue: auto/gpt-6.2-sol
hillclimb: auto/gpt-6.2-sol
judgment and prose: auto/gpt-6.2-sol
hardest tasks: auto/gpt-6.2-astra
reflect tooling: auto/gpt-6.2-sol
reflect judgment, divergent, synthesizer: auto/gpt-6.2-sol
arena runners: auto/gpt-6.2-sol, sunplus/C1/anthropic/deepseek-flash
arena cross-judge pool: sunplus/C1/anthropic/deepseek-flash
swarm workers: sunplus/C1/anthropic/deepseek-flash
architect runners: auto/gpt-6.2-sol, sunplus/C1/anthropic/deepseek-flash
interrogate reviewers: auto/gpt-6.2-sol, sunplus/C1/anthropic/deepseek-flash
```
- **面板角色（`arena runners`、`architect runners`、`interrogate reviewers`）**：逗号分隔有几个模型，就会并发派出**几个**子代理；列表越短，开销越低。
- **`arena cross-judge pool`**：`arena` 在评选最佳基底时，会从池里挑一个**与当前主模型不同厂商**的模型做盲评裁判（`inherit-parent`/`auto` 不会当裁判）。
- **Codex 提示**：若你只希望 Codex 使用特定几个已验证的路由模型，可以在文件顶部加注释约束（如禁止回退到未授权模型别名，且 `model` 与 `reasoning_effort` 分开传递）。

---

## 四、主引擎 `/poteto-mode` 与 23 个内置 Playbook 全解析

### 1. `/poteto-mode` 开启后会强制发生什么？
1. **首条回复先复述对齐**：用自己的话复述你的目标、解决的问题、以及预计最小的改动范围，但不傻等确认（除非遇到不可逆操作）。
2. **匹配 Playbook 并建 Todo List**：从 23 个 Playbook 中挑出最匹配的一个，把它的步骤逐条照抄进 Todo List；跳过任何步骤都必须注明 `skip: <原因>`。
3. **先定数据结构再写代码**：强制先思考数据模型/状态机/查表结构（`principle-model-the-domain`），禁止一上来堆 `if/else`。
4. **先实验不瞎问**：凡是能靠跑个小原型、跑一条命令观察出答案的问题，绝不甩给人类做选择题；只把纯粹的产品偏好/取舍留给人拍板。
5. **不可逆操作必停顿**：对共享分支 force-push、线上发布、删库/删数据、给外部用户发消息前必须暂停确认；本地可逆操作与只读检查直接推进。
6. **必须拿实证结项**：绝不允许以“编译通过 / 改完了”结项，必须贴出真实运行命令、复现对比或检查结果，并标注每条结论的来源（实测 `measured` / 推断 `inferred` / 猜测 `guess`）。

### 2. 23 个内置 Playbook 完整对照

#### A. 研发与架构类
| Playbook | 何时触发 | 核心流程与硬要求 |
| :--- | :--- | :--- |
| **Investigation** | 只读提问：这是怎么工作的、为什么这样写、该选 A 还是 B | 全程不改业务代码，追踪源码、git 历史与运行态，给出带 `file:line` 引用的严谨结论 |
| **Bug fix** | 报告了 Defect / 异常行为 | ① 在真实表面先复现 ② 二分法排因找第一现场根因（可配 `/why`） ③ 跨函数则先 `architect` 再改 ④ 原表面复测通过 ⑤ 若有低成本测试则先补失败测试再补修复提交 ⑥ 开 PR 附复现前后输出 |
| **Feature** | 新增或修改功能行为 | ① 追踪影响子系统 ② `architect` 定接口/数据形状 ③ 写 4 维吞吐检查点（阻塞前置/独立并行流/共享可变状态拆分/最小安全拆解） ④ 委派子代理实现（多方案时自动转 `arena`） ⑤ 真实验证 ⑥ 按可验证小单元整理提交 ⑦ 有争议则 `interrogate` ⑧ 开 PR |
| **Refactoring** | 保持行为不变的结构整理 | 先记录/固化改动前的真实输出基准，再做抽取、合并、去重或搬移，最后证明外部行为字节级/语义级不变 |
| **Prototype** | UI 交互、布局或技术路线摇摆不定 | 禁止开空洞的抽象评审，快速搭 2–3 个可运行/可截图的抛弃型原型，用真实观测结果帮你拍板 |
| **Visual parity** | 像素级 UI 还原或样式系统迁移 | 逐项对齐两套实现的渲染结果与间距 token，留存对比截图 |
| **Multi-phase plan** | 跨阶段改造或叠层 PR 规划 | 只输出分阶段/叠层 PR 拆解计划，每步附明确验证门禁，**不提前写实现代码** |

#### B. 性能与取证类
| Playbook | 何时触发 | 核心流程与硬要求 |
| :--- | :--- | :--- |
| **Perf issue** | 某个具体操作慢，需一次性排查提速 | 先在固定 fixture 上量基准，Profile/Trace 定位真实瓶颈，修复后用 `benchmark-checklist` 核验前后对比 |
| **Hillclimb** | 持续科学调优某个单一指标（如评分、延迟、命中率） | 循环“提假设 → 改一处 → 测前后对比 → 记入 TSV 日志 → 仅胜出改动保留一次 commit” |
| **Runtime forensics** | 内存泄漏、CPU 空转、偶发卡顿等在线症状排查 | 在运行态插桩取证，**只输出根因诊断报告，不直接混改业务代码** |
| **Trace forensics** | 手头已有离线文件（`cpuprofile`、`trace`、`heap snapshot`、`spindump`） | 针对已捕获的离线档案做深度热点与调用链诊断 |

#### C. 自动化、长任务与大型项目类
| Playbook | 何时触发 | 核心流程与硬要求 |
| :--- | :--- | :--- |
| **Autonomous run** | 明确带有结束条件的单任务长跑（`"run until done"`） | 围绕可自动判定 PASS/FAIL 的断言循环推进，期间保留决策日志，直至达标或卡死退出 |
| **Orchestrate** | 跨多天、几十个子代理、多叠层 PR 的大型工程总控 | 由主会话担任协调者，拆解多个 PR 队列并统筹并发子代理，最小化人类介入轮次 |
| **Autopilot-full** | 一批彼此独立的 PR 任务队列（全自动合并） | 每个 PR 分配独立 Owner 从开发跑到绿灯，根协调者独立复验每个 PR 后允许 Owner 自动合并 |
| **Autopilot-stack** | 同上，但构建的是彼此依赖的叠层 PR（不自动合并） | 全自动开发、压栈与独立复验，最后把整条干净绿灯 PR 栈交给你亲自合并 |
| **Session pickup** | 接手别人/前一个会话做到一半的分支或任务 | 先读工作区、git 分支、决策日志与最近会话，确认已完成项绝不返工，接着往下跑 |
| **Pause safely** | 临近上下文压缩、重启或临时中断前安全存档 | 整理未提交改动、当前假设、下一步清单与恢复指令，确保下一棒零损耗接手 |

#### D. PR 交付与仓库维护类
| Playbook | 何时触发 | 核心流程与硬要求 |
| :--- | :--- | :--- |
| **Babysit** | `"babysit this pr"` / `"check on pr 123"` | 盯紧 PR 直到可合并：处理合并冲突、逐条核实 Review/Bugbot 评论（区分真 Bug 与误报，不盲目迎合）、修绿 CI；**未明确要求不自动 merge** |
| **Shipping** | `"land the stack"` | 独立复验绿灯 PR 并非假绿，然后按依赖栈从底向上逐个安全合并 |
| **Opening a PR** | 其他开发类 Playbook 的收尾阶段 | 清理注释与 AI 套话，拆分干净有序提交，在 PR `## Why` 写明用户目标与验证实证 |
| **Worktree cleanup** | 磁盘告急或废弃 worktree 堆积 | 安全排查并清理已合并/废弃的 git worktree 和过期模拟器，释放本地磁盘 |
| **Authoring a skill** | 编写或修改某个 `SKILL.md` | 按 Agent Skills 规范编写/精简，确保 frontmatter 与触发边界清晰 |
| **Eval** | 改完 Skill/Prompt 想先盲测效果 | 构造对照测试评估改动是否真的改善了 Agent 行为 |

---

## 五、独立 Skills 分类详解与实战用例

> **依赖提醒（已对齐 0.15.43）**：新版中 `how`、`why`、`architect` 均已可独立安装使用（`architect` 仅在需要大型多方案竞速时联动 `arena`）。

### 1. 代码理解、问题对齐与汇报类

#### `/how` — 搞清“现在怎么跑的”
- **适用**：改陌生模块前梳理调用链、状态归属，或纠结“新代码应该放哪个目录/哪一层”。
- **用例**：
  ```text
  /how 梳理一下这个项目里文件树刷新和 git status 轮询是怎么联动的？新加一个防抖逻辑应该放哪一层？
  ```

#### `/why` — 搞清“当年为什么要这样写”
- **适用**：看到奇怪的阈值、兼容分支、魔数或历史写法，不敢贸然删改时。
- **用例**：
  ```text
  /why 为什么这里要把目录读取并发限制在 8 个，而不是全量并发？查一下提交历史和相关文档。
  ```

#### `/teach` — 用通俗的话讲透一个改动或模块（依赖 `how`、`why`）
- **用例**：
  ```text
  /teach 给我讲清楚这次 PR 为什么选了方案 A 而不是方案 B，各自权衡了什么，用大白话和示例说明。
  ```

#### `/in-your-own-words` — 动工前校验 AI 有没有理解错你的意思
- **适用**：你刚贴了一大段复杂背景或需求，怕它会错意直接写偏。
- **用例**：
  ```text
  /in-your-own-words <粘贴你的长需求或排查背景>
  ```

#### `/recall` — 跨会话快速找回近期工作上下文
- **适用**：隔了几天重新打开项目，忘了自己上次改到哪、踩过什么坑。
- **用例**：
  ```text
  /recall 帮我回顾一下我最近在这个仓库做顶部 Tab 样式优化和缓存清理的进展与遗留问题。
  ```

#### `/ketchup` 与 `/ketchup-video` — 当前长会话快速追进度
- **适用**：AI 在当前会话里跑了半天（或子代理刚汇报完一堆），你想一眼看清“自上次我说话以来改了啥、现在哪几件事等我拍板”。
- **用例**：
  ```text
  /ketchup
  ```
  *(需要幻灯片带字幕短视频版本时用 `/ketchup-video`。)*

#### `/bro` — 黑话翻译机
- **适用**：AI 上一条回复太学术、太啰嗦或满屏内部名词时。
- **用例**：
  ```text
  /bro
  ```

---

### 2. 需求加深、架构设计与多方案竞速类

#### `/sharpen` — 只帮你重写提示词，不直接干活
- **原理**：在重写前先回答 4 个专业问题：① 顶级专家还会额外做什么你没提的事 ② 应该从哪份最原始的材料而不是二手摘要出发 ③ 具体用什么方法/工具 ④ 除了你和我之外靠什么客观证据证明做对了——最后吐出一段可直接发送的高质量 Prompt。
- **用例**：
  ```text
  /sharpen 我想给这个 Node 服务加一个令牌桶限流中间件，防止高并发打爆数据库。
  ```

#### `/architect` — 先画清骨架与边界再写代码（大型争议设计会自动转 `arena`）
- **原理**：在写代码前追踪改动触及的所有子系统，草拟两种不同的形状（类型定义、函数签名、模块边界），选出“每份状态只有一个 Owner、每件事只有一种做法、调用方需要知道最少”的方案后再落地。
- **用例**：
  ```text
  /architect 给这个仓库设计一套统一的插件配置校验与热重载机制。先列出两种结构对比，等我确认方案后再写实现。
  ```

#### `/arena` — 多模型/多候选赛马 + 盲评嫁接
- **6 阶段流**：Frame（定产物与 3-6 条可评分 Rubric）→ Fan out（并发在独立 worktree 生成 N 份实现）→ Cross-judge（挑不同厂商模型做盲评裁判）→ Pick a base（逐项按 Rubric 选基底）→ Graft（把落选方案里最精华的 1-2 点手工融合进基底）→ Verify（整体验证）。
- **用例**：
  ```text
  /arena 为离线同步引擎设计冲突解决策略模块，并发跑 3 个候选方案，按可测试性、幂等性和代码简洁度评分选出最佳基底并融合亮点。
  ```

#### `/figure-it-out` — 定制无现成模板的大工程审计方案
- **适用**：跨几十个文件的全面迁移、没有标准模板的复杂改造。
- **用例**：
  ```text
  /figure-it-out 帮我制定并执行把仓库里所有遗留回调风格异步接口迁到 async/await 的可审计方案，要求每迁移一批都有回归验证。
  ```

---

### 3. 编码、并行扫描与测试类

#### `/swarm` — 扇出 N 个并发 Worker，全部回收汇总成一张表
- **适用**：对几十个子模块批量跑检查、并发复现偶发竞态、多角度代码巡检。
- **用例**：
  ```text
  /swarm 检查 mods/ 目录下每一个插件的 check*.cjs 脚本与图标引用是否齐全。每个目录一个 worker，汇总成一张状态表，标出所有失败项与报错。
  ```

#### `/tdd` — 精准节制的测试驱动开发
- **特点**：不盲目教条 TDD——只有当你明确要求 TDD/回归测试，或 Bug 有明确低成本的本地单测路径时才先写失败测试再修；若是强依赖真实集成环境的 UI/并发问题，会老实跳过并走真实表面复现。
- **用例**：
  ```text
  /tdd 修复日期解析器在 UTC-5 时区跨午夜时少算一天的问题。先写失败单测再修复。
  ```

#### `/typescript-best-practices` — TypeScript 严格类型指南
- **用例**：
  ```text
  用 /typescript-best-practices 审查 src/core/session.ts，收紧松散类型并消除不必要的 any 和类型断言。
  ```

#### `/make-bot-ui` — 构建 Webhook / Tailscale 控制面板
- **用例**：
  ```text
  /make-bot-ui 做一个简洁的状态看板页面，点击按钮能通过 webhook 唤醒本地部署机器人。
  ```

---

### 4. 对抗审查、影响面证明、文档清理与形式化验证

#### `/interrogate` — 专门找茬的“对抗式代码审查”
- **硬规则**：**只保留能用实际命令/测试/脚本跑出失败实证的问题**，不准提代码风格、命名偏好等口水 Nitpick；且绝不自动改你的代码，只出实锤报告（包含 `Findings` 和被毙掉的 `Dropped` 列表）。
- **用例**：
  ```text
  /interrogate 严厉审查当前分支相对 main 的所有改动。不要改任何文件，只列出你能用真实脚本或测试跑出故障的 Bug 或回退问题。
  ```

#### `/blast-radius` — 查“Grep 搜不到”的隐蔽破坏面（依赖 `arena`、`how`、`why`、`unslop`）
- **核心理念**：列出调用点 `grep` 一秒就能搜到，没价值；真正的爆炸半径在于**第三方库源码行为、微任务/卸载时序、API JSON 契约、跨语言字节流、Feature Flag 或三跳之外的下游逻辑**。它要求找出支撑这次改动安全的“核心一件事”，并写一段真跑真实代码的脚本来证明它（证明等级 1~5，必须尽量打到第 4 级“跑起来”或第 5 级“真应用复现”）。
- **用例**：
  ```text
  /blast-radius 分析一下把缓存清理间隔从 60 秒改成 5 秒、并在失焦时取消 watchFolder 可能会破坏哪些上游或边界场景，用真实运行脚本证明核心安全前提成立。
  ```

#### `/no-comments` — 注释洁癖清理
- **原理**：派出一个“没写这段代码的审查者（Comment Sicko）”，把所有“复述代码在干嘛”的废话注释和分阶段注释（如 `// Phase 1: ...`）清理干净，只留下真正解释非显而易见原因（`why`）或外部限制的注释。
- **用例**：
  ```text
  /no-comments 清理当前分支改动里的多余注释。
  ```

#### `/unslop` & `/technical-writing` — 文档与文案去 AI 味
- **`/unslop`**：砍掉“值得一提的是”“综上所述”和滥用破折号等 AI 套话。
- **`/technical-writing`**：按 Diátaxis 架构（教程/操作指南/参考/解释）+ Google 开发者文档风格重写 README、RFC、PR 描述。
- **用例**：
  ```text
  /technical-writing 审校 docs/architecture.md，补充快速上手和 API 参考部分，再过一遍 /unslop。
  ```

#### `/benchmark-checklist` — 性能数字防造假清单
- **适用**：任何时候报告“提速 3 倍”“内存降了 40%”之前，强制核查限流器、冷热缓存、异常静默失败、样本量、可复现性以及工作是不是其实根本没执行（dead-code / skipped work）。
- **用例**：
  ```text
  /benchmark-checklist 核验一下我们刚测出来的“文件树加载提速 4 倍”这个数据是不是真实可靠。
  ```

#### `/create-verification-skill` — 为项目生成真实端到端驱动验证 Skill
- **做法**：自动摸清当前项目的启动命令、操作表面（Web/CDP、Electron、CLI/PTY、HTTP API）、健康检查（Doctor）和孤立环境能力，生成 `<skills>/verify-<app>/SKILL.md` 及核心功能地图（`features/*.md`），**并在交付前亲自端到端跑通一遍、留存截图/日志证据且保证清理不误删证据**。
- **用例**：
  ```text
  /create-verification-skill 给当前项目生成一个本地端到端验证 skill，能够自动启动应用、操作核心流程并截图留证，最后干净清理临时进程。
  ```

#### `/create-formal-verification-skill` & `/statechart` — 为高危并发/状态机上形式化验证
- **适用**：重试幂等、并发抢锁、状态机流转、资金/订单等“普通单测很难覆蓋到所有交错顺序”的代码。
- **`/create-formal-verification-skill`**：自动选型（并发/交错顺序默认 TLA+），写出紧贴真实代码的模型，**并故意往真实代码注入一个破坏（scratch change）确认模型真能抓住 Bug 后再撤回**。
- **`/statechart`**：运行 TLA+ 模型检查并画成直观的 Mermaid 状态图，给出任何违规不变量的最短触发路径（已在镜像版修复 Windows 兼容问题，不依赖 `/bin/sh`）。
- **用例**：
  ```text
  /create-formal-verification-skill 证明这个分布式任务租约模块在 worker 崩溃重启和心跳延迟交错时，绝对不会出现两个 worker 同时持有同一租约。
  ```
  ```text
  /statechart 检查支付退款状态机的 TLA+ 模型并输出 Mermaid 状态图和异常最短路径。
  ```

---

### 5. 留痕、配置与向导类

#### `/show-me-your-work` — 无人值守决策日志（TSV）
- **做法**：在项目里维护一个只追加（append-only）的 `decisions.tsv`（或 `.audit/<slug>.tsv`），记录每次关键分支决策：`ts`、`phase`、`decision`（人话描述）、`why`、`evidence`（commit/文件路径/截图路径）、`result`；并在收尾时**对照真实会话记录审计 TSV 有没有撒谎或漏证**。
- **用例**：
  ```text
  /show-me-your-work 帮我汇总一下昨晚长任务到底做了哪些关键决策，先指出需要我关注的异常或取舍。
  ```

#### `/poteto-help` — 随时不知道用啥就问它
- **用例**：
  ```text
  /poteto-help 我想在不改代码的前提下检查一个 PR 合进去会不会搞坏异步清理逻辑，该用哪个 skill？给我直接可用的提示词。
  ```

---

## 六、自进化与防呆闭环实战攻略

`pstack` 把“越用越顺手、越用越少犯错”拆成了三个不同层次的闭环：

### 1. `/reflect` — 任务收尾复盘，进化 Skill 本身
- **什么时候用**：一个比较曲折的任务刚做完，中间你纠正过 AI 几次，或者它自己摸索出一条很管用的命令。
- **流程**：读取当前工作区本次会话完整记录 → 过滤掉一次性信息（版本号、SHA） → 输出 **Accepted（问题 / 提案 / 目标 Skill）**、**Rejected** 和 **Backlog** → **等你点头确认后才动文件**。
- **实用口令**：
  ```text
  /reflect 复盘这次会话我们踩过的坑和我的纠正，只保留半年后依然有价值的经验并给出修改提案。
  ```

### 2. `/correct` — 仓库被连续纠正时，从架构/类型/Lint 上彻底堵死
- **核心哲学**：“假设下一个来改代码的 Agent 只打开了一个文件、照着最近的例子抄、只要能编译就提交”。
- **处理优先级（从高到低，能用高层绝不用底层文档凑数）**：
  1. **架构消除**：收口成单一所有权 / 单一入口，删掉容易抄错的旧接口；
  2. **类型系统**：让非法状态根本写不出来；
  3. **带修复提示的 Lint / CI**：报错信息里直接写明“请改用哪个文件/函数”；
  4. **行为测试**：删改一处真实逻辑时测试必挂；
  5. **文档与 `AGENTS.md`（最后兜底）**：仅保留无法靠代码强约束的判断规则，并维护一张“规则 ↔ 强制检查手段”对照表。
- **实用口令**：
  ```text
  /correct Agent 在这个仓库里总是忘记修改 shared/*.js 后同步到各模块并跑 check。分析历史提交并把这个错误从机制上堵死，且用真实旧错误证明新检查能拦住它。
  ```

### 3. `/automate-me` — 从你的历史习惯里提炼专属 `*-mode`
- **做法**：跨近 2–4 周的多个历史会话切片并发挖掘你稳定复现的偏好（出现 2 次以上才采信，防止过拟合），再用 1–2 轮选择题和你对齐边界，最终生成 `<你的名字>-mode/SKILL.md`；以后重跑只需基于 `git log` 增量更新。
- **实用口令**：
  ```text
  /automate-me 扫描我在这个项目最近几周的会话记录，提炼出我的编码风格、中文回复要求和验收习惯，帮我生成一个个人专属的 mode skill。
  ```

> **⚠️ 在本机软链环境下的重要提醒**：
> 挂载了 `pstack` 的项目里，`.agents/skills/*` 指向 `D:\Projects\pstack\skills\*`。
> - **跨所有项目都适用的经验**（如通用的提问、验证方法改进），可以让 `/reflect` 改写 `D:\Projects\pstack` 里的对应 Skill；
> - **某个特定项目独有的规范和坑**，请务必让 `/correct` 写入该项目的 `AGENTS.md` / Lint / CI 或新建项目专属 Skill，避免污染通用的 `pstack` 仓库！

---

## 七、24 个工程原则（`principle-*`）速查与纠偏口令

平时不用手动 `/principle-xxx`，而是在 `/poteto-mode` 下直接点名原则名称纠偏（AI 会立刻重读该原则全文并说明它改了哪个决定）：

| 分类 | 原则英文名 | 一句话含义 | 实战纠偏怎么喊 |
| :--- | :--- | :--- | :--- |
| **Core** | `laziness-protocol` | 偏向删代码与最小改动，拒绝多余抽象层 | `Apply laziness-protocol. Keep the smallest change and drop extra abstractions.` |
| **Core** | `foundational-thinking` | 动工前先想清核心数据结构与并发共享边界 | `Apply foundational-thinking. Define the data structure first.` |
| **Core** | `redesign-from-first-principles` | 接新需求按第一性原理重构，不打歪补丁 | `Apply redesign-from-first-principles instead of patching.` |
| **Core** | `attack-the-premise` | 同一前提下连续修错两次，立刻质疑并验证该前提 | `Apply attack-the-premise. Write down and test our assumption directly.` |
| **Core** | `subtract-before-you-add` | 重构/新增前先删死代码、废校验和桩引用 | `Apply subtract-before-you-add before adding new code.` |
| **Core** | `minimize-reader-load` | 合并单调用方包装层，缩小可变作用域 | `Apply minimize-reader-load. Collapse unnecessary wrapper layers.` |
| **Core** | `outcome-oriented-execution` | 分阶段大迁移直接收敛到终态，不留过渡兼容层 | `Apply outcome-oriented-execution.` |
| **Core** | `experience-first` | 产品/UX 权衡时优先用户体验，不图开发省事 | `Apply experience-first.` |
| **Core** | `exhaust-the-design-space` | 无先例新设计先做 2–3 个竞品原型横评 | `Apply exhaust-the-design-space. Build 2 prototypes to compare.` |
| **Core** | `build-the-lever` | 批量改动/校验先写可重跑脚本，不纯手工改 | `Apply build-the-lever. Write a reusable script instead of manual edits.` |
| **Arch** | `model-the-domain` | 用状态机/类型/查表替代散落 `if/else` 分支 | `Apply model-the-domain. Replace scattered flags with a state table.` |
| **Arch** | `boundary-discipline` | 校验集中在系统边缘，内部逻辑保持纯粹 | `Apply boundary-discipline.` |
| **Arch** | `type-system-discipline` | 让非法状态在类型上无法表达 | `Apply type-system-discipline.` |
| **Arch** | `make-operations-idempotent` | 生命周期/命令设计成崩溃重试也收敛到同一终态 | `Apply make-operations-idempotent.` |
| **Arch** | `migrate-callers-then-delete-legacy-apis` | 同一波次迁完旧调用方并立即删掉旧 API | `Apply migrate-callers-then-delete-legacy-apis.` |
| **Arch** | `separate-before-serializing-shared-state` | 并发冲突优先拆分文件/目录隔离，其次才加锁 | `Apply separate-before-serializing-shared-state.` |
| **Verify** | `prove-it-works` | **最常用**：拿真实运行/落盘/截图说话，编译不算数 | `Apply prove-it-works. Show me real runtime output, not just build passed.` |
| **Verify** | `fix-root-causes` | 顺症状追到第一出错源头去修，不靠防御性吞错掩盖 | `Apply fix-root-causes. Trace back to the origin instead of guarding the symptom.` |
| **Verify** | `sequence-verifiable-units` | 每一步改完都能独立验证再进下一步和提交 | `Apply sequence-verifiable-units.` |
| **Verify** | `test-behavior-not-implementation` | 测外部可观测行为，不锁死私有实现细节 | `Apply test-behavior-not-implementation.` |
| **Verify** | `explain-the-number` | 报任何性能数字前先找瓶颈上限并排除测偏 | `Apply explain-the-number before reporting metrics.` |
| **Deleg** | `guard-the-context-window` | 大文件/长日志扫描丢给子代理，主线程只留摘要 | `Apply guard-the-context-window. Offload raw logs to a subagent.` |
| **Deleg** | `never-block-on-the-human` | 可逆操作先干了拿结果给人看，别每步都问 | `Apply never-block-on-the-human for reversible steps.` |
| **Meta** | `encode-lessons-in-structure` | 同样的嘱咐说第二遍就写成 Lint/脚本/类型约束 | `Apply encode-lessons-in-structure.` |

---

## 八、5 个完整端到端实战剧本

### 剧本 1：接手陌生模块并安全开发新功能
1. 先搞懂现状：`"/how 梳理这个模块的数据流与状态生命周期"`
2. 查清历史顾虑：`"/why 为什么这里把缓存上限设成 200 且用了手动轮询？"`
3. 动手前定架构：`"/architect 我要给它加上增量同步能力。先给出类型和模块边界方案让我确认。"`
4. 正式开工：`"/poteto-mode 按刚才确认的设计实现增量同步。保持原有导出结果完全一致，并跑真实场景验证。"`
5. 合并前找茬：`"/interrogate 审查当前分支，只报告能用实际运行证明的 Bug。"` + `"/no-comments"`

### 剧本 2：修一个时好时坏的线上 / 本地疑难 Bug
```text
/poteto-mode 文件在外部被删除后文件树有时 10 秒都不刷新。
先用真实操作复现出来，再用二分排因定位根本原因并修复，最后给出修复前后的对比运行输出。用中文汇报。
```
*(若怀疑改完可能殃及别处，收尾前补一句：`/blast-radius 分析这次监听取消改动对其他页面的影响，用脚本证明安全。`)*

### 剧本 3：睡前 / 离开工位挂长任务，第二天一键验收
**离开前发送：**
```text
/poteto-mode 我要离开电脑几个小时。请在基于 main 新建的 git worktree 里完成 <目标描述>。
完成标准是 `<验证命令，如 npm test && npm run build>` 全部通过。
用 /show-me-your-work 维护决策日志。可逆提交不用问我确认。
如果连续尝试几轮依然卡住，请停下来并在总结里写明卡在哪以及已经排除了什么。
```
**回来后验收：**
```text
/show-me-your-work 先看 Attention 部分，给我汇报昨晚做了哪些关键决策和最终校验输出。
```
*(如果还是没看明白长对话进展，发 `/ketchup`。)*

### 剧本 4：发现 Agent 老在同一个项目犯同样的低级错
1. 立即纠正并固化到仓库防线：
   ```text
   /correct Agent 在这个仓库里总是忘记运行同步脚本就提交。查出最近两次犯错的提交，优先从架构、Lint 或测试检查层面堵死，并用过去犯错的状态验证新检查能拦住它。
   ```
2. 如果是工作流程顺不顺手的问题，用 `/reflect` 调整 Skill 描述或步骤。

### 剧本 5：给重点项目加装“真实驱动 + 形式化校验”双重护城河
1. 生成真实应用控制与回归 Skill：
   ```text
   /create-verification-skill 给当前 Web/CLI 应用生成一个 verify-app skill，要求能独立启动实例、走完登录到核心操作并保留证据。
   ```
2. 对最核心的并发/状态流转模块加形式化校验：
   ```text
   /create-formal-verification-skill 为任务队列抢锁与重试幂等逻辑建立 TLA+ 模型验证，并故意注入一次错误验证模型能抓到它。
   ```

---

## 九、常见排障 FAQ

| 现象 | 原因 | 解决办法 |
| :--- | :--- | :--- |
| **输入自然语言后 Skill 没触发** | 大部分 `pstack` Skill 设了 `disable-model-invocation: true` | 改用明确 `/skill-name + 中文内容` 触发，或先 `/poteto-mode` 开启模式 |
| **跑了几轮之后 `/poteto-mode` 失效了** | 单次会话或跨任务切换导致上下文稀释 | 每个新大任务开头重新显式带一次 `/poteto-mode`；换话题时写 `New task: ...` |
| **改完 `/setup-pstack` 模型没生效** | 既有会话可能缓存了旧配置，或未读项目级 `.agents/pstack-models.md` | 新开一个会话窗口，确认项目根目录下存在 `.agents/pstack-models.md` |
| **多线程并发修改互相覆盖代码** | 多个 subagent 写同一个工作区目录 | 在 Prompt 明确要求每个写代码的子代理使用独立 `git worktree` |
| **Agent 汇报“改好了、编译通过”但其实没跑通** | 未触发真实端到端验证 | 直接回复：`Apply prove-it-works. Run the real flow and show me the actual output.` |
| **过夜长任务空转烧 Token 没成果** | 只写了“跑 2 小时 / 优化一下”，没有可判定的完成条件 | 必须给出明确 PASS/FAIL 命令或断言作为完成标准，并限定最大尝试后退出 |
| **子代理报模型名不认识** | 该工具不支持 `.agents/pstack-models.md` 里的默认 Claude/Gemini slug | 重跑 `/setup-pstack` 检测本机真实可用模型，或将对应角色设为 `inherit-parent` / `auto` |
