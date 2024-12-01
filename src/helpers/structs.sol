// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// @title Pool
// @Author: Elku
// @dev Multiple borrowers can borrow from a single lender if there are enough funds.
contract Structs {

    struct LendedPool {
        address lender;
        uint256[] borrowerInfo; // points to the correct mapping
        address collateralToken;
        uint256 CollateralToBorrowRatio;
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