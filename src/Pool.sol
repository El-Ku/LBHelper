// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Errors} from "./helpers/errors.sol";
import {Structs} from "./helpers/structs.sol";

// @title Pool
// @Author: Elku
// @dev Multiple borrowers can borrow from a single lender if there are enough funds.
contract Pool is Structs {
    address private s_owner;
    mapping(address => bool) private s_whitelistedTokens; //true means its whitelisted

    mapping(uint256 => LendedPool) private s_lenderPools; //pool id to lender pool infor
    uint256 private s_currentMaxLenderPoolId;

    mapping(uint256 => BorrowerInfo) private s_borrowerInfos;

    constructor() {
        s_owner = msg.sender;
    }

    // Function called by lender.
    function lendNew(
        address collateralToken,
        uint256 CollateralToBorrowRatio,
        uint256 minBorrowAmount,
        uint256 interestRate,
        bool partialRepaymentAllowed,
        uint256 deadline,
        uint256 totalAmount
    ) external {
        _lend(
            collateralToken,
            CollateralToBorrowRatio,
            minBorrowAmount,
            interestRate,
            partialRepaymentAllowed,
            deadline,
            totalAmount,
            type(uint256).max //create a new mapping
        );
    }

    // Function called by lender.
    function lendUpdate(
        uint256 CollateralToBorrowRatio, //this would be ideally more than 1.
        uint256 minBorrowAmount,
        uint256 interestRate,
        bool partialRepaymentAllowed,
        uint256 deadline,
        uint256 amountToAdd,
        uint256 lenderPoolId
    ) external {
        require(
            s_lenderPools[lenderPoolId].lender == msg.sender,
            Errors.OnlyOriginalLenderCanUpdateLendedPool()
        );
        _lend(
            address(0),
            CollateralToBorrowRatio,
            minBorrowAmount,
            interestRate,
            partialRepaymentAllowed,
            deadline,
            amountToAdd,
            lenderPoolId //update an existing mapping
        );
    }

    // Function called by borrower specifying which lender he want to choose and how much he want to borrow

    // Internal functions
    function _lend(
        address collateralToken,
        uint256 CollateralToBorrowRatio,
        uint256 minBorrowAmount,
        uint256 interestRate,
        bool partialRepaymentAllowed,
        uint256 deadline,
        uint256 totalAmount,
        uint256 lenderPoolId
    ) internal {
        require(
            s_whitelistedTokens[collateralToken],
            Errors.CollateralTokenIsNotWhitelisted(collateralToken)
        );
        require(
            deadline > block.timestamp,
            Errors.DeadlineShouldBeInTheFuture(deadline, block.timestamp)
        );
        if (lenderPoolId == type(uint256).max) {
            LendedPool memory lendedPool = LendedPool({
                lender: msg.sender,
                borrowerInfo: new uint256[](0),
                collateralToken: collateralToken,
                CollateralToBorrowRatio: CollateralToBorrowRatio,
                minBorrowAmount: minBorrowAmount,
                interestRate: interestRate,
                partialRepaymentAllowed: partialRepaymentAllowed,
                deadline: deadline,
                initialAmountToLend: totalAmount,
                totalRemainingAmountToLend: totalAmount
            });
            s_lenderPools[++s_currentMaxLenderPoolId] = lendedPool;
        } else {
            //update a lender pool
            LendedPool memory lendedPool = s_lenderPools[lenderPoolId];
            require(
                lendedPool.CollateralToBorrowRatio >= CollateralToBorrowRatio,
                Errors.CollateralToBorrowRatioShouldBeSameOrSmaller(
                    CollateralToBorrowRatio,
                    lendedPool.CollateralToBorrowRatio
                )
            );
            require(
                lendedPool.minBorrowAmount >= minBorrowAmount,
                Errors.MinBorrowAmountShouldBeSameOrSmaller(
                    minBorrowAmount,
                    lendedPool.minBorrowAmount
                )
            );
            require(
                lendedPool.interestRate >= interestRate,
                Errors.InterestRateShouldBeSameOrSmaller(
                    interestRate,
                    lendedPool.interestRate
                )
            );
            require(
                lendedPool.partialRepaymentAllowed == partialRepaymentAllowed ||
                    partialRepaymentAllowed == true,
                Errors.PartialRepaymentAllowedShouldBeSameOrTrue(
                    partialRepaymentAllowed,
                    lendedPool.partialRepaymentAllowed
                )
            );
            require(
                lendedPool.deadline <= deadline,
                Errors.DeadlineShouldBeSameOrGreater(
                    deadline,
                    lendedPool.deadline
                )
            );
            LendedPool storage sLendedPool = s_lenderPools[lenderPoolId];
            if (lendedPool.CollateralToBorrowRatio != CollateralToBorrowRatio) {
                sLendedPool.CollateralToBorrowRatio = CollateralToBorrowRatio;
            }
            if (lendedPool.minBorrowAmount != minBorrowAmount) {
                sLendedPool.minBorrowAmount = minBorrowAmount;
            }
            if (lendedPool.interestRate != interestRate) {
                sLendedPool.interestRate = interestRate;
            }
            if (lendedPool.partialRepaymentAllowed != partialRepaymentAllowed) {
                sLendedPool.partialRepaymentAllowed = partialRepaymentAllowed;
            }
            if (lendedPool.deadline != deadline) {
                sLendedPool.deadline = deadline;
            }
            if (totalAmount > 0) {
                sLendedPool.initialAmountToLend =
                    sLendedPool.initialAmountToLend +
                    totalAmount;
            }
        }
    }

    function getOwner() public view returns (address) {
        return s_owner;
    }

    function isTokenWhitelisted(address token) public view returns (bool) {
        return s_whitelistedTokens[token];
    }
}
