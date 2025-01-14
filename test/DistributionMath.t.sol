// DistributionMath.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/libraries/DistributionMath.sol";

contract DistributionMathTest is Test {
    uint256 constant PRECISION = 1e18;
    // Allow for 0.1% difference in calculations
    uint256 constant EPSILON = PRECISION / 1000;

    function setUp() public {}

    function testCalculateLambda() public {
        uint256 k = 100 * PRECISION;
        uint256 sigma = 10 * PRECISION;
        uint256 expectedLambda = 595391274861000000000; // 595.391274861 * PRECISION
        uint256 lambda = DistributionMath.calculateLambda(sigma, k);
        assertApproxEqRel(lambda, expectedLambda, EPSILON);
    }

    // https://www.desmos.com/calculator/92vr2lflym
    function testCalculateF() public {
        // Test case 1: x = mu = 100
        int256 x1 = 100 * int256(PRECISION);
        int256 mu = 100 * int256(PRECISION);
        uint256 sigma = 10 * PRECISION;
        uint256 k = 100 * PRECISION;
        uint256 expectedF1 = 23752680000000000000; // 23.75268 * PRECISION
        uint256 result1 = DistributionMath.calculateF(x1, mu, sigma, k);
        console.log("Test case 1 (x = 100):");
        console.log("result1:", result1);
        console.log("expectedF1:", expectedF1);
        assertApproxEqRel(result1, expectedF1, EPSILON);

        // Test case 2: x = 85
        int256 x2 = 85 * int256(PRECISION);
        uint256 expectedF2 = 7711360000000000000; // 7.71136 * PRECISION
        uint256 result2 = DistributionMath.calculateF(x2, mu, sigma, k);
        console.log("\nTest case 2 (x = 85):");
        console.log("result2:", result2);
        console.log("expectedF2:", expectedF2);
        assertApproxEqRel(result2, expectedF2, EPSILON);
    }

    function testCalculateFZeroWhenFarFromMean() public {
        int256 x = 1000 * int256(PRECISION);
        int256 mu = 0;
        uint256 sigma = 10 * PRECISION;
        uint256 k = 100 * PRECISION;
        uint256 f = DistributionMath.calculateF(x, mu, sigma, k);
        assertLt(f, PRECISION / 1000000, "F should be very close to zero when far from mean");
    }

    function testMinimumSigmaAndMaximumK() public {
        uint256 k = 100 * PRECISION;
        uint256 b = 100 * PRECISION;
        uint256 minSigma = DistributionMath.calculateMinimumSigma(k, b);
        uint256 maxK = DistributionMath.calculateMaximumK(minSigma, b);
        assertApproxEqRel(maxK, k, EPSILON);
    }

    // https://www.desmos.com/calculator/lg3qike3zc
    function testFindMaximumLossSpecificCase() public {
        // Parameters (scaled by 1e18)
        int256 from_mu = 1500000000000000000;    // 1.5
        uint256 from_sigma = 450000000000000000;  // 0.45
        int256 to_mu = 1900000000000000000;      // 1.9
        uint256 to_sigma = 400000000000000000;    // 0.4
        uint256 k = 2000000000000000000;         // 2.0
        
        // Expected results (scaled)
        int256 expected_x = 2108129000000000000;  // 2.108129
        uint256 expected_loss = 1175948000000000000;  // 1.175948
        
        // Initial hint slightly above to_mu
        int256 hint = 2000000000000000000;  // 2.0
        
        (uint256 maxLoss, int256 xAtMaxLoss) = DistributionMath.findMaximumLossNoScipy(
            from_mu,
            from_sigma,
            to_mu,
            to_sigma,
            hint,
            k,
            20,  // max iterations
            1000000000000  // tolerance (1e-6 when scaled)
        );
        
        assertApproxEqRel(
            uint256(xAtMaxLoss),
            uint256(expected_x),
            EPSILON,
            "x value at maximum loss incorrect"
        );
        
        assertApproxEqRel(
            maxLoss,
            expected_loss,
            EPSILON,
            "maximum loss value incorrect"
        );
    }


}