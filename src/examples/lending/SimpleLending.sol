// SPDX-License-Identifier: MIT
/**
 * **断言点：**价格变化 → 借款上限变化；HF 边界正确

    这里给你一个最小但够风控用的借贷：

    抵押物：collateralToken（数量）

    债务：按 USD 计价（WAD 1e18）

    Oracle：给出 collateral 的 USD 价格（WAD 1e18）

    风控：LTV 决定最大可借，liqThreshold 决定 HF

    你当天做什么（步骤）

    写内部单位：全部用 1e18（WAD）

    抵押价值 collateralValueUsd = collateralAmount * price / 1e18

    最大可借 maxBorrowUsd = collateralValueUsd * LTV / 1e18

    HF = collateralValueUsd * liqThreshold / debtUsd（debt=0 时视为无穷大）

    borrow() 要校验 oracle staleness + debtUsd <= maxBorrowUsd

    你当天能学到什么

    风控参数（LTV、liqThreshold、HF）如何真正落到可测公式

    价格变化如何传导到“借款上限 / 清算触发”
 *
 *
 */
pragma solidity ^0.8.20;

import {MockOracle} from "src/mocks/MockOracle.sol";

contract SimpleLending {
    uint256 public constant WAD = 1e18;

    MockOracle public oracle;

    // risk params (WAD): 0.75e18 = 75%
    uint256 public immutable ltv;
    uint256 public immutable liqThreshold;
    uint256 public immutable maxOracleAge; // seconds
    uint256 public immutable liquidationBonus; // WAD, e.g. 0.05e18 = 5%

    mapping(address => uint256) public collateral; // in collateral token units (WAD assumed)
    mapping(address => uint256) public debtUsd; // USD debt in WAD

    error StaleOracle(uint256 updatedAt, uint256 nowTs);
    error InvalidPrice();
    error ExceedsBorrowLimit(uint256 wantDebtUsd, uint256 maxDebtUsd);
    error NotLiquidatable(uint256 hfWad);
    error TooMuchRepay();

    constructor(
        MockOracle _oracle,
        uint256 _ltv,
        uint256 _liqThreshold,
        uint256 _maxOracleAge,
        uint256 _liquidationBonus
    ) {
        oracle = _oracle;
        ltv = _ltv;
        liqThreshold = _liqThreshold;
        maxOracleAge = _maxOracleAge;
        liquidationBonus = _liquidationBonus;
    }

    function depositCollateral(uint256 amount) external {
        // minimal: assume collateral token transfer handled elsewhere; we just account it
        collateral[msg.sender] += amount;
    }

    function _readPriceWad() internal view returns (uint256 priceWad) {
        (int256 p, uint256 u) = oracle.getPrice();
        if (block.timestamp > u + maxOracleAge)
            revert StaleOracle(u, block.timestamp);
        if (p <= 0) revert InvalidPrice();
        priceWad = uint256(p); // assume oracle returns WAD already
    }

    function collateralValueUsd(address user) public view returns (uint256) {
        uint256 price = _readPriceWad();
        return (collateral[user] * price) / WAD;
    }

    function maxBorrowUsd(address user) public view returns (uint256) {
        return (collateralValueUsd(user) * ltv) / WAD;
    }

    /// 健康因子healthFactor > 1：通常表示安全（抵押品按阈值折算后仍覆盖债务）
    function healthFactorWad(address user) public view returns (uint256) {
        uint256 d = debtUsd[user];
        if (d == 0) return type(uint256).max;
        return (collateralValueUsd(user) * liqThreshold) / d;
    }

    function borrowUsd(uint256 amountUsdWad) external {
        uint256 newDebt = debtUsd[msg.sender] + amountUsdWad;
        uint256 maxDebt = maxBorrowUsd(msg.sender);
        if (newDebt > maxDebt) revert ExceedsBorrowLimit(newDebt, maxDebt);
        debtUsd[msg.sender] = newDebt;
    }

    // Minimal liquidation: liquidator repays debtUsd and seizes collateral with bonus
    function liquidate(
        address user,
        uint256 repayUsdWad
    ) external returns (uint256 seizedCollateral) {
        uint256 hf = healthFactorWad(user);
        if (hf >= WAD) revert NotLiquidatable(hf);

        uint256 d = debtUsd[user];
        if (repayUsdWad > d) revert TooMuchRepay();

        uint256 price = _readPriceWad();
        // collateral to seize = repay * (1 + bonus) / price
        uint256 repayWithBonus = (repayUsdWad * (WAD + liquidationBonus)) / WAD;
        seizedCollateral = (repayWithBonus * WAD) / price;

        // cap seize to user's collateral
        if (seizedCollateral > collateral[user])
            seizedCollateral = collateral[user];

        debtUsd[user] = d - repayUsdWad;
        collateral[user] -= seizedCollateral;
    }
}
