# Debugging & Trace Playbook（失败怎么查）

> 目标：让团队在 **Foundry/Forge** 下，能快速把一次失败定位到“最小复现”，并沉淀为可回归的测试。

---

## 1) 先把失败缩小到最小复现

### 只跑一个合约
```bash
forge test --match-contract <ContractName> -vvv
```

### 只跑一个用例
```bash
forge test --match-test <test_name> -vvv
```

### 组合过滤（最常用）
```bash
forge test --match-path test/integration/D4_Fixtures_Smoke.t.sol --match-test test_fixture_supply_matches_balances -vvv
```

> **原则**：能用一条用例复现，就不要跑全量。定位效率会指数提升。

---

## 2) 提高可观测性：用 `-v` 系列看 trace

Foundry 的 `-v` 越多，输出越详细：

- `-v`：简略
- `-vv`：更详细
- `-vvv`：**最常用**（call trace + revert 原因）
- `-vvvv`：超详细（输出会很大，一般不必）

示例：
```bash
forge test --match-test test_fixture_supply_matches_balances -vvv
```

---

## 3) 用日志打印中间值（最直接）

Foundry `forge-std/Test.sol` 提供了很多日志事件，你可以在测试里直接：

### 打印数字 / 地址 / bytes32
```solidity
emit log_named_uint("x", x);
emit log_named_int("delta", delta);
emit log_named_address("user", user);
emit log_named_bytes32("id", id);
emit log_named_string("stage", "after swap");
```

### 打印更复杂结构：拆分打印
把结构体/数组拆成关键字段分别打印（不要一次打印大数组，trace 会很难看）。

---

## 4) 正确使用 `expectRevert / expectEmit`（把失败变成“可解释”）

### 断言 Revert（字符串/自定义错误）
```solidity
vm.expectRevert("BALANCE");
token.transfer(bob, 1e18);
```

自定义错误更推荐：
```solidity
vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", attacker));
target.adminOnly();
```

### 断言事件（事件是“协议承诺”）
```solidity
vm.expectEmit(true, true, false, true);
emit Transfer(alice, bob, 100);
token.transfer(bob, 100);
```

> 审计/安全视角：**事件是链上可追踪承诺**，测试里最好把关键事件也纳入断言。

---

## 5) 常用定位套路（从快到慢）

### Step 1：先看 Revert 原因
- 是 `require("xxx")`？还是 `custom error`？
- `Error != expected error` 常见于你 `expectRevert` 的编码不匹配。

### Step 2：看调用栈（谁调用谁）
- trace 里从上到下就是调用链
- 找到第一个 revert 点，回到对应函数看输入参数/状态

### Step 3：打印关键变量（输入/状态/余额）
典型安全测试关键点：
- `balanceOf / totalSupply`
- `reserve / price / oracle`
- `nonce / deadline / processed[messageId]`
- `role / owner / admin`

### Step 4：把随机/模糊因素固定（让复现稳定）
- 时间：`vm.warp(ts)`
- 区块：`vm.roll(blockNumber)`
- 调用者：`vm.prank(user)` / `vm.startPrank(user)`
- 资金：`vm.deal(user, ethAmount)`

---

## 6) “最小复现”的落地模板（推荐拷贝）

当你发现一个失败或安全风险，建议按这个结构立刻最小化：

1. `setUp()`：只保留必要合约/依赖（fixtures）
2. `test_...()`：只做一条路径，**先写失败断言**（红）
3. 修复后：断言升级为回归（绿）
4. 最后补：边界 case（0 / 极小 / 极大）

---

## 7) Fork 场景的定位（只读验证优先）

### 常用：指定 RPC 与区块高度
```solidity
uint256 forkId = vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19_000_000);
```

定位建议：
- 先做 **readonly assertions**（读状态 + 断言不变量）
- 再加极少量交互（避免 fork 上执行成本/状态复杂）

---

## 8) 把“失败”沉淀成“回归门禁”

修复后至少满足其一（越多越好）：
- ✅ 状态不变：余额、supply、nonce、processed 等
- ✅ 错误一致：`expectRevert` 精确匹配
- ✅ 事件一致：`expectEmit`
- ✅ 边界一致：0/极小/极大
- ✅ invariant：长期不变量（可选）

---

## 9) 常见坑速查

- **编译器版本不一致**：VS Code 插件报错但 `forge test` 绿 → 以 Foundry 为准，关闭插件 as-you-type 编译
- `Error != expected error`：自定义错误编码不对（签名/参数/顺序）
- `call to non-contract address 0x0`：handler/fixture 地址没部署或没初始化
- 断言失败但差一点：需要用 `assertApproxAbs/Rel`，并解释容忍度来源

---

## 10) 推荐命令合集（复制即用）

```bash
# 1) 单测最小化
forge test --match-test <test_name> -vvv

# 2) 合约级筛选
forge test --match-contract <ContractName> -vvv

# 3) 文件级筛选
forge test --match-path test/unit/*.t.sol -vvv

# 4) 失败后反复跑同一条（快速迭代）
forge test --match-test <test_name> -vvv
```

---

**建议**：团队约定“每次修 bug 必须补回归测试”，并把这个文档挂到 `docs/playbook/`，配合 `scripts/ci.sh` 做门禁。
