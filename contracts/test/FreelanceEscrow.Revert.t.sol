// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FreelanceEscrowTestBase} from "./FreelanceEscrow.Base.t.sol";
import {FreelanceEscrow} from "../FreelanceEscrow.sol";
import {GreedyFreelancer, IEscrowLike} from "../test-helpers/EscrowMocks.sol";

/// Revert paths: access control, invalid input, state machine, refund timing.
contract FreelanceEscrowRevertTest is FreelanceEscrowTestBase {
    function _inv(FreelanceEscrow.Status s) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(FreelanceEscrow.InvalidStatus.selector, s);
    }

    // ---------------------------------------------------------------- 4. unauthorized
    function test_Release_FreelancerReverts() public {
        uint256 id = _createFunded();
        vm.prank(freelancer);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.release(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_Release_StrangerReverts() public {
        uint256 id = _createFunded();
        vm.prank(stranger);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.release(id);
        assertEq(token.balanceOf(address(escrow)), AMOUNT);
    }

    function test_Release_UnfundedReverts() public {
        uint256 id = _create();
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Created));
        escrow.release(id);
    }

    function test_Release_NonexistentReverts() public {
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.release(1);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.release(0);
    }

    function test_Fund_NonClientReverts() public {
        uint256 id = _create();
        vm.prank(freelancer);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.fund(id);
        vm.prank(stranger);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.fund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Created));
    }

    function test_Cancel_NonClientReverts() public {
        uint256 id = _create();
        vm.prank(freelancer);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.cancel(id);
        vm.prank(stranger);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.cancel(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Created));
    }

    function test_RefundByFreelancer_NonFreelancerReverts() public {
        uint256 id = _createFunded();
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.NotFreelancer.selector);
        escrow.refundByFreelancer(id);
        vm.prank(stranger);
        vm.expectRevert(FreelanceEscrow.NotFreelancer.selector);
        escrow.refundByFreelancer(id);
        assertEq(token.balanceOf(address(escrow)), AMOUNT);
    }

    function test_ClaimExpiredRefund_NonClientReverts() public {
        uint256 id = _createFunded();
        skip(DEADLINE_OFFSET + 1);
        vm.prank(freelancer);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.claimExpiredRefund(id);
        vm.prank(stranger);
        vm.expectRevert(FreelanceEscrow.NotClient.selector);
        escrow.claimExpiredRefund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_RefundByFreelancer_UnfundedReverts() public {
        uint256 id = _create();
        vm.prank(freelancer);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Created));
        escrow.refundByFreelancer(id);
    }

    function test_ClaimExpiredRefund_UnfundedReverts() public {
        uint256 id = _create();
        skip(DEADLINE_OFFSET + 1);
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Created));
        escrow.claimExpiredRefund(id);
    }

    function test_AllMutators_NonexistentIdReverts() public {
        vm.startPrank(client);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.fund(99);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.cancel(99);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.claimExpiredRefund(99);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.refundByFreelancer(99);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 5. invalid inputs
    function _expectCreateRevert(address who, address fl, uint96 amt, uint64 dl, bytes4 err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        escrow.createEscrow(fl, amt, dl, "t", "");
    }

    function test_CreateEscrow_ZeroFreelancerReverts() public {
        _expectCreateRevert(client, address(0), AMOUNT, 0, FreelanceEscrow.ZeroAddress.selector);
    }

    function test_CreateEscrow_FreelancerIsClientReverts() public {
        _expectCreateRevert(client, client, AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
    }

    function test_CreateEscrow_FreelancerIsTokenReverts() public {
        _expectCreateRevert(client, address(token), AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
    }

    function test_CreateEscrow_FreelancerIsEscrowContractReverts() public {
        _expectCreateRevert(client, address(escrow), AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
    }

    function test_CreateEscrow_FreelancerPrecompileRangeReverts() public {
        _expectCreateRevert(client, address(uint160(1)), AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
        _expectCreateRevert(client, address(uint160(9)), AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
        _expectCreateRevert(client, address(uint160(0x100)), AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
        _expectCreateRevert(client, address(uint160(0xFFFF)), AMOUNT, 0, FreelanceEscrow.InvalidFreelancer.selector);
    }

    function test_CreateEscrow_FreelancerArcSystemEmitterReverts() public {
        _expectCreateRevert(
            client,
            0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE,
            AMOUNT,
            0,
            FreelanceEscrow.InvalidFreelancer.selector
        );
    }

    function test_CreateEscrow_ZeroAmountReverts() public {
        _expectCreateRevert(client, freelancer, 0, 0, FreelanceEscrow.InvalidAmount.selector);
    }

    function test_CreateEscrow_PastDeadlineReverts() public {
        _expectCreateRevert(
            client, freelancer, AMOUNT, uint64(block.timestamp - 1), FreelanceEscrow.InvalidDeadline.selector
        );
        _expectCreateRevert(client, freelancer, AMOUNT, 1, FreelanceEscrow.InvalidDeadline.selector);
    }

    function test_CreateEscrow_DeadlineEqualToNowReverts() public {
        _expectCreateRevert(
            client, freelancer, AMOUNT, uint64(block.timestamp), FreelanceEscrow.InvalidDeadline.selector
        );
    }

    function test_CreateEscrow_DeadlineOneSecondInFutureAccepted() public {
        vm.prank(client);
        uint256 id = escrow.createEscrow(freelancer, AMOUNT, uint64(block.timestamp + 1), "t", "");
        assertEq(id, 1);
    }

    function test_CreateEscrow_EmptyTitleReverts() public {
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.InvalidTitleLength.selector);
        escrow.createEscrow(freelancer, AMOUNT, 0, "", "desc");
    }

    function test_CreateEscrow_OversizeTitleReverts() public {
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.InvalidTitleLength.selector);
        escrow.createEscrow(freelancer, AMOUNT, 0, _str(101), "");
    }

    function test_CreateEscrow_OversizeDescriptionReverts() public {
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.InvalidDescriptionLength.selector);
        escrow.createEscrow(freelancer, AMOUNT, 0, "t", _str(1001));
    }

    function test_CreateEscrow_TitleLimitIsBytesNotCharacters() public {
        // 34 x 3-byte characters = 102 bytes > 100 though only 34 characters
        bytes memory b = new bytes(0);
        for (uint256 i = 0; i < 34; ++i) {
            b = bytes.concat(b, bytes(unicode"€"));
        }
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.InvalidTitleLength.selector);
        escrow.createEscrow(freelancer, AMOUNT, 0, string(b), "");
    }

    function test_CreateEscrow_FailedValidationDoesNotConsumeId() public {
        _expectCreateRevert(client, address(0), AMOUNT, 0, FreelanceEscrow.ZeroAddress.selector);
        assertEq(escrow.escrowCount(), 0);
        assertEq(_create(), 1);
    }

    function test_Fund_NonexistentIdReverts() public {
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.fund(1);
        _create();
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.fund(2);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.fund(0);
    }

    // ---------------------------------------------------------------- 6. double / cross terminal ops
    function test_Release_DoubleReleaseReverts() public {
        uint256 id = _createFunded();
        vm.startPrank(client);
        escrow.release(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Released));
        escrow.release(id);
        vm.stopPrank();
        assertEq(token.balanceOf(freelancer), AMOUNT);
    }

    function test_Release_AfterFreelancerRefundReverts() public {
        uint256 id = _createFunded();
        vm.prank(freelancer);
        escrow.refundByFreelancer(id);
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.release(id);
        assertEq(token.balanceOf(freelancer), 0);
    }

    function test_Release_AfterClientRefundReverts() public {
        uint256 id = _createFunded();
        skip(DEADLINE_OFFSET + 1);
        vm.startPrank(client);
        escrow.claimExpiredRefund(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.release(id);
        vm.stopPrank();
    }

    function test_Refund_AfterReleaseReverts() public {
        uint256 id = _createFunded();
        vm.prank(client);
        escrow.release(id);
        skip(DEADLINE_OFFSET + 1);
        vm.prank(freelancer);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Released));
        escrow.refundByFreelancer(id);
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Released));
        escrow.claimExpiredRefund(id);
        assertEq(token.balanceOf(freelancer), AMOUNT);
        assertEq(token.balanceOf(client), 1_000_000e6 - AMOUNT);
    }

    function test_Refund_DoubleFreelancerRefundReverts() public {
        uint256 id = _createFunded();
        vm.startPrank(freelancer);
        escrow.refundByFreelancer(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.refundByFreelancer(id);
        vm.stopPrank();
    }

    function test_Refund_DoubleClientRefundReverts() public {
        uint256 id = _createFunded();
        skip(DEADLINE_OFFSET + 1);
        vm.startPrank(client);
        escrow.claimExpiredRefund(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.claimExpiredRefund(id);
        vm.stopPrank();
        assertEq(token.balanceOf(client), 1_000_000e6);
    }

    function test_Refund_FreelancerThenClientRefundReverts() public {
        uint256 id = _createFunded();
        vm.prank(freelancer);
        escrow.refundByFreelancer(id);
        skip(DEADLINE_OFFSET + 1);
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.claimExpiredRefund(id);
    }

    function test_Fund_DoubleFundReverts() public {
        uint256 id = _createFunded();
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Funded));
        escrow.fund(id);
        assertEq(token.balanceOf(address(escrow)), AMOUNT);
    }

    function test_Fund_AfterReleaseOrRefundReverts() public {
        uint256 a = _createFunded();
        uint256 b = _createFunded();
        vm.prank(client);
        escrow.release(a);
        vm.prank(freelancer);
        escrow.refundByFreelancer(b);
        vm.startPrank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Released));
        escrow.fund(a);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.fund(b);
        vm.stopPrank();
    }

    function test_Release_ByGreedyFreelancerContractCannotRefundAfterPayment() public {
        GreedyFreelancer g = new GreedyFreelancer(IEscrowLike(address(escrow)));
        vm.prank(client);
        uint256 id = escrow.createEscrow(address(g), AMOUNT, 0, "t", "");
        vm.prank(client);
        escrow.fund(id);
        vm.prank(client);
        escrow.release(id);
        g.tryRefund(id);
        assertFalse(g.lastRefundOk());
        assertEq(token.balanceOf(address(g)), AMOUNT);
    }

    // ---------------------------------------------------------------- 7. cancel
    function test_Cancel_AfterFundingReverts() public {
        uint256 id = _createFunded();
        vm.prank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Funded));
        escrow.cancel(id);
        assertEq(token.balanceOf(address(escrow)), AMOUNT);
    }

    function test_Fund_AfterCancelReverts() public {
        uint256 id = _create();
        vm.startPrank(client);
        escrow.cancel(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Cancelled));
        escrow.fund(id);
        vm.stopPrank();
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function test_Cancel_DoubleCancelReverts() public {
        uint256 id = _create();
        vm.startPrank(client);
        escrow.cancel(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Cancelled));
        escrow.cancel(id);
        vm.stopPrank();
    }

    function test_Cancelled_ReleaseAndRefundsRevert() public {
        uint256 id = _create();
        vm.startPrank(client);
        escrow.cancel(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Cancelled));
        escrow.release(id);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Cancelled));
        escrow.claimExpiredRefund(id);
        vm.stopPrank();
        vm.prank(freelancer);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Cancelled));
        escrow.refundByFreelancer(id);
    }

    function test_Cancel_AfterReleaseOrRefundReverts() public {
        uint256 a = _createFunded();
        uint256 b = _createFunded();
        vm.prank(client);
        escrow.release(a);
        vm.prank(freelancer);
        escrow.refundByFreelancer(b);
        vm.startPrank(client);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Released));
        escrow.cancel(a);
        vm.expectRevert(_inv(FreelanceEscrow.Status.Refunded));
        escrow.cancel(b);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 8. refund timing
    function test_ClaimExpiredRefund_BeforeDeadlineReverts() public {
        uint256 id = _createFunded();
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);
        assertFalse(escrow.isRefundable(id));
    }

    function test_ClaimExpiredRefund_AtExactDeadlineReverts() public {
        uint256 id = _createFunded();
        vm.warp(escrow.getEscrow(id).deadline);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Funded));
    }

    function test_ClaimExpiredRefund_OneSecondBeforeDeadlineReverts() public {
        uint256 id = _createFunded();
        vm.warp(escrow.getEscrow(id).deadline - 1);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);
    }

    function test_ClaimExpiredRefund_NoDeadlineBeforeDelayReverts() public {
        uint256 id = _createFundedNoDeadline();
        skip(NO_DEADLINE_DELAY - 1);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);
    }

    function test_ClaimExpiredRefund_NoDeadlineAtExactDelayReverts() public {
        uint256 id = _createFundedNoDeadline();
        vm.warp(escrow.getEscrow(id).fundedAt + NO_DEADLINE_DELAY);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);
    }

    function test_ClaimExpiredRefund_NoDeadlineDelayCountsFromFundingNotCreation() public {
        uint256 id = _createNoDeadline();
        skip(NO_DEADLINE_DELAY + 10 days); // old escrow, funded late
        vm.prank(client);
        escrow.fund(id);
        skip(1 days);
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);
    }
}
