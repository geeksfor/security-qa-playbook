# Solidity 语法复习笔记（围绕 BaseTest / Asserts）

> 面向 Foundry 测试工程化：把你在 `BaseTest.t.sol` 与断言工具 `assertApproxRelBps` 里遇到的 Solidity 语法点集中整理，便于随时查阅。

---

## 1. 合约与继承：`abstract contract BaseTest is Test`

### 1.1 `contract`
- Solidity 的基本组织单元：状态变量 + 函数 + 事件 + 错误等。

### 1.2 `abstract`
- **抽象合约**：通常作为“基类/模板”使用，强调“用来被继承复用”。
- 抽象合约可以不包含抽象函数；加 `abstract` 主要是表达意图：这是基建，不是业务合约。

### 1.3 `is Test`（继承）
- `is` 表示继承（单继承/多继承）。
- 在 Foundry 中通常继承 `forge-std/Test.sol` 的 `Test`，获得：
  - `assertEq / assertTrue / assertLe ...` 断言
  - `vm` cheatcodes（如 `vm.prank / vm.warp / vm.expectRevert` 等）
  - 便捷函数（如 `makeAddr`）

---

## 2. 状态变量声明：`address internal alice;`

### 2.1 `address`
- 以太坊地址类型（20 bytes），用于账户或合约地址。

### 2.2 可见性 `internal`
- `internal`：本合约 + 子合约可访问（非常适合“测试基类角色账户”）。
- 对比：
  - `private`：仅本合约可访问（子类拿不到，不适合复用）
  - `public`：自动生成 getter（测试里通常不需要暴露接口）

---

## 3. 函数声明：`function setUp() public virtual { ... }`

### 3.1 `setUp()`（Foundry 约定）
- 这是 **Foundry 的测试约定**：每条测试执行前会自动调用 `setUp()`。
- 不是 Solidity 语言内置关键字，但在 Foundry 测试体系里非常重要。

### 3.2 可见性 `public`
- `public`：外部/内部都可调用。
- 测试运行器需要能调用 `setUp()`，因此常用 `public`。

### 3.3 `virtual` / `override`
- `virtual`：允许子类重写该函数。
- 子类写法：
  ```solidity
  function setUp() public override {
      super.setUp();
      // 子类扩展部署与初始化
  }
  ```
- `super.setUp()`：先执行父类初始化，再做子类扩展。

---

## 4. 赋值与三元表达式

### 4.1 赋值 `=`
- 把右侧表达式的值写入左侧变量（如角色地址）。

### 4.2 三元表达式 `cond ? x : y`
- 用于在一行内写条件选择。
- 例：
  ```solidity
  uint256 hi = a > b ? a : b;
  uint256 lo = a > b ? b : a;
  ```
- 常用于避免 `if/else` 冗余，且可保证 `hi >= lo`，便于计算差值不发生 underflow。

---

## 5. 字符串与“数据位置”（data location）

你遇到的报错：
> Data location must be "storage", "memory" or "calldata" for parameter in function, but none was given

这涉及 Solidity 的关键语法规则：

### 5.1 值类型 vs 引用类型
- **值类型（按值拷贝）**：`uint256`, `address`, `bool`, `bytes32` 等  
  ✅ 作为函数参数时 **不需要**写数据位置。
- **引用类型（指向一段数据）**：`string`, `bytes`, 动态数组 `T[]`, `struct`, `mapping`  
  ✅ 作为函数参数/返回值时 **必须显式**写数据位置：`memory` / `calldata` / `storage`。

### 5.2 `memory / calldata / storage` 含义
- `memory`：函数执行期间的临时内存，执行结束即释放（可读可写，常用于 internal 工具函数）。
- `calldata`：外部调用输入数据区，只读（**最省 gas**，适合 `external` 参数）。
- `storage`：链上持久化状态（合约状态变量所在地）。

### 5.3 为什么 `string err` 必须写 `memory`
- `string` 是引用类型，所以必须标明数据位置：
  ```solidity
  string memory err
  ```
- 你的断言函数是 `internal`，通常使用 `memory` 最通用、最少踩坑。
- 另外 forge-std 的断言接口也常以 `string memory` 形式接收错误信息。

### 5.4 为什么 “外部函数参数不能用 storage”
- `storage` 引用的是“合约自己的链上状态变量位置”。
- 外部调用的参数来自交易输入（calldata），外部不可能传入“指向你合约 storage 某个槽位的引用”。  
  因此 `external/public` 的参数只能是 `calldata` 或拷贝后的 `memory`。

---

## 6. `calldata` 为什么省 gas

核心原因：**不拷贝大块数据**。

- 外部调用的动态参数（`string/bytes/数组`）原本就在 calldata。
- 如果参数写 `calldata`：函数直接读取输入数据（只读视图），几乎不需要拷贝。
- 如果参数写 `memory`：需要把 calldata 数据拷贝到内存，开销与数据长度线性相关。

推荐实践：
- `external` 函数参数：优先 `calldata`
- `internal` 工具函数参数：通常 `memory`

---

## 7. `assertApproxRelBps`：相对误差断言（bps）

### 7.1 bps 是什么？为什么有 10000？
- bps = basis points（基点）
- 1 bps = 0.01%
- 100 bps = 1%
- 10,000 bps = 100%

所以允许误差比例为：
\[ allow = \frac{maxRelBps}{10000} \]

### 7.2 断言的数学含义
目标条件：
\[ \frac{|a-b|}{\max(a,b)} \le \frac{maxRelBps}{10000} \]

代码中为了避免 Solidity 整数除法的精度损失，把除法改为交叉相乘：
\[ |a-b| \cdot 10000 \le \max(a,b) \cdot maxRelBps \]

### 7.3 关键代码结构（逐段）
```solidity
function assertApproxRelBps(uint256 a, uint256 b, uint256 maxRelBps, string memory err) internal {
    if (a == b) return;

    uint256 hi = a > b ? a : b;
    uint256 lo = a > b ? b : a;

    uint256 diff = hi - lo;
    assertLe(diff * 10_000, hi * maxRelBps, err);
}
```

- `hi/lo`：确保 `hi >= lo`，避免 underflow。
- `diff`：等价于 `|a-b|`。
- `* 10_000`：把 bps 换算到比例尺度。
- `assertLe`：来自 `Test` 的断言，失败会打印 `err`。

---

## 8. 测试环境相关（Foundry 特有，但写 Solidity 测试必会）

### 8.1 `makeAddr("alice")`
- `forge-std/Test` 提供的 helper：按字符串生成可复现地址，方便角色管理。

### 8.2 `vm.label(address, "NAME")`
- 给地址打标签，trace 里可读性大幅提升。
- 只影响调试输出，不影响链上逻辑。

---

## 9. 快速记忆口诀

- **值类型**：不用写 data location  
- **引用类型**：必须写 `memory / calldata / storage`  
- `external` 参数：优先 `calldata`（省 gas，只读）  
- `internal` 工具函数：常用 `memory`（通用可写）  
- bps：**10000 = 100%**（1% = 100 bps）  
- 相对误差：尽量用 “交叉相乘” 避免整数除法精度坑

---

## 10. 你可以怎么用这份笔记
- 写测试基类时：优先 `internal` 角色变量 + `virtual setUp()`
- 写工具断言时：引用类型参数记得 data location；误差类断言优先 bps 与交叉相乘
- 写 `external` 接口时：动态参数优先 `calldata`

