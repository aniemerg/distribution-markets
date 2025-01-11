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
}