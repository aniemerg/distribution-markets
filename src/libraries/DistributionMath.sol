// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DistributionMath {
    // Precision for fixed-point calculations
    uint256 constant PRECISION = 1e18;
    
    // Constants
    uint256 constant PI = 3141592653589793238; // π * 1e18
    uint256 constant SQRT_PI = 1772453850905516027; // √π * 1e18
    
    /**
     * @dev Calculate lambda scaling factor: λ = k * √(2σ√π)
     * @param sigma Standard deviation
     * @param k L2 norm constraint
     * @return Lambda scaling factor
     */
    function calculateLambda(uint256 sigma, uint256 k) internal pure returns (uint256) {
        // λ = k * √(2σ√π)
        uint256 inner = 2 * sigma * SQRT_PI / PRECISION;
        uint256 sqrt_ = sqrt(inner);
        return (k * sqrt_) / PRECISION;
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
        uint256 denominator = ((b * b * SQRT_PI) / PRECISION);
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
        uint256 inner = sigma * SQRT_PI / PRECISION;
        uint256 sqrt_ = sqrt(inner);
        return (b * sqrt_) / PRECISION;
    }
    
    /**
     * @dev Calculate the value of the scaled PDF at a point
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
        // f(x) = λ * exp(-(x-μ)²/2σ²) / √(2πσ²)
        uint256 lambda = calculateLambda(sigma, k);
        
        // Calculate (x-μ)²/2σ²
        int256 diff = x - mu;
        uint256 diffSquared = uint256(diff * diff);
        uint256 twoSigmaSquared = 2 * sigma * sigma;
        uint256 exponent = (diffSquared * PRECISION) / twoSigmaSquared;
        
        // Calculate exp(-exponent)
        uint256 expTerm = exp(-int256(exponent));
        
        // Calculate 1/√(2πσ²)
        uint256 denominator = sqrt(2 * PI * sigma * sigma / PRECISION);
        
        // Combine terms
        return (lambda * expTerm) / denominator;
    }
    
    /**
     * @dev Calculate square root
     * @param x Input value
     * @return y Square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        // This is using `sqrt(x) = e^(ln(x)/2)`
        assembly {
            // We'll use the precompile at address 0x05 for exp
            let xx := x
            
            // Compute ln(x) using a Taylor series
            let ln := 0
            let n := 1
            for { } lt(n, 8) { n := add(n, 1) } {
                let term := div(xx, n)
                ln := add(ln, term)
                xx := div(mul(xx, x), n)
            }
            
            // Compute exp(ln(x)/2) using the precompile
            let halfLn := div(ln, 2)
            y := exp(halfLn)
        }
    }
    
    /**
     * @dev Calculate e^x
     * @param x Input value
     * @return Result e^x
     */
    function exp(int256 x) internal pure returns (uint256) {
        // This implementation uses a lookup table and linear interpolation
        // A more precise implementation would be needed for production
        require(x >= -50 * int256(PRECISION) && x <= 50 * int256(PRECISION), "exp: input out of bounds");
        
        // Simple approximation for demo
        if (x >= 0) {
            return uint256(x) + PRECISION;
        } else {
            return PRECISION - uint256(-x);
        }
    }
}