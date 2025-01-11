// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solstat/Gaussian.sol";

library DistributionMath {
    // Precision for fixed-point calculations
    uint256 constant PRECISION = 1e18;
    
    // Constants scaled by PRECISION
    uint256 constant PI = 3141592653589793238;
    uint256 constant SQRT_PI = 1772453850905516027;
    uint256 constant SQRT_TWO = 1414213562373095048;
    uint256 constant SQRT_TWO_PI = 2506628274631000502; // √(2π)
    
    /**
     * @dev Calculate lambda scaling factor: λ = k * √(2σ√π)
     */
    function calculateLambda(uint256 sigma, uint256 k) internal pure returns (uint256) {
        // Calculate 2σ√π with proper scaling
        uint256 scaledSigma = sigma; // sigma is already scaled by PRECISION
        uint256 innerTerm = (2 * scaledSigma * SQRT_PI); // Now scaled by PRECISION^2
        
        // Take square root - removes one PRECISION factor
        uint256 sqrt = sqrtPrecise(innerTerm);
        
        // Multiply by k and divide by PRECISION once to get final scaling
        return (k * sqrt) / PRECISION;
    }
    
    /**
     * @dev Calculate minimum allowed standard deviation: σ >= k² / (b²√π)
     */
    function calculateMinimumSigma(uint256 k, uint256 b) internal pure returns (uint256) {
        // k and b are both scaled by PRECISION
        uint256 kSquared = (k * k);  // Scaled by PRECISION^2
        uint256 bSquared = (b * b);  // Scaled by PRECISION^2
        return (kSquared * PRECISION * PRECISION) / (bSquared * SQRT_PI);
    }
    
    /**
     * @dev Calculate maximum allowed k: k = b * √(σ√π)
     */
    function calculateMaximumK(uint256 sigma, uint256 b) internal pure returns (uint256) {
        // sigma and b are scaled by PRECISION
        uint256 inner = (sigma * SQRT_PI) / PRECISION;  // Scale back to PRECISION
        uint256 sqrt = sqrtPrecise(inner * PRECISION);  // Add PRECISION to compensate for sqrt
        return (b * sqrt) / PRECISION;
    }
    
    /**
     * @dev Calculate the value of the scaled PDF at a point
     */
    function calculateF(
        int256 x, 
        int256 mu, 
        uint256 sigma, 
        uint256 k
    ) internal pure returns (uint256) {
        // Calculate standardized value z = (x - μ)/σ
        int256 z = ((x - mu) * int256(PRECISION)) / int256(sigma);
        
        // Calculate PDF = (1/√(2πσ²)) * exp(-z²/2)
        // First calculate z²/2
        uint256 absZ = uint256(z >= 0 ? z : -z);
        uint256 zSquared = (absZ * absZ) / PRECISION;
        uint256 zSquaredHalf = zSquared / 2;
        
        // Calculate exp(-z²/2) - result is scaled by PRECISION
        uint256 expTerm = exp(-int256(zSquaredHalf));
        
        // Calculate 1/(σ√(2π))
        uint256 denominator = (sigma * SQRT_TWO_PI) / PRECISION;
        uint256 standardPdf = (expTerm * PRECISION) / denominator;
        
        // Scale by lambda
        uint256 lambda = calculateLambda(sigma, k);
        return (lambda * standardPdf) / PRECISION;
    }

    function calculateFWithDebug(
        int256 x, 
        int256 mu, 
        uint256 sigma, 
        uint256 k
    ) public pure returns (uint256 expTerm, uint256 denominator, uint256 standardPdf, uint256 lambda, uint256 result) {
        // Calculate standardized value z = (x - μ)/σ
        int256 z = ((x - mu) * int256(PRECISION)) / int256(sigma);
        
        // Get standardized PDF value using solstat (which uses μ = 0, σ = 1)
        int256 pdfValue = Gaussian.pdf(z);  // This will give us PDF for standard normal
        
        // Convert to uint for remaining calculations (PDF is always positive)
        standardPdf = uint256(pdfValue);
        
        // Adjust for our sigma (divide by sigma since PDF = (1/σ) * standard_pdf)
        standardPdf = (standardPdf * PRECISION) / sigma;
        
        // Scale by lambda
        lambda = calculateLambda(sigma, k);
        result = (lambda * standardPdf) / PRECISION;
        
        // For debugging, include other values
        expTerm = 0;  // Not used with solstat
        denominator = sigma;  // Just for debugging
        
        return (expTerm, denominator, standardPdf, lambda, result);
    }
    /**
     * @dev Calculate exp(x) for x scaled by PRECISION
     */
    function exp(int256 x) internal pure returns (uint256) {
        if (x < -41 * int256(PRECISION)) {
            return 0;
        }
        
        if (x > 50 * int256(PRECISION)) {
            revert("exp overflow");
        }
        
        bool isNegative = x < 0;
        if (isNegative) {
            x = -x;
        }
        
        // Use Taylor series for exp(x)
        uint256 result = PRECISION;  // First term: 1
        uint256 xi = PRECISION;      // x^i, starting at x^0
        uint256 fact = 1;           // i!, starting at 0!
        
        for (uint256 i = 1; i <= 15; i++) {
            xi = (xi * uint256(x)) / PRECISION;  // x^i
            fact = fact * i;                     // i!
            uint256 term = (xi * PRECISION) / fact;
            result += term;
        }
        
        if (isNegative) {
            return (PRECISION * PRECISION) / result;
        }
        return result;
    }

    /**
     * @dev Calculate square root using Newton's method
     */
    function sqrtPrecise(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        // Initial guess
        y = x;
        uint256 z = (x + 1) / 2;
        
        // Newton iterations
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}