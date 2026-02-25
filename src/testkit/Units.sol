// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @notice Minimal unit helpers for tests. Keep it small & explicit.
library Units {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;

    enum Rounding {
        Down,
        Up
    }

    function pow10(uint8 n) internal pure returns (uint256) {
        // n <= 77 fits in uint256 for 10**n, typical decimals <= 18
        uint256 r = 1;
        for (uint8 i = 0; i < n; i++) r *= 10;
        return r;
    }

    /// @notice Scale `amount` from `fromDecimals` to `toDecimals` with rounding.
    /// 不同 token decimals 的统一（比如把 USDC 6 位换到 18 位做计算）
    /// 价格、利率、份额 share 计算时统一精度
    /// 在缩小精度时，通过 Rounding.Up/Down 控制偏向：
    /// Down：更保守（不会多给用户）
    /// Up：更保守（不会少收费用/不会少扣债务等，具体看语义）
    function scaleAmount(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals,
        Rounding rounding
    ) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) return amount;
        if (fromDecimals < toDecimals) {
            uint256 factor = pow10(toDecimals - fromDecimals);
            return amount * factor;
        } else {
            uint256 factor = pow10(fromDecimals - toDecimals);
            if (rounding == Rounding.Down) return amount / factor;
            // Up: (a + f - 1) / f
            return (amount + factor - 1) / factor;
        }
    }

    /// 在 DeFi 里经常把 18 位精度当作统一的“内部计算精度”，1 WAD = 1e18
    function toWad(
        uint256 amount,
        uint8 decimals_,
        Rounding rounding
    ) internal pure returns (uint256) {
        return scaleAmount(amount, decimals_, 18, rounding);
    }

    /// 由wad换算为真实的token数量
    function fromWad(
        uint256 wadAmount,
        uint8 decimals_,
        Rounding rounding
    ) internal pure returns (uint256) {
        return scaleAmount(wadAmount, 18, decimals_, rounding);
    }

    /// wadMul 主要用来做 18 位定点数（WAD，1e18）之间的乘法：把两个“带 18 位小数的数”相乘后，再除回 1e18，
    /// 保持结果仍是 WAD 精度，并按需要 向下/向上舍入
    function wadMul(
        uint256 a,
        uint256 b,
        Rounding rounding
    ) internal pure returns (uint256) {
        // (a*b)/WAD with rounding
        if (a == 0 || b == 0) return 0;
        uint256 prod = a * b;
        if (rounding == Rounding.Down) return prod / WAD;
        return (prod + WAD - 1) / WAD;
    }

    /// wadDiv 主要用来做 18 位定点数（WAD=1e18）的除法
    function wadDiv(
        uint256 a,
        uint256 b,
        Rounding rounding
    ) internal pure returns (uint256) {
        require(b != 0, "DIV_BY_ZERO");
        // (a*WAD)/b with rounding
        uint256 num = a * WAD;
        if (rounding == Rounding.Down) return num / b;
        return (num + b - 1) / b;
    }
}
