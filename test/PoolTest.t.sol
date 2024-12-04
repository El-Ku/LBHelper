// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {DeployPool} from "../script/DeployPool.s.sol";
import {Pool} from "../src/Pool.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Errors} from "../src/helpers/errors.sol";
import {Structs} from "../src/helpers/structs.sol";

contract PoolTest is Test {
    struct Parameters {
        uint256 collateralToBorrowRatio;
        uint256 minBorrowAmount;
        uint256 interestRate;
        bool partialRepaymentAllowed;
        uint256 deadline;
        uint256 totalAmount;
    }

    Parameters s_parameters = Parameters({
        collateralToBorrowRatio: 1.5 ether,
        minBorrowAmount: 10 ether,
        interestRate: 0.01 ether,
        partialRepaymentAllowed: false,
        deadline: block.timestamp + 365 days,
        totalAmount: 20 ether
    });

    struct Parameters2 {
        uint256 collateralToBorrowRatio;
        uint256 minBorrowAmount;
        uint256 interestRate;
        bool partialRepaymentAllowed;
        uint256 deadline;
        uint256 totalAmount;
        uint256 index;
    }

    Parameters2 s_parameters2 = Parameters2({
        collateralToBorrowRatio: 1.5 ether,
        minBorrowAmount: 10 ether,
        interestRate: 0.01 ether,
        partialRepaymentAllowed: false,
        deadline: block.timestamp + 365 days,
        totalAmount: 20 ether,
        index: 1
    });
    DeployPool s_deployPool;
    Pool s_pool;
    ERC20Mock s_lenderToken;
    ERC20Mock s_collateralToken;
    address constant USER1 = address(0x01);
    address constant USER2 = address(0x02);
    address constant USER3 = address(0x03);
    address constant RANDOM_USER = address(0xF);
    uint256 constant INITIAL_TOKEN_BALANCE = 10000 ether;

    function setUp() external {
        s_deployPool = new DeployPool();
        (s_pool, s_lenderToken, s_collateralToken) = s_deployPool.run();
        console2.log("msg.sender:           ", msg.sender);
        console2.log("this:                 ", address(this));
        console2.log("DeployPool:           ", address(s_deployPool));
        console2.log("Pool:                 ", address(s_pool));
        console2.log("Lender Token:         ", address(s_lenderToken));
        console2.log("Collateral Token:     ", address(s_collateralToken));
        s_lenderToken.mint(USER1, INITIAL_TOKEN_BALANCE);
        s_collateralToken.mint(USER2, INITIAL_TOKEN_BALANCE);
    }

    function testOwnerIsSetCorrectly() external view {
        assert(s_pool.getOwner() == address(msg.sender));
    }

    function testAddTokenToWhitelist() external {
        _addTokenToWhitelist(address(s_lenderToken));
    }

    function testChangeOwner() external {
        vm.prank(msg.sender);
        s_pool.changeOwner(USER3);
        assert(s_pool.getOwner() != USER3);

        vm.expectRevert(Errors.CoolDownPeriodNotYetOver.selector);
        vm.prank(USER3);
        s_pool.acceptOwnership();

        vm.warp(block.timestamp + 2 days);
        vm.prank(USER3);
        s_pool.acceptOwnership();
        assert(s_pool.getOwner() == USER3);
    }

    function testLendNewLoanLenderTokenIsNotWhitelisted() external {
        // use a lender token which is not in the whitelist
        vm.expectRevert(abi.encodeWithSelector(Errors.LenderTokenIsNotWhitelisted.selector, address(s_lenderToken)));
        vm.prank(USER1);
        s_pool.lendNew(
            address(s_lenderToken),
            address(s_collateralToken),
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount
        );
    }

    function testLendNewLoanCollateralTokenIsNotWhitelisted() external {
        // use a collateral token which is not in the whitelist
        _addTokenToWhitelist(address(s_lenderToken));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CollateralTokenIsNotWhitelisted.selector, address(s_collateralToken))
        );
        vm.prank(USER1);
        s_pool.lendNew(
            address(s_lenderToken),
            address(s_collateralToken),
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount
        );
    }

    function testDeadlineShouldBeInTheFuture() external {
        _addTokenToWhitelist(address(s_lenderToken));
        _addTokenToWhitelist(address(s_collateralToken));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DeadlineShouldBeInTheFuture.selector, block.timestamp, block.timestamp)
        );
        vm.prank(USER1);
        s_pool.lendNew(
            address(s_lenderToken), //set random address for lender token
            address(s_collateralToken),
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            block.timestamp,
            s_parameters.totalAmount
        );
    }

    function testTotalAmountShouldBeGreaterThanZero() external {
        _addTokenToWhitelist(address(s_lenderToken));
        _addTokenToWhitelist(address(s_collateralToken));
        vm.expectRevert(abi.encodeWithSelector(Errors.TotalAmountShouldBePositive.selector, 0));
        vm.prank(USER1);
        s_pool.lendNew(
            address(s_lenderToken),
            address(s_collateralToken),
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            0 ether
        );
    }

    function testTotalAmountShouldBeGtMinBorrowAmount() external {
        _addTokenToWhitelist(address(s_lenderToken));
        _addTokenToWhitelist(address(s_collateralToken));
        s_parameters.totalAmount = s_parameters.minBorrowAmount - 1;
        vm.expectRevert(abi.encodeWithSelector(Errors.TotalAmountShouldBePositive.selector, s_parameters.totalAmount));
        vm.prank(USER1);
        s_pool.lendNew(
            address(s_lenderToken),
            address(s_collateralToken),
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount
        );
    }

    function testLenderTokenAdded() external {
        _addANewlenderPoolAndVerify(s_parameters);
    }

    function testNonLenderCallsCancelLending() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        vm.expectRevert(Errors.OnlyOriginalLenderCanCancelLending.selector);
        vm.prank(USER2);
        s_pool.cancelLending(maxPoolIndex, false);
    }

    function testLenderCallsCancelLendingKeepMapping() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        uint256 user1BeforeBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolBeforeBalance = s_lenderToken.balanceOf(address(s_pool));
        vm.prank(USER1);
        s_pool.cancelLending(maxPoolIndex, false);
        uint256 user1AfterBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolAfterBalance = s_lenderToken.balanceOf(address(s_pool));
        assert(user1AfterBalance == user1BeforeBalance + s_parameters.totalAmount);
        assert(poolAfterBalance == poolBeforeBalance - s_parameters.totalAmount);
        // verify that the mapping is updated successfully
        Structs.LendedPool memory lendedPool = s_pool.getLenderPools(maxPoolIndex);
        assert(lendedPool.lender == USER1);
        assert(lendedPool.initialAmountToLend == 0);
        assert(lendedPool.totalRemainingAmountToLend == 0);
        assert(s_pool.getLenderPoolsLength() == maxPoolIndex);
    }

    function testLenderCallsCancelLendingDeleteMapping() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        uint256 user1BeforeBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolBeforeBalance = s_lenderToken.balanceOf(address(s_pool));
        vm.prank(USER1);
        s_pool.cancelLending(maxPoolIndex, true);
        uint256 user1AfterBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolAfterBalance = s_lenderToken.balanceOf(address(s_pool));
        assert(user1AfterBalance == user1BeforeBalance + s_parameters.totalAmount);
        assert(poolAfterBalance == poolBeforeBalance - s_parameters.totalAmount);
        // verify that the mapping is updated successfully
        Structs.LendedPool memory lendedPool = s_pool.getLenderPools(maxPoolIndex);
        assert(lendedPool.lender == address(0));
        assert(s_pool.getLenderPoolsLength() == maxPoolIndex - 1);
    }

    function testNonLenderCallingLendUpdate() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        vm.expectRevert(Errors.OnlyOriginalLenderCanUpdateLendedPool.selector);
        vm.prank(USER2);
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
    }

    function testLendUpdateCBRatio() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CBRatioShouldBeSameOrSmall.selector, 1.51 ether, s_parameters.collateralToBorrowRatio
            )
        );
        s_parameters.totalAmount = 0 ether;
        vm.prank(USER1);
        s_pool.lendUpdate( //this reverts
            1.51 ether, //collateralToBorrowRatio
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        vm.prank(USER1);
        s_pool.lendUpdate( //this will succeed
            1.49 ether, //collateralToBorrowRatio
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        assert(s_pool.getLenderPools(maxPoolIndex).collateralToBorrowRatio == 1.49 ether);
    }

    function testLendUpdateMinBorrowAmt() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        s_parameters.totalAmount = 0 ether;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MinBAmtShouldBeSameOrSmall.selector, 11 ether, s_parameters.minBorrowAmount)
        );
        vm.prank(USER1);
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            11 ether, //minBorrowAmount
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        //this one will work
        vm.prank(USER1);
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            9 ether, //minBorrowAmount
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        assert(s_pool.getLenderPools(maxPoolIndex).minBorrowAmount == 9 ether);
    }

    function testLendUpdateInterestRate() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        s_parameters.totalAmount = 0 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InterestRateShouldBeSameOrSmaller.selector, 0.02 ether, s_parameters.interestRate
            )
        );
        vm.prank(USER1);
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            0.02 ether, //interestRate
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        // this one will work
        vm.prank(USER1);
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            0.009 ether, //interestRate
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        assert(s_pool.getLenderPools(maxPoolIndex).interestRate == 0.009 ether);
    }

    function testLendUpdateRepaymentMode() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        s_parameters.totalAmount = 0 ether;
        vm.prank(USER1);
        //this works
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            true, //partialRepaymentAllowed
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
    }

    function testLendUpdateRepaymentMode2() external {
        s_parameters.partialRepaymentAllowed = true;
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        s_parameters.totalAmount = 0 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PartialRepaymentShouldBeSameOrTrue.selector, false, s_parameters.partialRepaymentAllowed
            )
        );
        vm.prank(USER1);
        //this wont  work
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            false, //partialRepaymentAllowed
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
    }

    function testLendUpdateDeadline() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        s_parameters.totalAmount = 0 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DeadlineShouldBeSameOrGreater.selector, s_parameters.deadline - 1 seconds, s_parameters.deadline
            )
        );
        vm.prank(USER1);
        s_pool.lendUpdate( // doesnt work
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline - 1 seconds,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        vm.prank(USER1);
        s_pool.lendUpdate( // this works
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline + 1 seconds,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        assert(s_pool.getLenderPools(maxPoolIndex).deadline == s_parameters.deadline + 1 seconds);
    }

    function testAddMoreTokensToLenderPool() external {
        _addANewlenderPoolAndVerify(s_parameters);
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        assert(maxPoolIndex == 1);
        s_parameters.totalAmount = 5 ether;
        uint256 user1BeforeBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolBeforeBalance = s_lenderToken.balanceOf(address(s_pool));
        vm.startPrank(USER1);
        s_lenderToken.approve(address(s_pool), s_parameters.totalAmount);
        s_pool.lendUpdate(
            s_parameters.collateralToBorrowRatio,
            s_parameters.minBorrowAmount,
            s_parameters.interestRate,
            s_parameters.partialRepaymentAllowed,
            s_parameters.deadline,
            s_parameters.totalAmount,
            maxPoolIndex
        );
        vm.stopPrank();
        uint256 user1AfterBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolAfterBalance = s_lenderToken.balanceOf(address(s_pool));
        assert(user1AfterBalance == user1BeforeBalance - s_parameters.totalAmount);
        assert(poolAfterBalance == poolBeforeBalance + s_parameters.totalAmount);
        assert(s_pool.getLenderPools(maxPoolIndex).initialAmountToLend == poolAfterBalance);
        assert(s_pool.getLenderPools(maxPoolIndex).totalRemainingAmountToLend == poolAfterBalance);
    }

    /**
     * Internal Functions   ***************
     */
    /**
     *
     */
    function _addTokenToWhitelist(address token) internal {
        vm.prank(msg.sender);
        s_pool.addTokenToWhitelist(token);
        assert(s_pool.isTokenWhitelisted(token));
    }

    function _addANewlenderPoolAndVerify(Parameters memory p) internal {
        _addTokenToWhitelist(address(s_lenderToken));
        _addTokenToWhitelist(address(s_collateralToken));
        uint256 user1BeforeBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolBeforeBalance = s_lenderToken.balanceOf(address(s_pool));
        vm.startPrank(USER1);
        s_lenderToken.approve(address(s_pool), p.totalAmount);
        s_pool.lendNew(
            address(s_lenderToken), //set random address for lender token
            address(s_collateralToken),
            p.collateralToBorrowRatio,
            p.minBorrowAmount,
            p.interestRate,
            p.partialRepaymentAllowed,
            p.deadline,
            p.totalAmount
        );
        vm.stopPrank();
        uint256 user1AfterBalance = s_lenderToken.balanceOf(USER1);
        uint256 poolAfterBalance = s_lenderToken.balanceOf(address(s_pool));
        assert(user1AfterBalance == user1BeforeBalance - p.totalAmount);
        assert(poolAfterBalance == poolBeforeBalance + p.totalAmount);
        // verify that the mapping is created successfully
        uint256 maxPoolIndex = s_pool.getLenderPoolsLength();
        Structs.LendedPool memory lendedPool = s_pool.getLenderPools(maxPoolIndex);
        assert(lendedPool.lender == USER1);
        assert(lendedPool.lenderToken == address(s_lenderToken));
        assert(lendedPool.collateralToken == address(s_collateralToken));
        assert(lendedPool.collateralToBorrowRatio == p.collateralToBorrowRatio);
        assert(lendedPool.minBorrowAmount == p.minBorrowAmount);
        assert(lendedPool.interestRate == p.interestRate);
        assert(lendedPool.partialRepaymentAllowed == p.partialRepaymentAllowed);
        assert(lendedPool.deadline == p.deadline);
        assert(lendedPool.initialAmountToLend == p.totalAmount);
        assert(lendedPool.totalRemainingAmountToLend == p.totalAmount);
    }
}
