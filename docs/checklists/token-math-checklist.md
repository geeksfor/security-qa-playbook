# Token Math Checklist (decimals / WAD-RAY / rounding / special tokens)

> 目的：把“单位换算 / 舍入 / 特殊 Token 行为”变成**可执行的审计与测试清单**，减少团队最常见的数学与会计翻车。

---

## 1. Units & Decimals（单位与精度）

### 1.1 明确所有数值的“单位”
- [ ] 每个变量都能回答：它是 **token base unit**（最小单位）还是 **WAD(1e18)** 还是 **RAY(1e27)**？
- [ ] 在 README / docs / 注释中标清：例如 `amount` 是 `assetDecimals`，`price` 是 WAD 或 RAY。

### 1.2 统一换算入口（不要散落魔法数）
- [ ] `decimals ↔ WAD ↔ RAY` 换算必须走统一 helper（例如 `Units.scaleAmount/toWad/fromWad`）
- [ ] 禁止散落 `* 1e18`、`/ 1e27` 这类“看起来对但经常错”的魔法数
- [ ] 对外部 token 的 `decimals()` 读取要考虑：缓存/可变/异常（少数 token 可能 revert）

### 1.3 Round-trip（来回换算不“变多”）
- [ ] `x -> toWad -> fromWad`：**不应凭空变大**（通常允许向下舍入导致的轻微损失）
- [ ] Round-trip 的最大误差（dust）需要定义并写进断言（例如 `<= 1` 个最小单位）

### 1.4 乘除顺序与溢出
- [ ] 对表达式 `a * b / c`：检查是否可能溢出；能用 `mulDiv` 就用 `mulDiv`
- [ ] 若必须手写：先除后乘（等价变形）是否改变舍入方向？（非常常见翻车点）
- [ ] 对 `uint256` 上界估算：`a`、`b` 可能来自用户输入、外部价格、累计值

---

## 2. Rounding Rules（舍入规则与一致性）

### 2.1 明确每个公式的舍入方向
- [ ] 每个关键转换都要写明：**Rounding.Down** 还是 **Rounding.Up**
- [ ] 对协议安全：通常更偏向 **“对用户不利但对协议安全”** 的方向（例如向下取整防止超发）
- [ ] 但如果向下会造成“用户永远取不干净资产”或“长期累计吃亏”，要有 dust 处理策略

### 2.2 ERC4626/份额会计一致性
- [ ] `deposit` vs `mint`：同等经济含义下 shares/asset 结果应一致（允许极小误差）
- [ ] `withdraw` vs `redeem`：同等经济含义下 assets/share 结果应一致（允许极小误差）
- [ ] `convertToShares` / `convertToAssets`：两边必须使用**同一套 rounding policy**
- [ ] “预览函数” `previewDeposit/previewMint/...` 与实际行为一致（否则前端/聚合器会踩坑）

### 2.3 小额边界（最容易被套利）
- [ ] 最小资产单位（1 wei）/ 最小 share：行为是否合理？
- [ ] 当 `totalSupply==0` 或 `totalAssets==0` 的初始化路径是否特殊处理正确？
- [ ] 极端比例：池子里资产很大、shares 很小，或反过来（会触发精度灾难）

### 2.4 循环套利回归（必须有）
- [ ] 写“攻击者小额循环存取”回归测试：攻击者净资产 **不应上升**
- [ ] 若允许极小的可解释误差：给出上限（例如最多 +1 wei 或 0）
- [ ] 测试维度：不同 `loops`、不同初始化比例（seed liquidity）、不同 decimals

---

## 3. Fee-on-Transfer / Deflationary Tokens（通缩/转账扣费）

> 特征：`transfer(amount)` 之后接收方实际到账 `< amount`。  
> 风险：协议用“期望入账 amount”做会计，会导致 share 定价、TVL、抵押率、清算阈值等全错。

### 3.1 会计入账必须基于真实到账
- [ ] 所有“入账”逻辑必须用 `balanceBefore/After` 计算 `received`
- [ ] 严禁 `totalAssets += amount` 这种“假入账”（除非你显式拒绝 fee-on-transfer）

