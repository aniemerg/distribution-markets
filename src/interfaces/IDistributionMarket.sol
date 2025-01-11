// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDistributionMarket {
    /// Custom errors
    error MarketAlreadyInitialized();
    error MarketNotInitialized();
    error MarketAlreadySettled();
    error InsufficientCollateral();
    error StandardDeviationTooLow();
    error Unauthorized();
    error PositionNotFound();
    error PositionAlreadySettled();

    /// Events
    event MarketInitialized(
        uint256 indexed positionId,
        address indexed lp,
        int256 initialMean,
        uint256 initialStdDev,
        uint256 backing
    );

    event Trade(
        uint256 indexed positionId,
        address indexed trader,
        int256 newMean,
        uint256 newStdDev,
        uint256 collateral
    );

    event LiquidityAdded(
        uint256 indexed positionId,
        address indexed lp,
        uint256 backingAmount
    );

    event MarketSettled(int256 finalValue);

    event PositionSettled(
        uint256 indexed positionId,
        address indexed recipient,
        uint256 payout
    );

    /// Functions
    function initializeMarket(
        int256 initialMean,
        uint256 initialStdDev,
        uint256 initialBacking,
        uint256 initialK
    ) external returns (uint256 positionId);

    function addLiquidity(uint256 backingAmount) 
        external returns (uint256 positionId);

    function trade(
        int256 newMean,
        uint256 newStdDev,
        uint256 maxCollateral
    ) external returns (uint256 positionId, uint256 requiredCollateral);

    function settleMarket(int256 finalValue) external;

    function settlePosition(uint256 positionId) external returns (uint256 payout);

    function settleLPPosition(address lp) external returns (uint256 payout);

    // View functions
    function getPosition(uint256 positionId) 
        external view returns (
            address owner,
            int256 mean,
            uint256 stdDev,
            uint256 k,
            uint256 collateral,
            bool isLP,
            bool settled
        );

    function getCurrentMarketPrice() external view returns (int256 mean, uint256 stdDev);
    
    function getTotalBacking() external view returns (uint256);
    
    function isInitialized() external view returns (bool);
    
    function isSettled() external view returns (bool);
}