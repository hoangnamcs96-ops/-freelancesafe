// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FreelanceEscrowTestBase} from "./FreelanceEscrow.Base.t.sol";
import {FreelanceEscrow} from "../FreelanceEscrow.sol";
import {MockERC20} from "../test-helpers/EscrowMocks.sol";

contract FreelanceEscrowFuzzTest is FreelanceEscrowTestBase {
    function _fuzzDeadline(uint64 raw) internal view returns (uint64) {
        if (raw % 4 == 0) return 0;
        return uint64(block.timestamp + 1 + (raw % 1000 days));
    }

    function testFuzz_FundAndRelease_Conserves(uint96 amount, uint64 rawDeadline, uint32 wait) public {
        amount = uint96(bound(amount, 1, type(uint96).max));
        uint64 dl = _fuzzDeadline(rawDeadline);
        token.mint(client, amount);
        uint256 supply = token.totalSupply();
        uint256 cBefore = token.balanceOf(client);

        uint256 id = _createWith(escrow, amount, dl);
        vm.prank(client);
        escrow.fund(id);
        assertEq(token.balanceOf(address(escrow)), amount);
        assertEq(token.balanceOf(client), cBefore - amount);

        skip(wait); // release works at any time
        vm.prank(client);
        escrow.release(id);

        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(token.balanceOf(freelancer), amount);
        assertEq(token.balanceOf(client), cBefore - amount);
        assertEq(token.totalSupply(), supply);
        assertEq(uint8(_status(id)), uint8(FreelanceEscrow.Status.Released));
    }

    function testFuzz_FundAndFreelancerRefund_Conserves(uint96 amount, uint64 rawDeadline, uint32 wait) public {
        amount = uint96(bound(amount, 1, type(uint96).max));
        token.mint(client, amount);
        uint256 cBefore = token.balanceOf(client);
        uint256 id = _createWith(escrow, amount, _fuzzDeadline(rawDeadline));
        vm.prank(client);
        escrow.fund(id);
        skip(wait);
        vm.prank(freelancer);
        escrow.refundByFreelancer(id);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(token.balanceOf(client), cBefore);
        assertEq(token.balanceOf(freelancer), 0);
    }

    function testFuzz_ClientRefundTiming(uint96 amount, uint64 rawDeadline, uint32 offsetSeed) public {
        amount = uint96(bound(amount, 1, type(uint96).max));
        token.mint(client, amount);
        uint64 dl = _fuzzDeadline(rawDeadline);
        uint256 id = _createWith(escrow, amount, dl);
        vm.prank(client);
        escrow.fund(id);
        uint256 threshold = dl != 0 ? dl : block.timestamp + NO_DEADLINE_DELAY;

        // not refundable at or before threshold
        uint256 early = bound(offsetSeed, 0, threshold - block.timestamp);
        vm.warp(threshold - early);
        assertFalse(escrow.isRefundable(id));
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.DeadlineNotExpired.selector);
        escrow.claimExpiredRefund(id);

        // refundable strictly after
        vm.warp(threshold + 1 + (offsetSeed % 365 days));
        assertTrue(escrow.isRefundable(id));
        uint256 cBefore = token.balanceOf(client);
        vm.prank(client);
        escrow.claimExpiredRefund(id);
        assertEq(token.balanceOf(client), cBefore + amount);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertFalse(escrow.isRefundable(id));
    }

    function testFuzz_CreateEscrow_DeadlineValidation(uint64 deadline) public {
        vm.prank(client);
        if (deadline != 0 && deadline <= block.timestamp) {
            vm.expectRevert(FreelanceEscrow.InvalidDeadline.selector);
        }
        escrow.createEscrow(freelancer, AMOUNT, deadline, "t", "");
    }

    function testFuzz_CreateEscrow_PrecompileRangeRejected(uint16 low) public {
        vm.prank(client);
        vm.expectRevert(FreelanceEscrow.InvalidFreelancer.selector);
        escrow.createEscrow(address(uint160(low)) == address(0) ? address(1) : address(uint160(low)), AMOUNT, 0, "t", "");
    }

    function testFuzz_GetEscrows_Pagination(uint8 n, uint256 start, uint256 count) public {
        n = uint8(bound(n, 0, 12));
        for (uint256 i = 0; i < n; ++i) {
            _createWith(escrow, AMOUNT, 0);
        }
        start = bound(start, 1, type(uint256).max);
        FreelanceEscrow.Escrow[] memory r = escrow.getEscrows(start, count);
        uint256 expected;
        if (start <= n && count > 0) {
            uint256 avail = n - start + 1;
            expected = count < avail ? count : avail;
        }
        assertEq(r.length, expected);
    }
}

