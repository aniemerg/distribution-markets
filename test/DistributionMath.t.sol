// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/libraries/DistributionMath.sol";

contract DistributionMathTest is Test {
    uint256 constant PRECISION = 1e18;
    // Allow for 0.1% difference in calculations due to fixed-point arithmetic
    uint256 constant EPSILON = PRECISION / 1000;  // 0.1%

    function setUp() public {}

    function testCalculateLambda() public {
        // Test case 1: k = 10, sigma = 10, expected lambda ≈ 59.5391274861
        uint256 k1 = 10 * PRECISION;
        uint256 sigma1 = 10 * PRECISION;
        uint256 expectedLambda1 = 59539127486100000000; // 59.5391274861 * PRECISION
        uint256 lambda1 = DistributionMath.calculateLambda(sigma1, k1);

        console.log("Lambda1:", lambda1);
        console.log("Expected Lambda1:", expectedLambda1);
        assertApproxEqRel(lambda1, expectedLambda1, EPSILON);
    }

    function testCalculateF() public {
        // Test case: x = 100, mu = 100, sigma = 10, k = 1, expected f ≈ 23.75268
        int256 x = 100 * int256(PRECISION);
        int256 mu = 100 * int256(PRECISION);
        uint256 sigma = 10 * PRECISION;
        uint256 k = 1 * PRECISION;
        uint256 expectedF = 23752680000000000000; // 23.75268 * PRECISION
        
        // Get all intermediate values
        (uint256 expTerm, uint256 denominator, uint256 standardPdf, uint256 lambda, uint256 result) = 
            DistributionMath.calculateFWithDebug(x, mu, sigma, k);
        
        console.log("Intermediate values:");
        console.log("expTerm:", expTerm);
        console.log("denominator:", denominator);
        console.log("standardPdf:", standardPdf);
        console.log("lambda:", lambda);
        console.log("result:", result);
        console.log("Expected:", expectedF);
        
        assertApproxEqRel(result, expectedF, EPSILON);
    }

    function testCalculateFZeroWhenFarFromMean() public {
        // Test that f approaches zero when x is far from the mean
        int256 x = 1000 * int256(PRECISION);  // Very far from mean
        int256 mu = 0;
        uint256 sigma = 10 * PRECISION;
        uint256 k = 1 * PRECISION;
        
        uint256 f = DistributionMath.calculateF(x, mu, sigma, k);
        
        assertLt(f, PRECISION / 1000000, "F should be very close to zero when far from mean");
    }

    function testMinimumSigmaAndMaximumK() public {
        uint256 k = 10 * PRECISION;
        uint256 b = 100 * PRECISION;
        
        uint256 minSigma = DistributionMath.calculateMinimumSigma(k, b);
        uint256 maxK = DistributionMath.calculateMaximumK(minSigma, b);
        
        console.log("MaxK:", maxK);
        console.log("Expected K:", k);
        assertApproxEqRel(maxK, k, EPSILON);
    }
}