// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDistributionMarket {
    struct Position {
        int256 mean;
        uint256 stdDev;
        uint256 k;
        uint256 collateral;
        bool isLp;
        // For non-LP positions
        int256 oldMean;
        uint256 oldStdDev;
        bool settled;
    }

    event MarketInitialized(
        uint256 indexed positionId,
        int256 initialMean,
        uint256 initialStdDev,
        uint256 initialBacking
    );
    
    event MarketSettled(int256 finalValue);
    
    event PositionSettled(
        uint256 indexed positionId,
        uint256 payout
    );
}