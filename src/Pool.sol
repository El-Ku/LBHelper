// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Errors} from "./helpers/errors.sol";
import {Structs} from "./helpers/structs.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// @title Pool
// @Author: Elku
// @dev Multiple borrowers can borrow from a single lender if there are enough funds.
contract Pool is Structs {
    using SafeERC20 for ERC20;

    address private s_owner;
    address private s_tempOwner;
    uint256 private s_tempOwnerSetTimestamp;
    uint256 private constant COOL_DOWN_PERIOD = 1 days;
    mapping(address => bool) private s_whitelistedTokens; //true means its whitelisted

    mapping(uint256 => LendedPool) private s_lenderPools; //pool id to lender pool infor
    uint256 private s_currentMaxLenderPoolId;

    mapping(uint256 => BorrowerInfo) private s_borrowerInfos;

    constructor() {
        s_owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner, Errors.NotOwner());
        _;
    }

    modifier onlyTempOwner() {
        require(msg.sender == s_tempOwner, Errors.NotTempOwner());
        _;
    }

    // Function called by lender.
    function lendNew(
        address lenderToken,
        address collateralToken,
        uint256 collateralToBorrowRatio,
        uint256 minBorrowAmount,
        uint256 interestRate,
        bool partialRepaymentAllowed,
        uint256 deadline,
        uint256 totalAmount
    ) external {
        require(s_whitelistedTokens[lenderToken], Errors.LenderTokenIsNotWhitelisted(lenderToken));
        require(s_whitelistedTokens[collateralToken], Errors.CollateralTokenIsNotWhitelisted(collateralToken));
        require(deadline > block.timestamp, Errors.DeadlineShouldBeInTheFuture(deadline, block.timestamp));
        require(totalAmount > 0 && totalAmount >= minBorrowAmount, Errors.TotalAmountShouldBePositive(totalAmount));
        LendedPool memory lendedPool = LendedPool({
            lender: msg.sender,
            borrowerInfo: new uint256[](0),
            lenderToken: lenderToken,
            collateralToken: collateralToken,
            collateralToBorrowRatio: collateralToBorrowRatio,
            minBorrowAmount: minBorrowAmount,
            interestRate: interestRate,
            partialRepaymentAllowed: partialRepaymentAllowed,
            deadline: deadline,
            initialAmountToLend: totalAmount,
            totalRemainingAmountToLend: totalAmount
        });
        s_lenderPools[++s_currentMaxLenderPoolId] = lendedPool;
        _transferLenderToken(lenderToken, totalAmount);
    }

    // Function called by lender.
    function lendUpdate(
        uint256 collateralToBorrowRatio, //this would be ideally more than 1.
        uint256 minBorrowAmount,
        uint256 interestRate,
        bool partialRepaymentAllowed,
        uint256 deadline,
        uint256 amountToAdd,
        uint256 lenderPoolId
    ) external {
        require(s_lenderPools[lenderPoolId].lender == msg.sender, Errors.OnlyOriginalLenderCanUpdateLendedPool());
        LendedPool memory lendedPool = s_lenderPools[lenderPoolId];
        require(
            lendedPool.collateralToBorrowRatio >= collateralToBorrowRatio,
            Errors.CBRatioShouldBeSameOrSmall(collateralToBorrowRatio, lendedPool.collateralToBorrowRatio)
        );
        require(
            lendedPool.minBorrowAmount >= minBorrowAmount,
            Errors.MinBAmtShouldBeSameOrSmall(minBorrowAmount, lendedPool.minBorrowAmount)
        );
        require(
            lendedPool.interestRate >= interestRate,
            Errors.InterestRateShouldBeSameOrSmaller(interestRate, lendedPool.interestRate)
        );
        require(
            lendedPool.partialRepaymentAllowed == partialRepaymentAllowed || partialRepaymentAllowed == true,
            Errors.PartialRepaymentShouldBeSameOrTrue(partialRepaymentAllowed, lendedPool.partialRepaymentAllowed)
        );
        require(lendedPool.deadline <= deadline, Errors.DeadlineShouldBeSameOrGreater(deadline, lendedPool.deadline));
        LendedPool storage sLendedPool = s_lenderPools[lenderPoolId];
        if (lendedPool.collateralToBorrowRatio != collateralToBorrowRatio) {
            sLendedPool.collateralToBorrowRatio = collateralToBorrowRatio;
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
        if (amountToAdd > 0) {
            sLendedPool.initialAmountToLend = sLendedPool.initialAmountToLend + amountToAdd;
            sLendedPool.totalRemainingAmountToLend = sLendedPool.totalRemainingAmountToLend + amountToAdd;
        }
        address lenderToken = s_lenderPools[lenderPoolId].lenderToken;
        _transferLenderToken(lenderToken, amountToAdd);
    }

    function cancelLending(uint256 lenderPoolId, bool deleteMapping) external {
        require(s_lenderPools[lenderPoolId].lender == msg.sender, Errors.OnlyOriginalLenderCanCancelLending());
        require(s_lenderPools[lenderPoolId].borrowerInfo.length == 0, Errors.LenderStillHasBorrowers());
        ERC20(s_lenderPools[lenderPoolId].lenderToken).safeTransfer(
            msg.sender, s_lenderPools[lenderPoolId].totalRemainingAmountToLend
        );
        if (deleteMapping) {
            delete s_lenderPools[lenderPoolId];
            s_currentMaxLenderPoolId--;
        } else {
            s_lenderPools[lenderPoolId].totalRemainingAmountToLend = 0;
            s_lenderPools[lenderPoolId].initialAmountToLend = 0;
        }
    }

    // Function called by borrower specifying which lender he want to choose and how much he want to borrow

    // Internal functions
    function _transferLenderToken(address lenderToken, uint256 totalAmount) internal {
        if (totalAmount > 0) {
            ERC20(lenderToken).safeTransferFrom(msg.sender, address(this), totalAmount);
        }
    }

    function addTokenToWhitelist(address token) external onlyOwner {
        require(ERC20(token).decimals() == 18, Errors.TokenNeeds18Decimals());
        s_whitelistedTokens[token] = true;
    }

    function changeOwner(address newOwner) external onlyOwner {
        s_tempOwner = newOwner;
        s_tempOwnerSetTimestamp = block.timestamp;
    }

    function acceptOwnership() external onlyTempOwner {
        require(block.timestamp > s_tempOwnerSetTimestamp + COOL_DOWN_PERIOD, Errors.CoolDownPeriodNotYetOver());
        s_owner = s_tempOwner;
        s_tempOwner = address(0);
    }

    function getOwner() public view returns (address) {
        return s_owner;
    }

    function isTokenWhitelisted(address token) public view returns (bool) {
        return s_whitelistedTokens[token];
    }

    function getLenderPools(uint256 index) public view returns (LendedPool memory) {
        return s_lenderPools[index];
    }

    function getLenderPoolsLength() public view returns (uint256) {
        return s_currentMaxLenderPoolId;
    }

    function getBorrowerInfo(uint256 index) public view returns (BorrowerInfo memory) {
        return s_borrowerInfos[index];
    }
}
