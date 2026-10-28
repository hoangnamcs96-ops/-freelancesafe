// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FreelanceEscrowTestBase} from "./FreelanceEscrow.Base.t.sol";
import {FreelanceEscrow} from "../FreelanceEscrow.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ToggleToken, FeeOnTransferToken, ReentrantToken} from "../test-helpers/EscrowMocks.sol";

/// Token-behaviour tests: allowance/balance failures, failing transfers, fee-on-transfer, reentrancy.
contract FreelanceEscrowTokensTest is FreelanceEscrowTestBase {
    // ---------------------------------------------------------------- 9. allowance / balance
    function test_Fund_InsufficientAllowanceRevertsAndKeepsCreated() public {
        uint256 id = _create();
        vm.prank(client);
        token.approve(address(escrow), AMOUNT - 1);
        uint256 cBefore = token.balanceOf(client);
        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(escrow), AMOUNT - 1, AMOUNT
            )
        );
        escrow.fund(id);
        FreelanceEscrow.Escrow memory e = escrow.getEscrow(id);
        assertEq(uint8(e.status), uint8(FreelanceEscrow.Status.Created));
        assertEq(e.fundedAt, 0);
        assertEq(token.balanceOf(client), cBefore);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function test_Fund_ZeroAllowanceReverts() public {
        uint256 id = _create();
        vm.prank(client);
        token.approve(address(escrow), 0);
        vm.prank(client);
        vm.expectRevert();
        escrow.fund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Created));
    }

    function test_Fund_InsufficientBalanceRevertsAndKeepsCreated() public {
        address poor = makeAddr("poor");
        token.mint(poor, AMOUNT - 1);
        vm.prank(poor);
        token.approve(address(escrow), type(uint256).max);
        vm.prank(poor);
        uint256 id = escrow.createEscrow(freelancer, AMOUNT, 0, "t", "");
        vm.prank(poor);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, poor, AMOUNT - 1, AMOUNT)
        );
        escrow.fund(id);
        FreelanceEscrow.Escrow memory e = escrow.getEscrow(id);
        assertEq(uint8(e.status), uint8(FreelanceEscrow.Status.Created));
        assertEq(e.fundedAt, 0);
        assertEq(token.balanceOf(poor), AMOUNT - 1);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function test_Fund_SucceedsAfterTopUpFollowingFailure() public {
        address poor = makeAddr("poor");
        token.mint(poor, AMOUNT - 1);
        vm.startPrank(poor);
        token.approve(address(escrow), type(uint256).max);
        uint256 id = escrow.createEscrow(freelancer, AMOUNT, 0, "t", "");
        vm.expectRevert();
        escrow.fund(id);
        vm.stopPrank();
        token.mint(poor, 1);
        vm.prank(poor);
        escrow.fund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Funded));
    }

    // ---------------------------------------------------------------- 10. failing transfers
    function _toggleSetup() internal returns (FreelanceEscrow e, ToggleToken t, uint256 id) {
        t = new ToggleToken();
        e = new FreelanceEscrow(address(t));
        t.mint(client, 1_000_000e6);
        vm.prank(client);
        t.approve(address(e), type(uint256).max);
        id = _createWith(e, AMOUNT, uint64(block.timestamp + DEADLINE_OFFSET));
    }

    function test_Release_TokenTransferRevertsLeavesFunded() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        vm.prank(client);
        e.fund(id);
        t.setTransferMode(2);
        vm.prank(client);
        vm.expectRevert(bytes("transfer disabled"));
        e.release(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(t.balanceOf(address(e)), AMOUNT);
        assertEq(t.balanceOf(freelancer), 0);
        // recovers when token works again
        t.setTransferMode(0);
        vm.prank(client);
        e.release(id);
        assertEq(t.balanceOf(freelancer), AMOUNT);
    }

    function test_Release_TokenTransferReturnsFalseLeavesFunded() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        vm.prank(client);
        e.fund(id);
        t.setTransferMode(1);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(t)));
        e.release(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(t.balanceOf(address(e)), AMOUNT);
    }

    function test_RefundByFreelancer_TokenTransferRevertsLeavesFunded() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        vm.prank(client);
        e.fund(id);
        t.setTransferMode(2);
        vm.prank(freelancer);
        vm.expectRevert(bytes("transfer disabled"));
        e.refundByFreelancer(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(t.balanceOf(address(e)), AMOUNT);
    }

    function test_RefundByFreelancer_TokenTransferReturnsFalseLeavesFunded() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        vm.prank(client);
        e.fund(id);
        t.setTransferMode(1);
        vm.prank(freelancer);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(t)));
        e.refundByFreelancer(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_ClaimExpiredRefund_TokenTransferFailsLeavesFunded() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        vm.prank(client);
        e.fund(id);
        skip(DEADLINE_OFFSET + 1);
        t.setTransferMode(1);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(t)));
        e.claimExpiredRefund(id);
        t.setTransferMode(2);
        vm.prank(client);
        vm.expectRevert(bytes("transfer disabled"));
        e.claimExpiredRefund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(t.balanceOf(address(e)), AMOUNT);
    }

    function test_Fund_TransferFromReturnsFalseLeavesCreated() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        t.setTransferFromMode(1);
        uint256 cBefore = t.balanceOf(client);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(t)));
        e.fund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Created));
        assertEq(e.getEscrow(id).fundedAt, 0);
        assertEq(t.balanceOf(client), cBefore);
    }

    function test_Fund_TransferFromRevertsLeavesCreated() public {
        (FreelanceEscrow e, ToggleToken t, uint256 id) = _toggleSetup();
        t.setTransferFromMode(2);
        vm.prank(client);
        vm.expectRevert(bytes("transferFrom disabled"));
        e.fund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Created));
    }

    function test_Fund_FeeOnTransferTokenRevertsUnexpectedAmount() public {
        FeeOnTransferToken fee = new FeeOnTransferToken();
        FreelanceEscrow e = new FreelanceEscrow(address(fee));
        fee.mint(client, 1_000_000e6);
        vm.prank(client);
        fee.approve(address(e), type(uint256).max);
        uint256 id = _createWith(e, AMOUNT, 0);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.UnexpectedTransferAmount.selector);
        e.fund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Created));
        assertEq(e.getEscrow(id).fundedAt, 0);
        assertEq(fee.balanceOf(client), 1_000_000e6);
        assertEq(fee.balanceOf(address(e)), 0);
    }

    // ---------------------------------------------------------------- 10. reentrancy
    function _reentrantSetup() internal returns (FreelanceEscrow e, ReentrantToken t, uint256 id) {
        t = new ReentrantToken();
        e = new FreelanceEscrow(address(t));
        t.mint(client, 1_000_000e6);
        vm.prank(client);
        t.approve(address(e), type(uint256).max);
        id = _createWith(e, AMOUNT, uint64(block.timestamp + DEADLINE_OFFSET));
    }

    function test_Reentrancy_ReleaseReenteringReleaseReverts() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        vm.prank(client);
        e.fund(id);
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.release, (id)), true);
        vm.prank(client);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.release(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(t.balanceOf(address(e)), AMOUNT);
        assertEq(t.balanceOf(freelancer), 0);
    }

    function test_Reentrancy_ReleaseReenteringRefundReverts() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        vm.prank(client);
        e.fund(id);
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.refundByFreelancer, (id)), true);
        vm.prank(client);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.release(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_Reentrancy_RefundReenteringReleaseReverts() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        vm.prank(client);
        e.fund(id);
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.release, (id)), true);
        vm.prank(freelancer);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.refundByFreelancer(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(t.balanceOf(address(e)), AMOUNT);
    }

    function test_Reentrancy_ClaimExpiredRefundReenteringReverts() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        vm.prank(client);
        e.fund(id);
        skip(DEADLINE_OFFSET + 1);
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.claimExpiredRefund, (id)), true);
        vm.prank(client);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.claimExpiredRefund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_Reentrancy_FundReenteringFundReverts() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.fund, (id)), true);
        vm.prank(client);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.fund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Created));
        assertEq(t.balanceOf(address(e)), 0);
    }

    function test_Reentrancy_FundReenteringReleaseReverts() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.release, (id)), true);
        vm.prank(client);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.fund(id);
        assertEq(uint8(e.getEscrow(id).status), uint8(FreelanceEscrow.Status.Created));
    }

    /// Token swallows the failed re-entry: outer call completes, re-entry provably failed, no double payout.
    function test_Reentrancy_SwallowedReentryFailsAndNoDoublePayout() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        vm.prank(client);
        e.fund(id);
        uint256 id2 = _createWith(e, AMOUNT, 0);
        vm.prank(client);
        e.fund(id2);
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.release, (id)), false);
        vm.prank(client);
        e.release(id);
        assertTrue(t.hookRan());
        assertFalse(t.lastSuccess());
        assertEq(bytes4(t.lastReturn()), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(t.balanceOf(freelancer), AMOUNT);
        assertEq(t.balanceOf(address(e)), AMOUNT); // second escrow's funds untouched
        assertEq(uint8(e.getEscrow(id2).status), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_Reentrancy_GuardResetsAfterRevertedAttempt() public {
        (FreelanceEscrow e, ReentrantToken t, uint256 id) = _reentrantSetup();
        vm.prank(client);
        e.fund(id);
        t.arm(address(e), abi.encodeCall(FreelanceEscrow.release, (id)), true);
        vm.prank(client);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        e.release(id);
        t.disarm();
        vm.prank(client);
        e.release(id);
        assertEq(t.balanceOf(freelancer), AMOUNT);
    }
}
