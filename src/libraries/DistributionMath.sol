// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { UD60x18, ud, exp, sqrt } from "@prb/math/src/UD60x18.sol";
import "forge-std/console.sol";


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


    function calculateFirstDerivative(
        int256 x,
        int256 mu,
        uint256 sigma,
        uint256 k
    ) internal pure returns (int256) {
        UD60x18 scaledSigma = ud(sigma);
        
        int256 diff = x - mu;
        console.log("First derivative diff:", uint256(diff >= 0 ? diff : -diff));
        
        uint256 fValue = calculateF(x, mu, sigma, k);
        console.log("First derivative fValue:", fValue);
        
        if (fValue == 0) return 0;
        
        UD60x18 sigmaSquared = scaledSigma.mul(scaledSigma).div(ud(PRECISION));
        console.log("First derivative sigmaSquared:", sigmaSquared.intoUint256());
        
        SD59x18 multiplier = sd(diff).div(sd(int256(sigmaSquared.intoUint256())));
        console.log("First derivative multiplier:", uint256(multiplier.intoInt256()));
        
        multiplier = multiplier.mul(sd(-1e18));
        
        return multiplier.mul(sd(int256(fValue))).intoInt256();
    }

    function calculateSecondDerivative(
        int256 x,
        int256 mu,
        uint256 sigma,
        uint256 k
    ) internal pure returns (int256) {
        UD60x18 scaledSigma = ud(sigma);
        
        // Calculate standardized value z = (x - μ)/σ
        int256 diff = x - mu;
        console.log("Second derivative diff:", uint256(diff >= 0 ? diff : -diff));
        
        uint256 fValue = calculateF(x, mu, sigma, k);
        console.log("Second derivative fValue:", fValue);
        
        if (fValue == 0) return 0;
        
        // Calculate (x-μ)²/σ⁴
        UD60x18 sigmaSquared = scaledSigma.mul(scaledSigma).div(ud(PRECISION));
        console.log("Second derivative sigmaSquared:", sigmaSquared.intoUint256());
        
        UD60x18 sigmaQuad = sigmaSquared.mul(sigmaSquared).div(ud(PRECISION));
        console.log("Second derivative sigmaQuad:", sigmaQuad.intoUint256());
        
        UD60x18 diffSquared = ud(uint256(diff >= 0 ? diff : -diff))
            .mul(ud(uint256(diff >= 0 ? diff : -diff)))
            .div(ud(PRECISION));
        console.log("Second derivative diffSquared:", diffSquared.intoUint256());
        
        UD60x18 firstTerm = diffSquared.div(sigmaQuad);
        console.log("Second derivative firstTerm:", firstTerm.intoUint256());
        
        // Calculate 1/σ²
        UD60x18 secondTerm = ud(PRECISION).div(sigmaSquared);
        console.log("Second derivative secondTerm:", secondTerm.intoUint256());
        
        // Calculate ((x-μ)²/σ⁴ - 1/σ²)
        SD59x18 multiplier;
        if (firstTerm.gt(secondTerm)) {
            multiplier = sd(int256(firstTerm.sub(secondTerm).intoUint256()));
        } else {
            multiplier = sd(-int256(secondTerm.sub(firstTerm).intoUint256()));
        }
        console.log("Second derivative multiplier:", uint256(multiplier.intoInt256()));
        
        return multiplier.mul(sd(int256(fValue))).intoInt256();
    }

    function findMaximumLossNoScipy(
        int256 from_mu,
        uint256 from_sigma,
        int256 to_mu,
        uint256 to_sigma,
        int256 hint,
        uint256 k,
        uint256 max_iterations,
        uint256 tolerance
    ) public pure returns (uint256 maxLoss, int256 xAtMaxLoss) {
        SD59x18 x = sd(hint);
        console.log("Initial x:", uint256(x.intoInt256()));
        
        // Adjust hint if needed
        if (from_mu < to_mu && hint <= to_mu) {
            x = sd(to_mu + int256(to_sigma));
            console.log("Adjusted x up:", uint256(x.intoInt256()));
        } else if (from_mu > to_mu && hint >= to_mu) {
            x = sd(to_mu - int256(to_sigma));
            console.log("Adjusted x down:", uint256(x.intoInt256()));
        }
        
        SD59x18 prev_x = x;
        
        for (uint256 i = 0; i < max_iterations; i++) {
            console.log("Iteration:", i);
            console.log("Current x:", uint256(x.intoInt256()));
            
            // Calculate derivatives
            int256 f1_derivative = calculateFirstDerivative(x.intoInt256(), from_mu, from_sigma, k);
            console.log("f1_derivative:", uint256(f1_derivative >= 0 ? f1_derivative : -f1_derivative));
            
            int256 g1_derivative = calculateFirstDerivative(x.intoInt256(), to_mu, to_sigma, k);
            console.log("g1_derivative:", uint256(g1_derivative >= 0 ? g1_derivative : -g1_derivative));
            
            int256 f2_derivative = calculateSecondDerivative(x.intoInt256(), from_mu, from_sigma, k);
            console.log("f2_derivative:", uint256(f2_derivative >= 0 ? f2_derivative : -f2_derivative));
            
            int256 g2_derivative = calculateSecondDerivative(x.intoInt256(), to_mu, to_sigma, k);
            console.log("g2_derivative:", uint256(g2_derivative >= 0 ? g2_derivative : -g2_derivative));
            
            // Total derivatives
            SD59x18 derivative = sd(g1_derivative - f1_derivative);
            SD59x18 secondDerivative = sd(g2_derivative - f2_derivative);
            
            console.log("Combined derivative:", uint256(derivative.intoInt256()));
            console.log("Combined second derivative:", uint256(secondDerivative.intoInt256()));
            
            // Check convergence
            if (derivative.abs().intoUint256() < tolerance) {
                break;
            }
            
            // Prevent division by very small numbers
            if (secondDerivative.abs().intoUint256() < 1e8) {
                break;
            }
            
            // Newton step with damping
            SD59x18 step = derivative.div(secondDerivative);
            SD59x18 damping = sd(875000000000000000);  // 0.875
            step = step.mul(damping);
            
            x = x.sub(step);
            
            // Enforce bounds
            if (from_mu < to_mu) {
                x = x.lt(sd(to_mu)) ? sd(to_mu) : x;
            } else {
                x = x.gt(sd(to_mu)) ? sd(to_mu) : x;
            }
            
            // Check if x has converged
            SD59x18 delta = x.sub(prev_x).abs();
            if (delta.intoUint256() < tolerance) {
                break;
            }
            prev_x = x;
        }
        
        // Calculate final position value
        uint256 finalPosition = positionAtPoint(
            x.intoInt256(),
            from_mu,
            from_sigma,
            to_mu,
            to_sigma,
            k
        );
        
        return (finalPosition, x.intoInt256());
    }


    function positionAtPoint(
        int256 x,
        int256 from_mu,
        uint256 from_sigma,
        int256 to_mu,
        uint256 to_sigma,
        uint256 k
    ) internal pure returns (uint256) {
        uint256 f1 = calculateF(x, from_mu, from_sigma, k);
        uint256 f2 = calculateF(x, to_mu, to_sigma, k);
        
        // Return absolute value of difference
        return f2 >= f1 ? f2 - f1 : f1 - f2;
    }

}