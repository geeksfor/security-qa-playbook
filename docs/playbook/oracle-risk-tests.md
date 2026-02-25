# Oracle 风险矩阵（测试用例 → 断言指标）

> 目标：把 “oracle 风险” 从概念落到**可回归**的测试：**过期 / 跳变 / 操纵 / 偏离限制 / circuit breaker**。  
> 建议与本周代码配套使用：`MockOracle(updatedAt)`、`SimpleLending(LTV/HF/清算)`、`MockAMMXYK(spot)`。

---

## 1. 统一约定（强烈建议写死到模板里）

### 1.1 单位与精度
- **价格 `price`**：建议统一为 `WAD = 1e18`（USD per collateral token）
- **债务 `debtUsd`**：`WAD`
- **抵押 `collateral`**：如用 ERC20 真实 decimals，请在上层做换算；本周最小例子可直接假设抵押也按 `WAD`

### 1.2 风控参数（Risk Params）
- `maxOracleAge`：允许的最大“价格年龄”（秒）
- `ltv`：最大借款比例（WAD）
- `liqThreshold`：清算阈值（WAD）
- `liquidationBonus`：清算奖励（WAD）
- `maxDeviationBps`：允许 spot 相对参考价的最大偏离（bps，`10000=100%`）
- `circuitBreakerMode`：触发后策略（revert / freeze / sentinel）

### 1.3 核心公式（便于断言）
- 抵押价值（USD）  
  `collateralValueUsd = collateralAmount * price / 1e18`
- 最大可借（USD）  
  `maxBorrowUsd = collateralValueUsd * ltv / 1e18`
- 健康因子 HF（WAD）  
  `HF = collateralValueUsd * liqThreshold / debtUsd`（若 `debtUsd=0`，视为 `∞`）
- 清算可行条件  
  `HF < 1e18`（**严格小于**）

---

## 2. 风险矩阵（Risk → 用例 → 断言指标）

> 表格中的 “推荐测试文件路径” 对应你训练营第 3 周的产物目录建议：  
> - `test/templates/Oracle.staleness.spec.t.sol`  
> - `test/examples/lending/Lending.liquidation.boundary.t.sol`  
> - `test/examples/lending/SpotManipulation.vsProtection.t.sol`

### 2.1 Matrix（总表）

| 风险类型 | 如何模拟 | 上层期望行为（策略） | 关键断言指标 | 推荐测试用例名（示例） |
|---|---|---|---|---|
| **Stale / 过期** | `vm.warp()` + `setPriceWithTime(updatedAt)` | **拒绝**：revert 或 sentinel(false) | revert selector / `ok=false` | `stale_reverts_strict` / `stale_returns_false_sentinel` |
| **Jump / 跳变** | `oracle.setPrice(newPrice)` 瞬间变化 | 允许但应触发风控：借款上限变化；或启用偏离限制 | `maxBorrow`、HF 变化；事件 | `price_jump_changes_maxBorrow` / `jump_triggers_breaker` |
| **Spot Manip / 现价操纵** | AMM swap 改 reserve → spot 价格偏离 | 脆弱版可被打穿；修复版（TWAP/偏离限制）不可 | `borrow` 成功/失败；偏离检查触发 | `vuln_spot_overborrow_succeeds` / `fixed_deviation_reverts` |
| **Oracle Outlier / 异常值** | 价格=0、负值、极大值 | **拒绝**：InvalidPrice / 进入 breaker | revert；状态不变 | `invalid_price_reverts` |
| **Deviation Limit / 偏离限制** | spot vs ref 偏离刚好边界（±1 bps） | 边界正确：≤阈值通过，>阈值拒绝 | `DeviationTooHigh` 是否触发 | `deviation_just_within_ok` / `deviation_just_over_reverts` |
| **Circuit Breaker / 熔断** | 连续异常/偏离超限/price jump | 触发后：冻结借款/清算/仅允许还款（按策略） | breaker 状态位；允许/禁止动作 | `breaker_freezes_borrow_allows_repay` |
| **Oracle Latency / 更新延迟** | `updatedAt` 很旧但 price 未变 | 同 stale：拒绝或降级 | 同 stale | `updatedAt_old_reverts` |
| **HF Boundary / 清算边界** | 通过改 price 让 HF == 1 或 <1 | HF==1 **不能清算**；HF<1 **能清算** | `NotLiquidatable` / 状态变化公式 | `hf_eq_1_cannot_liquidate` / `hf_just_below_can_liquidate` |

---

## 3. 详细用例清单（可直接照抄成测试）

### O1 — Stale Strict（过期必须 revert）
- **前置**：`maxOracleAge = 1h`
- **步骤**  
  1) `oracle.setPriceWithTime(p, t0)`  
  2) `vm.warp(t0 + maxOracleAge + 1)`  
  3) 调用 `readPriceStrict()` 或 `lending.borrowUsd()`（内部读价）
