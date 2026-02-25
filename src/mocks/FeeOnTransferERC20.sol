// SPDX-License-Identifier: MIT
/**
 * @title FeeOnTransferERC20
 * @notice
 * @dev 断言点（测试里）
        balanceOf(to) 增量 < amount
        fee 被 burn：totalSupply 减少 / 或 collector 收到 fee
        totalFeeTaken 累计正确
 */
pragma solidity ^0.8.23;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FeeOnTransferERC20 is ERC20 {
    uint16 public feeBps; // e.g. 100 = 1%
    address public collector; // if 0, burn
    uint256 public totalFeeTaken; // easy assert hook

    error FeeTooHigh();

    constructor(
        string memory name_,
        string memory symbol_,
        uint16 feeBps_,
        address collector_
    ) ERC20(name_, symbol_) {
        _setFee(feeBps_, collector_);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setFee(uint16 feeBps_, address collector_) external {
        _setFee(feeBps_, collector_);
    }

    function _setFee(uint16 feeBps_, address collector_) internal {
        if (feeBps_ > 2000) revert FeeTooHigh(); // cap 20% for sanity
        feeBps = feeBps_;
        collector = collector_;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        // 只对普通转账收手续费（不对 mint/burn 收）
        if (from != address(0) && to != address(0) && feeBps != 0) {
            uint256 fee = (value * feeBps) / 10_000;
            uint256 remain = value - fee;

            // 先把 fee 转给 collector
            if (fee != 0) {
                super._update(from, collector, fee);
            }
            // 再把剩余转给 to
            super._update(from, to, remain);
            return;
        }

        // mint/burn 或不收手续费：走原逻辑
        super._update(from, to, value);
    }
}