### 3.2 明确 fee 去向
- [ ] fee 是 burn 还是 collector？（必须可观测、可审计）
- [ ] fee 可能动态变化（owner 可调）：是否有治理/权限风险？

### 3.3 是否支持此类 token（必须明确）
- [ ] 若不支持：显式 revert（例如 `require(received == amount)`）
- [ ] 若支持：所有 mint/share 计算必须基于 `received`，并写回归测试覆盖

---

## 4. Non-standard ERC20 behaviors（非标准 ERC20 行为）

### 4.1 返回值与 SafeERC20
- [ ] `transfer/transferFrom/approve` 不返回 bool 或返回 false 的老 token：必须用 `SafeERC20`
- [ ] 对“成功但不返回值”的 token：是否能兼容？

### 4.2 Approve 竞态（经典翻车）
- [ ] 演示用例：从 `oldAllowance` 改 `newAllowance`，spender 抢跑可花掉两次
- [ ] 防护建议：`approve(0)` 再 `approve(new)` 或使用 `increaseAllowance/decreaseAllowance`

### 4.3 可暂停/黑名单/税收白名单等
- [ ] `paused/blacklist` 可能导致协议 DoS（用户无法取回、清算无法执行）
- [ ] 税率对不同地址不同：协议账户是否被当成“高税地址”？

### 4.4 Rebasing（余额自动变化）
- [ ] rebasing 会让 `balanceOf` 自动涨/跌：TVL/totalAssets/抵押率会被动漂移
- [ ] 如果协议不支持：必须明确拒绝或隔离

---

## 5. Testkit Requirements（工程化落地要求）

### 5.1 Units 最小库必须存在且被复用
- [ ] `Units.scaleAmount/toWad/fromWad` 在测试中广泛使用
- [ ] Round-trip 测试覆盖多个 decimals（6、8、18 常见）

### 5.2 ERC20 spec 模板
- [ ] 标准行为：余额守恒、allowance 扣减、transferFrom 行为
- [ ] 非标准演示：approve 竞态复现用例 + 安全改法用例

### 5.3 ERC4626 rounding spec 模板
- [ ] 小额循环套利回归（攻击者净资产不应上升）
- [ ] deposit/mint 与 withdraw/redeem 一致性（允许误差但有上限）

### 5.4 Fee-on-transfer 作为 asset 的 spec
- [ ] 演示“会计失真”（OZ 基线 vault 直接跑一遍）
- [ ] 防护策略（拒绝 or 兼容）至少实现一种并写测试

---

## 6. Audit Quick Red Flags（审计快速红旗）

- [ ] 看到 `amount * 1e18 / x`：先查溢出、舍入方向、乘除顺序
- [ ] 看到 `totalAssets += amount`：先问“amount 真的到账了吗？”
- [ ] 看到 `convertToShares/convertToAssets`：两边 rounding policy 是否一致？
- [ ] 看到“支持任意 ERC20 作为 asset/collateral”：必须跑特殊 token spec（FOT / rebasing / blacklist）
- [ ] 看到“价格 or 比率”使用整数：必须检查精度尺度（WAD/RAY/decimals）是否统一

---

## 7. 最小推荐断言清单（可直接抄到用例里）

- [ ] **Round-trip**：`x -> wad -> x'`，断言 `x' <= x` 且 `x - x' <= dust`
- [ ] **ERC20 守恒（标准 token）**：`balA + balB` 转账前后不变
- [ ] **Allowance 扣减**：`transferFrom` 后 allowance 正确减少
- [ ] **Approve 竞态演示**：old + new 都可被 spender 花掉（演示用例）
- [ ] **ERC4626 一致性**：deposit/mint 与 withdraw/redeem 经济一致（误差上限）
- [ ] **循环套利回归**：攻击者净资产不应上升
- [ ] **FOT 入账**：`received < sent` 且 fee 去向清晰；vault 若不支持必须 revert

---

## 8. 建议的文件与命名（与你本周交付对齐）

- `docs/checklists/token-math.md`（本文件）
- `src/testkit/Units.sol`
- `src/mocks/FeeOnTransferERC20.sol`
- `test/templates/ERC20.spec.t.sol`
- `test/templates/ERC4626.rounding.spec.t.sol`
- `test/templates/ERC4626.feeOnTransfer.spec.t.sol`
