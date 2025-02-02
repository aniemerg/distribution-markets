// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/DistributionMath.sol";
import "./MarketPosition.sol";
import "./interfaces/IDistributionMarket.sol";

contract DistributionMarket is ERC20, IDistributionMarket {
    IERC20 public immutable token;
    MarketPosition public immutable positionNFT;
    
    bool public initialized;
    bool public settled;
    int256 public finalValue;
    
    int256 public currentMean;
    uint256 public currentStdDev;
    uint256 public currentK;
    uint256 public totalBacking;
    
    mapping(uint256 => Position) private positions;

    constructor(
        address _token,
        address _positionNFT
    ) ERC20("Market LP Token", "MLP") {
        token = IERC20(_token);
        positionNFT = MarketPosition(_positionNFT);
    }

    function initializeMarket(
        int256 initialMean,
        uint256 initialStdDev,
        uint256 initialBacking,
        uint256 initialK
    ) external returns (uint256) {
        require(!initialized, "Market already initialized");
        
        // Transfer tokens to market
        require(token.transferFrom(msg.sender, address(this), initialBacking), 
                "Token transfer failed");
        
        // Mint LP tokens
        _mint(msg.sender, initialBacking);
        
        // Create position NFT
        uint256 positionId = positionNFT.mint(msg.sender);
        
        // Store position data
        positions[positionId] = Position({
            mean: initialMean,
            stdDev: initialStdDev,
            k: initialK,
            collateral: initialBacking,
            isLp: true,
            oldMean: 0,
            oldStdDev: 0,
            settled: false
        });
        
        // Set market state
        currentMean = initialMean;
        currentStdDev = initialStdDev;
        currentK = initialK;
        totalBacking = initialBacking;
        initialized = true;
        
        emit MarketInitialized(positionId, initialMean, initialStdDev, initialBacking);
        
        return positionId;
    }

    function trade(
        int256 newMean,
        uint256 newStdDev,
        uint256 maxCollateral
    ) external returns (uint256) {
        require(initialized, "Market not initialized");
        require(!settled, "Market already settled");
        
        // Calculate minimum allowed std dev and verify
        uint256 minStdDev = DistributionMath.calculateMinimumSigma(currentK, totalBacking);
        require(newStdDev >= minStdDev, "Standard deviation too low");

        // Calculate required collateral
        uint256 requiredCollateral = DistributionMath.calculateRequiredCollateral(
            currentMean,
            currentStdDev,
            newMean,
            newStdDev,
            currentK,
            newMean  // Using newMean as hint for calculation
        );

        require(requiredCollateral <= maxCollateral, "Insufficient collateral");
        
        // Transfer collateral to market
        require(token.transferFrom(msg.sender, address(this), requiredCollateral),
                "Token transfer failed");

        // Create position NFT
        uint256 positionId = positionNFT.mint(msg.sender);
        
        // Store position data
        positions[positionId] = Position({
            mean: newMean,
            stdDev: newStdDev,
            k: currentK,
            collateral: requiredCollateral,
            isLp: false,
            oldMean: currentMean,
            oldStdDev: currentStdDev,
            settled: false
        });
        
        // Update market state
        currentMean = newMean;
        currentStdDev = newStdDev;
        
        emit Trade(positionId, msg.sender, newMean, newStdDev, requiredCollateral);
        
        return positionId;
    }

    function addLiquidity(uint256 backingAmount) external returns (uint256) {
        require(initialized, "Market not initialized");
        require(!settled, "Market already settled");
        
        // Transfer backing to market
        require(token.transferFrom(msg.sender, address(this), backingAmount), 
                "Token transfer failed");
        
        // Calculate new k based on backing ratio
        uint256 oldBacking = totalBacking;
        totalBacking += backingAmount;
        uint256 oldK = currentK;
        // new k = old k * (new backing / old backing)
        currentK = (oldK * totalBacking) / oldBacking;
        
        // Mint LP tokens proportional to backing share
        // new LP tokens = total LP supply * (new backing / old backing)
        uint256 newLpTokens = (totalSupply() * backingAmount) / oldBacking;
        _mint(msg.sender, newLpTokens);
        
        // Create position NFT
        uint256 positionId = positionNFT.mint(msg.sender);
        
        // Create trader position at current market position
        uint256 newK = currentK - oldK;
        positions[positionId] = Position({
            mean: currentMean,
            stdDev: currentStdDev,
            k: newK,
            collateral: backingAmount,
            isLp: true,
            oldMean: 0,
            oldStdDev: 0,
            settled: false
        });
        
        emit LiquidityAdded(positionId, msg.sender, backingAmount);
        
        return positionId;
    }

    function getPosition(uint256 positionId) external view returns (
        int256 mean,
        uint256 stdDev,
        uint256 k,
        uint256 collateral,
        bool isLp
    ) {
        Position storage pos = positions[positionId];
        return (pos.mean, pos.stdDev, pos.k, pos.collateral, pos.isLp);
    }

    function settleMarket(int256 _finalValue) external {
        require(initialized, "Market not initialized");
        require(!settled, "Market already settled");
        
        finalValue = _finalValue;
        settled = true;
        
        emit MarketSettled(_finalValue);
    }

    function settlePosition(uint256 positionId) external {
        require(settled, "Market not settled");
        
        Position storage pos = positions[positionId];
        require(!pos.settled, "Position already settled");
        require(positionNFT.ownerOf(positionId) == msg.sender, "Not position owner");
        
        uint256 payout;
        if (pos.isLp) {
            payout = DistributionMath.calculateF(
                finalValue,
                pos.mean,
                pos.stdDev,
                pos.k
            );
        } else {
            uint256 finalPayout = DistributionMath.calculateF(
                finalValue,
                pos.mean,
                pos.stdDev,
                pos.k
            );
            uint256 initialPayout = DistributionMath.calculateF(
                finalValue,
                pos.oldMean,
                pos.oldStdDev,
                pos.k
            );
            
            if (finalPayout >= initialPayout) {
                payout = finalPayout - initialPayout;
            } else {
                payout = initialPayout - finalPayout;
            }
            payout += pos.collateral;
        }
        
        pos.settled = true;
        require(token.transfer(msg.sender, payout), "Token transfer failed");
        
        emit PositionSettled(positionId, payout);
    }

    function settleLpTokens(address lpHolder) external {
        require(settled, "Market not settled");
        
        uint256 lpBalance = balanceOf(lpHolder);
        require(lpBalance > 0, "No LP tokens");
        
        uint256 totalSupply = totalSupply();
        uint256 remainingFunds = totalBacking;
        
        // Calculate remaining funds after subtracting final distribution
        uint256 finalDist = DistributionMath.calculateF(
            finalValue,
            currentMean,
            currentStdDev,
            currentK
        );
        
        if (finalDist <= remainingFunds) {
            remainingFunds -= finalDist;
        } else {
            remainingFunds = 0;
        }
        
        // Calculate proportional payout
        uint256 payout = (lpBalance * remainingFunds) / totalSupply;
        
        // Burn LP tokens and transfer payout
        _burn(lpHolder, lpBalance);
        require(token.transfer(lpHolder, payout), "Token transfer failed");
    }
}