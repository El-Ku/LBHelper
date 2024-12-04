// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Errors library
 * @author Elku
 * @notice Defines the error messages emitted by the different contracts of the LBHelper protocol
 */
library Errors {
    error DeadlineShouldBeInTheFuture(uint256, uint256);
    error OnlyOriginalLenderCanUpdateLendedPool();
    error CollateralTokenIsNotWhitelisted(address);
    error LenderTokenIsNotWhitelisted(address);
    error CBRatioShouldBeSameOrSmall(uint256, uint256);
    error MinBAmtShouldBeSameOrSmall(uint256, uint256);
    error InterestRateShouldBeSameOrSmaller(uint256, uint256);
    error PartialRepaymentShouldBeSameOrTrue(bool, bool);
    error DeadlineShouldBeSameOrGreater(uint256, uint256);
    error TotalAmountShouldBePositive(uint256);
    error NotOwner();
    error NotTempOwner();
    error TokenNeeds18Decimals();
    error OnlyOriginalLenderCanCancelLending();
    error LenderStillHasBorrowers();
    error CoolDownPeriodNotYetOver();
}
