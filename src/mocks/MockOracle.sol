// SPDX-License-Identifier: MIT
/**
 * @title
 * @author
 * @notice
 * 定义一个最小 oracle 接口：latestRoundData() 或你自定义 getPrice()

    MockOracle 保存 price 与 updatedAt

    提供 setPrice(price)（自动更新 updatedAt）和 setPriceWithTime(price, updatedAt)（专门用来模拟 stale）

    写最小自检：读到的 price/updatedAt 符合预期

    你当天能学到什么

    Oracle 风控里“价格 + 时间戳”是最小闭环（staleness 的根）

    如何在测试中控制时间与数据源（让回归可重复）
 */
pragma solidity ^0.8.20;

contract MockOracle {
    int256 public price; // e.g. ETH/USD in 1e8 or 1e18, you decide
    uint256 public updatedAt; // unix timestamp

    event PriceUpdated(int256 price, uint256 updatedAt);

    constructor(int256 initialPrice, uint256 initialUpdatedAt) {
        price = initialPrice;
        updatedAt = initialUpdatedAt;
    }

    function setPrice(int256 newPrice) external {
        price = newPrice;
        updatedAt = block.timestamp;
        emit PriceUpdated(newPrice, updatedAt);
    }

    // For tests: simulate stale oracle by forcing updatedAt in the past
    function setPriceWithTime(int256 newPrice, uint256 newUpdatedAt) external {
        price = newPrice;
        updatedAt = newUpdatedAt;
        emit PriceUpdated(newPrice, updatedAt);
    }

    // Minimal read method (your lending will call this)
    function getPrice() external view returns (int256, uint256) {
        return (price, updatedAt);
    }
}
