// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solstat/Gaussian.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { UD60x18, ud, exp, sqrt } from "@prb/math/src/UD60x18.sol";


library DistributionMath {
    
    // Precision for fixed-point calculations
    uint256 constant PRECISION = 1e18;
    uint256 constant PI = 3141592653589793238;
    uint256 constant SQRT_PI = 1772453850905516027;
    uint256 constant SQRT_TWO = 1414213562373095048;
    uint256 constant SQRT_TWO_PI = 2506628274631000502; // √(2π)
    
    function calculateLambda(uint256 sigma, uint256 k) internal pure returns (uint256) {
        UD60x18 scaledSigma = ud(sigma);
        UD60x18 scaledK = ud(k);
        UD60x18 innerTerm = ud(2e18).mul(scaledSigma).mul(ud(SQRT_PI));
        return scaledK.mul(sqrt(innerTerm)).intoUint256();
    }
        
    function calculateF(
        int256 x, 
        int256 mu, 
        uint256 sigma, 
        uint256 k
    ) internal pure returns (uint256) {
        UD60x18 scaledSigma = ud(sigma);
        UD60x18 scaledK = ud(k);
        
        // Calculate standardized value z = (x - μ)/σ
        int256 diff = x - mu;  // Already scaled by PRECISION
        UD60x18 diffSquared = ud(uint256(diff >= 0 ? diff : -diff))
            .mul(ud(uint256(diff >= 0 ? diff : -diff)))
            .div(ud(PRECISION));
        
        UD60x18 sigmaSquared = scaledSigma.mul(scaledSigma).div(ud(PRECISION));
        UD60x18 exponentNumerator = diffSquared.div(ud(2e18).mul(sigmaSquared));
        
        // If exponent is too large, return 0 as the probability is effectively zero
        if (exponentNumerator.gt(ud(133e18))) {
            return 0;
        }
        
        // Calculate e^(-exponentNumerator)
        UD60x18 expTerm = exp(ud(0)).div(exp(exponentNumerator));
        
        // Calculate 1/(σ√(2π))
        UD60x18 denominator = scaledSigma.mul(ud(SQRT_TWO_PI)).div(ud(PRECISION));
        
        // Calculate PDF value
        UD60x18 standardPdf = expTerm.mul(ud(PRECISION)).div(denominator);
        
        // Scale by lambda
        UD60x18 lambda = ud(calculateLambda(sigma, k));
        return lambda.mul(standardPdf).intoUint256();
    }
    
    function calculateMinimumSigma(uint256 k, uint256 b) internal pure returns (uint256) {
        UD60x18 scaledK = ud(k);
        UD60x18 scaledB = ud(b);
        UD60x18 kSquared = scaledK.mul(scaledK);
        UD60x18 bSquared = scaledB.mul(scaledB);
        return kSquared.mul(ud(PRECISION)).mul(ud(PRECISION)).div(bSquared.mul(ud(SQRT_PI))).intoUint256();
    }
    
    function calculateMaximumK(uint256 sigma, uint256 b) internal pure returns (uint256) {
        UD60x18 scaledSigma = ud(sigma);
        UD60x18 inner = scaledSigma.mul(ud(SQRT_PI)).div(ud(PRECISION));
        return ud(b).mul(sqrt(inner)).intoUint256();
    }
}