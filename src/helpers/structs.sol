// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @title Structs
// @Author: Elku
// @dev Structures used in the Pool contract.
contract Structs {
    struct LendedPool {
        address lender;
        uint256[] borrowerInfo; // points to the correct mapping
        address lenderToken;
        address collateralToken;
        uint256 collateralToBorrowRatio;
        uint256 minBorrowAmount;
        uint256 interestRate;
        bool partialRepaymentAllowed;
        uint256 deadline;
        uint256 initialAmountToLend;
        uint256 totalRemainingAmountToLend;
    }

    struct BorrowerInfo {
        uint256 lenderPoolId; // points to the correct mapping
        uint256 lastRapayedTimestamp;
        uint256 remainingBorrowedAmount;
        uint256 interestAccrued;
        uint256 remainingAmountToRepay;
    }
}
