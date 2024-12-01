// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Errors library
 * @author Elku
 * @notice Defines the error messages emitted by the different contracts of the LBHelper protocol
 */
library Errors {
    error DeadlineShouldBeInTheFuture(uint256, uint256);
    error OnlyOriginalLenderCanUpdateLendedPool();
    error CollateralTokenIsNotWhitelisted(address);
    error CollateralToBorrowRatioShouldBeSameOrSmaller(uint256, uint256);
    error MinBorrowAmountShouldBeSameOrSmaller(uint256, uint256);
    error InterestRateShouldBeSameOrSmaller(uint256, uint256);
    error PartialRepaymentAllowedShouldBeSameOrTrue(bool, bool);
    error DeadlineShouldBeSameOrGreater(uint256, uint256);
    
}