- **期望**：revert `StaleOracle(updatedAt, nowTs)` / `StalePrice(...)`
- **断言**：错误 selector + 参数匹配；状态不变（debt/collateral）

### O2 — Stale Sentinel（过期返回 ok=false）
- **步骤**：同 O1，但调用 `readPriceSentinel()`
- **期望**：`ok == false`，上层把该价判为无效（不用于借款/清算）

### O3 — Price Jump（跳变引起借款上限变化）
- **步骤**  
  1) deposit 抵押  
  2) 记录 `maxBorrowUsd`（price=p1）  
  3) `oracle.setPrice(p2)`（p2 != p1）  
  4) 再读 `maxBorrowUsd`
- **期望**：`maxBorrowUsd` 随价格单调变化（p2>p1 → maxBorrow 增）
- **断言**：`maxBorrow2 > maxBorrow1`（或反向）

### O4 — Invalid Price（0/负值必须拒绝）
- **步骤**：`oracle.setPriceWithTime(0 or -1, now)`，调用读价路径
- **期望**：revert `InvalidPrice()`
- **断言**：revert；状态不变

### O5 — HF Boundary（清算边界回归）
- **步骤**  
  1) 构造 `debt = collateralValueUsd * liqThreshold` → HF==1  
  2) `liquidate()` 应 revert  
  3) `debt += 1` → HF<1  
  4) `liquidate()` 成功并断言状态变化
- **断言**  
  - HF==1：`NotLiquidatable(hf)`  
  - HF<1：`debt` 减少 `repayUsd`；`collateral` 减少 `seized`；`seized` 符合公式

### O6 — Spot Manipulation（脆弱版可被打穿）
- **前置**：lending 直接用 `amm.spotPrice()` 作为价格
- **步骤**  
  1) 攻击者 deposit 抵押  
  2) swap 操纵 spot 上升  
  3) 借款额度显著上升并成功借出
- **断言**：`spotMaxBorrow > refMaxBorrow`；借款成功

### O7 — Deviation Limit（修复：偏离超阈值必须拒绝）
- **前置**：有 `refOracle` 与 `maxDeviationBps`
- **步骤**  
  1) 初始 spot≈ref  
  2) 操纵 spot，使偏离 > 阈值（例如 5%+）  
  3) borrow / readPrice 使用保护模式
- **期望**：revert `DeviationTooHigh(spot, ref)`
- **断言**：revert；debt 不变

### O8 — Deviation Boundary（±1 bps 边界）
- **步骤**  
  1) 设 `maxDeviationBps = D`  
  2) 构造 spot 与 ref：偏离 = D bps（应通过）  
  3) 再构造偏离 = D+1 bps（应拒绝）
- **断言**  
  - `bps == D`：不 revert  
  - `bps == D+1`：revert

### O9 — Circuit Breaker（熔断状态机）
- **建议最小策略**  
  - breaker 激活后：**禁止 borrow**，允许 repay（降低风险）  
  - 或者：全部 revert（最简单）
- **断言**：breaker 状态位变化；动作许可符合策略；事件可选

---

## 4. 推荐断言指标（团队落地时最常用）

### 4.1 价格有效性（Oracle Quality Gates）
- `updatedAt`：`now <= updatedAt + maxOracleAge`
- `price > 0`
- （可选）`answeredInRound` / `roundId` 单调（如果接 Chainlink）

### 4.2 风控联动（Risk Linkage）
- `maxBorrowUsd` 对价格变化方向一致
- `HF` 边界：`HF == 1e18` 不清算，`HF < 1e18` 可清算
- 清算后守恒/变化：  
  - `debtAfter = debtBefore - repay`  
  - `collateralAfter = collateralBefore - seized`  
  - `seized ≈ repay*(1+bonus)/price`（必要时允许舍入误差）

### 4.3 抗操纵（Anti-Manipulation）
- spot-only 的版本必须有“能被打穿”的测试（教育 & 回归）
- 修复版必须有“同流程必失败”的测试（不可回归破坏）

---

## 5. 最小目录建议（与训练营产物一致）

```
src/
  mocks/
    MockOracle.sol
    MockAMMXYK.sol
  examples/
    lending/
      SimpleLending.sol
      SpotBasedLending.sol        (对照演示用，可选)

test/
  templates/
    Oracle.staleness.spec.t.sol
  examples/
    lending/
      Lending.liquidation.boundary.t.sol
      SpotManipulation.vsProtection.t.sol

docs/
  checklists/
    oracle-risk-tests.md          (本文)
```

---

## 6. 一句话“团队落地”建议
- **所有读取 oracle 的入口**（borrow/withdraw/liquidate/healthFactor）统一走 `readPriceStrict()` 或统一的 `OracleAdapter`，避免有人绕过 staleness/invalid checks。
- **每个协议必须至少有 1 条**：`spot 可被操纵` 的对照用例 + `修复后不可被操纵` 的回归用例。
- **阈值类参数**（maxAge/maxDeviation）必须覆盖 `==阈值` 与 `>阈值` 的边界回归（±1）。

