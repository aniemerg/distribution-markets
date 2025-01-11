// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solgauss/Gaussian.sol";

library DistributionMath {
    // Precision for fixed-point calculations
    uint256 constant PRECISION = 1e18;
    
    /**
     * @dev Calculate lambda scaling factor: λ = k * √(2σ√π)
     * @param sigma Standard deviation
     * @param k L2 norm constraint
     * @return Lambda scaling factor
     */
    function calculateLambda(uint256 sigma, uint256 k) internal pure returns (uint256) {
        // λ = k * √(2σ√π)
        uint256 twoSigmaSqrtPi = (2 * sigma * Gaussian.SQRT_PI) / PRECISION;
        uint256 sqrt = sqrtPrecise(twoSigmaSqrtPi);
        return (k * sqrt) / PRECISION;
    }
    
    /**
     * @dev Calculate minimum allowed standard deviation: σ >= k² / (b²√π)
     * @param k L2 norm constraint
     * @param b Backing amount
     * @return Minimum allowed standard deviation
     */
    function calculateMinimumSigma(uint256 k, uint256 b) internal pure returns (uint256) {
        // σ_min = k² / (b²√π)
        uint256 numerator = k * k;
        uint256 denominator = ((b * b * Gaussian.SQRT_PI) / PRECISION);
        return (numerator * PRECISION) / denominator;
    }
    
    /**
     * @dev Calculate maximum allowed k: k = b * √(σ√π)
     * @param sigma Standard deviation
     * @param b Maximum backing amount
     * @return Maximum allowed k value
     */
    function calculateMaximumK(uint256 sigma, uint256 b) internal pure returns (uint256) {
        // k_max = b * √(σ√π)
        uint256 inner = (sigma * Gaussian.SQRT_PI) / PRECISION;
        uint256 sqrt = sqrtPrecise(inner);
        return (b * sqrt) / PRECISION;
    }
    
    /**
     * @dev Calculate the value of the scaled PDF at a point
     * Uses the Gaussian PDF: f(x) = λ * exp(-(x-μ)²/2σ²) / √(2πσ²)
     * @param x Point to evaluate
     * @param mu Mean of the distribution
     * @param sigma Standard deviation
     * @param k L2 norm constraint
     * @return Value of scaled PDF
     */
    function calculateF(
        int256 x, 
        int256 mu, 
        uint256 sigma, 
        uint256 k
    ) internal pure returns (uint256) {
        // Standardize x to z-score: z = (x - μ)/σ
        int256 z = ((x - mu) * int256(PRECISION)) / int256(sigma);
        
        // Calculate PDF using solgauss
        uint256 pdf = Gaussian.pdf(uint256(z >= 0 ? z : -z));
        
        // Scale by lambda
        uint256 lambda = calculateLambda(sigma, k);
        return (lambda * pdf) / PRECISION;
    }

    /**
     * @dev Precise square root function using Newton's method
     */
    function sqrtPrecise(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        // Using Newton's method
        y = x;
        uint256 z = (x + 1) / 2;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}