/// Handler driving random lifecycle actions; the client is the handler itself.
contract EscrowHandler is Test {
    FreelanceEscrow public escrow;
    MockERC20 public token;
    address public freelancer = address(0xF1EE0000);
    uint256 public created;

    constructor(FreelanceEscrow e, MockERC20 t) {
        escrow = e;
        token = t;
        token.approve(address(e), type(uint256).max);
    }

    function _id(uint256 seed) internal view returns (uint256) {
        return created == 0 ? 0 : bound(seed, 1, created);
    }

    function create(uint96 amount, uint64 dlSeed) external {
        amount = uint96(bound(amount, 1, 1_000_000e6));
        uint64 dl = dlSeed % 3 == 0 ? 0 : uint64(block.timestamp + 1 + (dlSeed % 60 days));
        token.mint(address(this), amount);
        escrow.createEscrow(freelancer, amount, dl, "t", "");
        created++;
    }

    function fund(uint256 seed) external {
        uint256 id = _id(seed);
        if (id == 0) return;
        try escrow.fund(id) {} catch {}
    }

    function release(uint256 seed) external {
        uint256 id = _id(seed);
        if (id == 0) return;
        try escrow.release(id) {} catch {}
    }

    function cancel(uint256 seed) external {
        uint256 id = _id(seed);
        if (id == 0) return;
        try escrow.cancel(id) {} catch {}
    }

    function claimExpiredRefund(uint256 seed) external {
        uint256 id = _id(seed);
        if (id == 0) return;
        try escrow.claimExpiredRefund(id) {} catch {}
    }

    function refundByFreelancer(uint256 seed) external {
        uint256 id = _id(seed);
        if (id == 0) return;
        vm.prank(freelancer);
        try escrow.refundByFreelancer(id) {} catch {}
    }

    function warp(uint32 secs) external {
        skip(bound(secs, 0, 120 days));
    }
}

contract FreelanceEscrowInvariantTest is FreelanceEscrowTestBase {
    EscrowHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new EscrowHandler(escrow, token);
        targetContract(address(handler));
        bytes4[] memory sels = new bytes4[](7);
        sels[6] = EscrowHandler.cancel.selector;
        sels[0] = EscrowHandler.create.selector;
        sels[1] = EscrowHandler.fund.selector;
        sels[2] = EscrowHandler.release.selector;
        sels[3] = EscrowHandler.claimExpiredRefund.selector;
        sels[4] = EscrowHandler.refundByFreelancer.selector;
        sels[5] = EscrowHandler.warp.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    /// PROPERTY: escrow token balance == sum of amounts of Funded escrows.
    function invariant_BalanceEqualsSumOfFundedEscrows() public view {
        uint256 n = escrow.escrowCount();
        uint256 sum;
        if (n > 0) {
            FreelanceEscrow.Escrow[] memory all = escrow.getEscrows(1, n);
            for (uint256 i = 0; i < all.length; ++i) {
                if (all[i].status == FreelanceEscrow.Status.Funded) sum += all[i].amount;
            }
        }
        assertEq(token.balanceOf(address(escrow)), sum);
    }

    /// PROPERTY: escrowCount tracks creations, and no native value is ever held.
    function invariant_CountMatchesAndNoNative() public view {
        assertEq(escrow.escrowCount(), handler.created());
        assertEq(address(escrow).balance, 0);
    }
}
