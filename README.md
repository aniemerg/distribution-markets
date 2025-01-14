# Distribution Markets

A Solidity implementation for distribution prediction markets, based on ["Distribution Markets"](https://www.paradigm.xyz/2024/12/distribution-markets) by [Dave White](https://x.com/_Dave__White_). Follows the design of [Distribution Markets (Python)](https://github.com/aniemerg/distributionmarkets)

## Overview

Distribution markets extend traditional prediction markets by allowing traders to express beliefs about entire probability distributions rather than just discrete outcomes. This Solidity implementation provides the core mathematical tools for implementing these markets on-chain, with a focus on efficient and precise calculations using fixed-point arithmetic.

## Architecture

The implementation is built on fixed-point mathematics using PRBMath, providing high-precision calculations for Gaussian distributions and their derivatives. Key components include:

- `DistributionMath.sol`: Core mathematical library implementing the fundamental calculations needed for distribution markets
- Fixed-point arithmetic handling using `SD59x18` and `UD60x18` types

## Installation

```bash
# Clone the repository
git clone git@github.com:aniemerg/distribution-markets.git
cd distribution-markets

# Install dependencies
forge install
```

## Development

To compile:
```bash
forge build
```

To run tests:
```bash
forge test
```

For verbose test output:
```bash
forge test -vv
```

## Contributing

Contributions via pull request are welcome! Please ensure:
1. All tests pass
2. New features include comprehensive tests
3. Gas optimization is considered
4. Fixed-point arithmetic is handled correctly
5. Comments explain complex mathematical operations
