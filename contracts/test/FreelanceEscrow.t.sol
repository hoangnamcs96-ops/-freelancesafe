// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FreelanceEscrowTestBase} from "./FreelanceEscrow.Base.t.sol";
import {FreelanceEscrow} from "../FreelanceEscrow.sol";
import {MockERC20} from "../test-helpers/EscrowMocks.sol";

/// Happy paths: construction, creation, fund, release, cancel, refunds, views.
contract FreelanceEscrowTest is FreelanceEscrowTestBase {
    // ---------------------------------------------------------------- constructor
    function test_Constructor_StoresTokenAndStartsEmpty() public view {
        assertEq(address(escrow.token()), address(token));
        assertEq(escrow.escrowCount(), 0);
    }

    function test_Constructor_ZeroTokenReverts() public {
        vm.expectRevert(FreelanceEscrow.ZeroAddress.selector);
        new FreelanceEscrow(address(0));
    }

    function test_Constructor_TokenWithoutCodeReverts() public {
        vm.expectRevert(FreelanceEscrow.ZeroAddress.selector);
        new FreelanceEscrow(makeAddr("eoa"));
    }

    // ---------------------------------------------------------------- 1. creation
    function test_CreateEscrow_StoresAllFields() public {
        uint64 dl = uint64(block.timestamp + 7 days);
        vm.prank(client);
        uint256 id = escrow.createEscrow(freelancer, AMOUNT, dl, "Title", "Desc");
        assertEq(id, 1);
        assertEq(escrow.escrowCount(), 1);
        FreelanceEscrow.Escrow memory e = escrow.getEscrow(id);
        assertEq(e.client, client);
        assertEq(e.freelancer, freelancer);
        assertEq(e.amount, AMOUNT);
        assertEq(e.createdAt, uint64(block.timestamp));
        assertEq(e.deadline, dl);
        assertEq(e.fundedAt, 0);
        assertEq(uint8(e.status), uint8(FreelanceEscrow.Status.Created));
        assertEq(e.title, "Title");
        assertEq(e.description, "Desc");
    }

    function test_CreateEscrow_EmitsEscrowCreated() public {
        uint64 dl = uint64(block.timestamp + 7 days);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit FreelanceEscrow.EscrowCreated(1, client, freelancer, AMOUNT, dl, "Title", "Desc");
        vm.prank(client);
        escrow.createEscrow(freelancer, AMOUNT, dl, "Title", "Desc");
    }

    function test_CreateEscrow_SequentialIdsAcrossCallers() public {
        vm.prank(client);
        assertEq(escrow.createEscrow(freelancer, 1, 0, "a", ""), 1);
        vm.prank(stranger);
        assertEq(escrow.createEscrow(freelancer, 2, 0, "b", ""), 2);
        vm.prank(client);
        assertEq(escrow.createEscrow(stranger, 3, 0, "c", ""), 3);
        assertEq(escrow.escrowCount(), 3);
        assertEq(escrow.getEscrow(2).client, stranger);
    }

    function test_CreateEscrow_NoDeadlineAllowed() public {
        uint256 id = _createNoDeadline();
        assertEq(escrow.getEscrow(id).deadline, 0);
    }

    function test_CreateEscrow_BoundaryLengthsAccepted() public {
        vm.prank(client);
        uint256 id = escrow.createEscrow(freelancer, 1, 0, _str(100), _str(1000));
        assertEq(bytes(escrow.getEscrow(id).title).length, 100);
        assertEq(bytes(escrow.getEscrow(id).description).length, 1000);
    }

    function test_CreateEscrow_FreelancerAboveSystemRangeAccepted() public {
        vm.prank(client);
        uint256 id = escrow.createEscrow(address(uint160(0x10000)), 1, 0, "t", "");
        assertEq(id, 1);
    }

    // ---------------------------------------------------------------- 2. fund
    function test_Fund_MovesTokensSetsFundedAndFundedAt() public {
        uint256 id = _create();
        uint256 cBefore = token.balanceOf(client);
        skip(5 hours);
        vm.prank(client);
        escrow.fund(id);
        assertEq(token.balanceOf(address(escrow)), AMOUNT);
        assertEq(token.balanceOf(client), cBefore - AMOUNT);
        FreelanceEscrow.Escrow memory e = escrow.getEscrow(id);
        assertEq(uint8(e.status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(e.fundedAt, uint64(block.timestamp));
    }

    function test_Fund_EmitsEscrowFunded() public {
        uint256 id = _create();
        vm.expectEmit(true, true, false, true, address(escrow));
        emit FreelanceEscrow.EscrowFunded(id, client, AMOUNT);
        vm.prank(client);
        escrow.fund(id);
    }

    function test_Fund_AllowedAfterDeadline() public {
        uint256 id = _create();
        skip(DEADLINE_OFFSET + 1 days);
        vm.prank(client);
        escrow.fund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Funded));
    }

    // ---------------------------------------------------------------- 3. release
    function test_Release_PaysFreelancerAndMarksReleased() public {
        uint256 id = _createFunded();
        vm.prank(client);
        escrow.release(id);
        assertEq(token.balanceOf(freelancer), AMOUNT);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Released));
    }

    function test_Release_EmitsPaymentReleased() public {
        uint256 id = _createFunded();
        vm.expectEmit(true, true, false, true, address(escrow));
        emit FreelanceEscrow.PaymentReleased(id, freelancer, AMOUNT);
        vm.prank(client);
        escrow.release(id);
    }

    function test_Release_ClientCanStillReleaseAfterDeadline() public {
        uint256 id = _createFunded();
        skip(DEADLINE_OFFSET + 365 days);
        vm.prank(client);
        escrow.release(id);
        assertEq(token.balanceOf(freelancer), AMOUNT);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Released));
    }

    function test_Release_NoDeadlineEscrowAfterDelay() public {
        uint256 id = _createFundedNoDeadline();
        skip(NO_DEADLINE_DELAY + 100 days);
        vm.prank(client);
        escrow.release(id);
        assertEq(token.balanceOf(freelancer), AMOUNT);
    }

    // ---------------------------------------------------------------- 7. cancel
    function test_Cancel_ByClientBeforeFunding() public {
        uint256 id = _create();
        vm.expectEmit(true, true, false, false, address(escrow));
        emit FreelanceEscrow.EscrowCancelled(id, client);
        vm.prank(client);
        escrow.cancel(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Cancelled));
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    // ---------------------------------------------------------------- refunds (happy)
    function test_RefundByFreelancer_ImmediatelyAfterFunding() public {
        uint256 id = _createFunded();
        uint256 cBefore = token.balanceOf(client);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit FreelanceEscrow.EscrowRefunded(id, client, AMOUNT, freelancer);
        vm.prank(freelancer);
        escrow.refundByFreelancer(id);
        assertEq(token.balanceOf(client), cBefore + AMOUNT);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Refunded));
    }

    function test_RefundByFreelancer_AllowedNoDeadlineAndAfterDeadline() public {
        uint256 a = _createFundedNoDeadline();
        uint256 b = _createFunded();
        skip(DEADLINE_OFFSET + 1);
        vm.startPrank(freelancer);
        escrow.refundByFreelancer(a);
        escrow.refundByFreelancer(b);
        vm.stopPrank();
        assertEq(uint8(_status(a)), uint8(FreelanceEscrow.Status.Refunded));
        assertEq(uint8(_status(b)), uint8(FreelanceEscrow.Status.Refunded));
    }

    function test_ClaimExpiredRefund_ClientStrictlyAfterDeadline() public {
        uint256 id = _createFunded();
        uint256 dl = escrow.getEscrow(id).deadline;
        vm.warp(dl + 1);
        uint256 cBefore = token.balanceOf(client);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit FreelanceEscrow.EscrowRefunded(id, client, AMOUNT, client);
        vm.prank(client);
        escrow.claimExpiredRefund(id);
        assertEq(token.balanceOf(client), cBefore + AMOUNT);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Refunded));
    }

    function test_ClaimExpiredRefund_NoDeadlineStrictlyAfter180Days() public {
        uint256 id = _createFundedNoDeadline();
        uint256 fundedAt = escrow.getEscrow(id).fundedAt;
        vm.warp(fundedAt + NO_DEADLINE_DELAY + 1);
        vm.prank(client);
        escrow.claimExpiredRefund(id);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Refunded));
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    // ---------------------------------------------------------------- views
    function test_GetEscrow_ZeroAndUnknownRevert() public {
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.getEscrow(0);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.getEscrow(1);
        _create();
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.getEscrow(2);
    }

    function _make(uint256 n) internal {
        for (uint256 i = 0; i < n; ++i) {
            _create();
        }
    }

    function test_GetEscrows_StartZeroReverts() public {
        _make(2);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.getEscrows(0, 1);
    }

    function test_GetEscrows_StartZeroRevertsEvenWithZeroCountOrEmpty() public {
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.getEscrows(0, 0);
    }

    function test_GetEscrows_ReturnsPageInOrder() public {
        _make(5);
        FreelanceEscrow.Escrow[] memory r = escrow.getEscrows(2, 3);
        assertEq(r.length, 3);
        assertEq(r[0].amount, AMOUNT);
        // distinguish via status: fund id 3 and re-read
        vm.prank(client);
        escrow.fund(3);
        r = escrow.getEscrows(2, 3);
        assertEq(uint8(r[0].status), uint8(FreelanceEscrow.Status.Created));
        assertEq(uint8(r[1].status), uint8(FreelanceEscrow.Status.Funded));
        assertEq(uint8(r[2].status), uint8(FreelanceEscrow.Status.Created));
    }

    function test_GetEscrows_BeyondRangeReturnsEmpty() public {
        _make(3);
        assertEq(escrow.getEscrows(4, 10).length, 0);
        assertEq(escrow.getEscrows(type(uint256).max, 1).length, 0);
    }

    function test_GetEscrows_ZeroCountReturnsEmpty() public {
        _make(3);
        assertEq(escrow.getEscrows(1, 0).length, 0);
    }

    function test_GetEscrows_ClampsOversizedCount() public {
        _make(3);
        assertEq(escrow.getEscrows(2, 100).length, 2);
        assertEq(escrow.getEscrows(1, 3).length, 3);
        assertEq(escrow.getEscrows(3, 2).length, 1);
    }

    function test_GetEscrows_HugeCountNoOverflow() public {
        _make(3);
        assertEq(escrow.getEscrows(1, type(uint256).max).length, 3);
        assertEq(escrow.getEscrows(3, type(uint256).max).length, 1);
    }

    function test_GetEscrows_EmptyContractReturnsEmpty() public view {
        assertEq(escrow.getEscrows(1, 5).length, 0);
    }

    // ---------------------------------------------------------------- 8. isRefundable across states
    function test_IsRefundable_AcrossAllStates() public {
        // Created
        uint256 created = _create();
        assertFalse(escrow.isRefundable(created));
        // Cancelled
        uint256 cancelled = _create();
        vm.prank(client);
        escrow.cancel(cancelled);
        skip(DEADLINE_OFFSET + 1);
        assertFalse(escrow.isRefundable(cancelled));
        assertFalse(escrow.isRefundable(created));

        // Funded with deadline: not before, not at, yes after
        uint256 dl = uint64(block.timestamp + 10 days);
        vm.prank(client);
        uint256 funded = escrow.createEscrow(freelancer, AMOUNT, uint64(dl), "t", "");
        vm.prank(client);
        escrow.fund(funded);
        assertFalse(escrow.isRefundable(funded));
        vm.warp(dl);
        assertFalse(escrow.isRefundable(funded));
        vm.warp(dl + 1);
        assertTrue(escrow.isRefundable(funded));

        // Released / Refunded -> false even when time passed
        uint256 rel = _createFunded();
        vm.prank(client);
        escrow.release(rel);
        uint256 ref = _createFunded();
        vm.prank(freelancer);
        escrow.refundByFreelancer(ref);
        skip(1000 days);
        assertFalse(escrow.isRefundable(rel));
        assertFalse(escrow.isRefundable(ref));
    }

    function test_IsRefundable_NoDeadlineBoundary() public {
        uint256 id = _createFundedNoDeadline();
        uint256 f = escrow.getEscrow(id).fundedAt;
        assertFalse(escrow.isRefundable(id));
        vm.warp(f + NO_DEADLINE_DELAY - 1);
        assertFalse(escrow.isRefundable(id));
        vm.warp(f + NO_DEADLINE_DELAY);
        assertFalse(escrow.isRefundable(id));
        vm.warp(f + NO_DEADLINE_DELAY + 1);
        assertTrue(escrow.isRefundable(id));
    }

    function test_IsRefundable_InvalidIdReverts() public {
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.isRefundable(0);
        vm.expectRevert(FreelanceEscrow.EscrowNotFound.selector);
        escrow.isRefundable(1);
    }

    // ---------------------------------------------------------------- native value
    function test_NoNativeValue_PlainSendReverts() public {
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        (bool ok,) = address(escrow).call{value: 1 ether}("");
        assertFalse(ok);
        assertEq(address(escrow).balance, 0);
    }

    function test_NoNativeValue_UnknownCalldataAndValueReverts() public {
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        (bool ok,) = address(escrow).call{value: 1 ether}(hex"deadbeef");
        assertFalse(ok);
        vm.prank(stranger);
        (ok,) = address(escrow).call(hex"deadbeef");
        assertFalse(ok);
        assertEq(address(escrow).balance, 0);
    }

    function test_NoNativeValue_PayableFreeFunctions() public {
        uint256 id = _create();
        vm.deal(client, 1 ether);
        vm.prank(client);
        (bool ok,) = address(escrow).call{value: 1}(abi.encodeCall(FreelanceEscrow.fund, (id)));
        assertFalse(ok);
        vm.prank(client);
        (ok,) = address(escrow).call{value: 1}(abi.encodeCall(FreelanceEscrow.cancel, (id)));
        assertFalse(ok);
        assertEq(address(escrow).balance, 0);
    }
}
