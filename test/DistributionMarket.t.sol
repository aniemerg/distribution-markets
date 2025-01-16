// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/libraries/DistributionMath.sol";
import "../src/DistributionMarket.sol";
import "../src/MarketPosition.sol";

// Test ERC20 token for market collateral
contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract DistributionMarketTest is Test {
    TestToken public token;
    DistributionMarket public market;
    MarketPosition public positionNFT;
    
    // Common test values
    uint256 constant PRECISION = 1e18;
    // Allow for 0.1% difference in calculations
    uint256 constant EPSILON = PRECISION / 1000;
    
    // Test addresses
    address public constant LP_1 = address(0x1);
    address public constant LP_2 = address(0x2);
    address public constant TRADER_1 = address(0x3);
    
    // Initial market parameters (based on Python test values)
    int256 constant INITIAL_MEAN = 95e18;  // 95.0
    uint256 constant INITIAL_STD_DEV = 10e18;  // 10.0
    uint256 constant INITIAL_BACKING = 50e18;  // 50.0
    uint256 constant INITIAL_K = 210502603956905700000;  // ~210.5026
    
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

    event Trade(
        uint256 indexed positionId,
        address indexed trader,
        int256 newMean,
        uint256 newStdDev,
        uint256 collateral
    );
    
    function setUp() public {
        // Deploy test token
        token = new TestToken();
        
        // Deploy position NFT contract
        positionNFT = new MarketPosition();
        
        // Deploy market with both token and position NFT addresses
        market = new DistributionMarket(address(token), address(positionNFT));
        
        // Set market as the minter for position NFTs
        positionNFT.setMarket(address(market));
        
        // Setup initial LP
        token.mint(LP_1, INITIAL_BACKING);
        vm.startPrank(LP_1);
        token.approve(address(market), INITIAL_BACKING);
        vm.stopPrank();
    }

    function testInitializeMarket() public {
        // Check initial state
        assertEq(token.balanceOf(LP_1), INITIAL_BACKING);
        assertEq(token.balanceOf(address(market)), 0);
        assertEq(market.totalSupply(), 0);
        
        // Initialize market
        vm.startPrank(LP_1);
        vm.expectEmit(true, true, true, true);
        emit MarketInitialized(1, INITIAL_MEAN, INITIAL_STD_DEV, INITIAL_BACKING);
        
        uint256 positionId = market.initializeMarket(
            INITIAL_MEAN,
            INITIAL_STD_DEV,
            INITIAL_BACKING,
            INITIAL_K
        );
        vm.stopPrank();
        
        // Check token transfers
        assertEq(token.balanceOf(LP_1), 0);
        assertEq(token.balanceOf(address(market)), INITIAL_BACKING);
        
        // Check LP token minting
        assertEq(market.totalSupply(), INITIAL_BACKING);
        assertEq(market.balanceOf(LP_1), INITIAL_BACKING);
        
        // Check position NFT
        assertEq(positionNFT.ownerOf(positionId), LP_1);
        
        // Check position data
        (int256 mean, uint256 stdDev, uint256 k, , bool isLp) = market.getPosition(positionId);
        assertEq(mean, INITIAL_MEAN);
        assertEq(stdDev, INITIAL_STD_DEV);
        assertEq(k, INITIAL_K);
        assertTrue(isLp);
        
        // Check market parameters
        assertEq(market.currentMean(), INITIAL_MEAN);
        assertEq(market.currentStdDev(), INITIAL_STD_DEV);
        assertEq(market.totalBacking(), INITIAL_BACKING);
        assertTrue(market.initialized());
        assertFalse(market.settled());
    }

    function testCannotInitializeMarketTwice() public {
        // First initialization
        vm.startPrank(LP_1);
        market.initializeMarket(
            INITIAL_MEAN,
            INITIAL_STD_DEV,
            INITIAL_BACKING,
            INITIAL_K
        );
        vm.stopPrank();
        
        // Fund second LP
        token.mint(LP_2, INITIAL_BACKING);
        vm.startPrank(LP_2);
        token.approve(address(market), INITIAL_BACKING);
        
        // Try to initialize again - should revert
        vm.expectRevert("Market already initialized");
        market.initializeMarket(
            INITIAL_MEAN,
            INITIAL_STD_DEV,
            INITIAL_BACKING,
            INITIAL_K
        );
        vm.stopPrank();
    }

    function testSettleAfterInitialization() public {
        // Initialize market
        vm.startPrank(LP_1);
        uint256 positionId = market.initializeMarket(
            INITIAL_MEAN,
            INITIAL_STD_DEV,
            INITIAL_BACKING,
            INITIAL_K
        );
        vm.stopPrank();
        
        uint256 initialMarketBalance = token.balanceOf(address(market));
        
        // Settle market
        int256 finalValue = 105e18;  // 105.0
        vm.expectEmit(true, true, true, true);
        emit MarketSettled(finalValue);
        market.settleMarket(finalValue);
        
        // Record LP balance before settlement
        uint256 initialLpBalance = token.balanceOf(LP_1);
        
        // Settle position
        vm.startPrank(LP_1);
        market.settlePosition(positionId);
        vm.stopPrank();
        
        // Check LP balance increased
        uint256 newLpBalance = token.balanceOf(LP_1);
        assertTrue(newLpBalance > initialLpBalance);
        
        // Record LP token balance
        uint256 initialLpTokens = market.balanceOf(LP_1);
        
        // Settle LP tokens
        vm.startPrank(LP_1);
        market.settleLpTokens(LP_1);
        vm.stopPrank();
        
        // Check final balances
        assertEq(market.balanceOf(LP_1), 0);  // LP tokens burned
        assertTrue(token.balanceOf(LP_1) > newLpBalance);  // Got more funds from LP position
        assertTrue(token.balanceOf(address(market)) < initialMarketBalance);  // Market paid out funds
        
        // Verify total payout equals initial backing (within rounding)
        uint256 totalPayout = token.balanceOf(LP_1);
        assertApproxEqRel(totalPayout, INITIAL_BACKING, EPSILON);
    }

    function testTradeAfterLp() public {
        // Initialize market first
        vm.startPrank(LP_1);
        uint256 initPositionId = market.initializeMarket(
            INITIAL_MEAN,
            INITIAL_STD_DEV,
            INITIAL_BACKING,
            INITIAL_K
        );
        vm.stopPrank();
        
        console.log("Initial Position ID:", initPositionId);

        // Setup trader
        uint256 maxCollateral = 15e18; // 15.0 (more than needed)
        token.mint(TRADER_1, maxCollateral);
        vm.startPrank(TRADER_1);
        token.approve(address(market), maxCollateral);

        // Execute trade - move mean to 100.0, keep same std dev
        int256 newMean = 100e18;
        
        // Calculate expected collateral (from Python test)
        uint256 expectedCollateral = 14851900000000000000; // ~14.8519 scaled to 1e18
        
        // Execute trade and capture position ID
        vm.expectEmit(true, true, true, true);
        uint256 expectedPosId = initPositionId + 1;
        console.log("Expected Position ID:", expectedPosId);
        console.log("Expected Collateral:", expectedCollateral);
        emit Trade(expectedPosId, TRADER_1, newMean, INITIAL_STD_DEV, expectedCollateral);
        
        uint256 positionId = market.trade(
            newMean,
            INITIAL_STD_DEV,
            maxCollateral
        );
        console.log("Actual Position ID:", positionId);
        
        // Get position details to see actual collateral
        (,,,uint256 actualCollateral,) = market.getPosition(positionId);
        console.log("Actual Collateral:", actualCollateral);
        
        vm.stopPrank();
        vm.stopPrank();

        // Verify position creation
        (int256 posMean, uint256 posStdDev, uint256 posK, uint256 posCollateral, bool isLp) = market.getPosition(positionId);
        assertEq(posMean, newMean);
        assertEq(posStdDev, INITIAL_STD_DEV);
        assertEq(posK, INITIAL_K);
        assertFalse(isLp);

        // Check collateral is close to expected value (14.8519 from Python test)
        assertApproxEqRel(posCollateral, expectedCollateral, EPSILON);

        // Check market state updated
        assertEq(market.currentMean(), newMean);
        assertEq(market.currentStdDev(), INITIAL_STD_DEV);
    }
}