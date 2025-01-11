// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/libraries/DistributionMath.sol";
import "solgauss/Gaussian.sol";

contract DistributionMathTest is Test {
    uint256 constant PRECISION = 1e18;
    // Allow for 0.01% difference in calculations due to fixed-point arithmetic
    uint256 constant EPSILON = PRECISION / 10000;  // 0.01%

    function setUp() public {}

    function testCalculateLambda() public {
        // Test case 1: k = 10, sigma = 10, expected lambda ≈ 59.5391274861
        uint256 k1 = 10 * PRECISION;
        uint256 sigma1 = 10 * PRECISION;
        uint256 expectedLambda1 = 59539127486100000000; // 59.5391274861 * PRECISION
        uint256 lambda1 = DistributionMath.calculateLambda(sigma1, k1);
        
        assertApproxEqRel(
            lambda1,
            expectedLambda1,
            EPSILON,
            "Lambda calculation failed for k=10, sigma=10"
        );

        // Test case 2: k = 1, sigma = 12, expected lambda ≈ 6.52218463567
        uint256 k2 = 1 * PRECISION;
        uint256 sigma2 = 12 * PRECISION;
        uint256 expectedLambda2 = 6522184635670000000; // 6.52218463567 * PRECISION
        uint256 lambda2 = DistributionMath.calculateLambda(sigma2, k2);
        
        assertApproxEqRel(
            lambda2,
            expectedLambda2,
            EPSILON,
            "Lambda calculation failed for k=1, sigma=12"
        );
    }

    function testCalculateF() public {
        // Test case: x = 100, mu = 100, sigma = 10, k = 1, expected f ≈ 23.75268
        int256 x = 100 * int256(PRECISION);
        int256 mu = 100 * int256(PRECISION);
        uint256 sigma = 10 * PRECISION;
        uint256 k = 1 * PRECISION;
        uint256 expectedF = 23752680000000000000; // 23.75268 * PRECISION
        
        uint256 f = DistributionMath.calculateF(x, mu, sigma, k);
        
        assertApproxEqRel(
            f,
            expectedF,
            EPSILON,
            "F calculation failed for x=100, mu=100, sigma=10"
        );
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
        
        // At minimum sigma, maximum k should equal our input k
        assertApproxEqRel(maxK, k, EPSILON, "Maximum k should match input k at minimum sigma");
        
        // Test that the maximum k constraint is enforced
        uint256 f = DistributionMath.calculateF(
            0,  // x at mean
            0,  // mu = 0
            minSigma,
            maxK
        );
        
        // The maximum value of the PDF should occur at the mean
        // and should equal the backing amount
        assertApproxEqRel(f, b, EPSILON * 10, "Maximum PDF value should equal backing");
    }
}