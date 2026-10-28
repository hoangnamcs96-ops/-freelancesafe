// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FreelanceEscrow} from "../FreelanceEscrow.sol";
import {MockERC20} from "../test-helpers/EscrowMocks.sol";

abstract contract FreelanceEscrowTestBase is Test {
    FreelanceEscrow internal escrow;
    MockERC20 internal token;

    address internal client = makeAddr("client");
    address internal freelancer = makeAddr("freelancer");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant T0 = 1_700_000_000;
    uint96 internal constant AMOUNT = 1_000e6;
    uint64 internal constant DEADLINE_OFFSET = 30 days;
    uint256 internal constant NO_DEADLINE_DELAY = 180 days;

    function setUp() public virtual {
        vm.warp(T0);
        token = new MockERC20();
        escrow = new FreelanceEscrow(address(token));
        token.mint(client, 1_000_000e6);
        vm.prank(client);
        token.approve(address(escrow), type(uint256).max);
    }

    function _create() internal returns (uint256) {
        return _createWith(escrow, AMOUNT, uint64(block.timestamp + DEADLINE_OFFSET));
    }

    function _createNoDeadline() internal returns (uint256) {
        return _createWith(escrow, AMOUNT, 0);
    }

    function _createWith(FreelanceEscrow e, uint96 amount, uint64 deadline) internal returns (uint256 id) {
        vm.prank(client);
        id = e.createEscrow(freelancer, amount, deadline, "Logo design", "Design a logo");
    }

    function _createFunded() internal returns (uint256 id) {
        id = _create();
        vm.prank(client);
        escrow.fund(id);
    }

    function _createFundedNoDeadline() internal returns (uint256 id) {
        id = _createNoDeadline();
        vm.prank(client);
        escrow.fund(id);
    }

    function _status(uint256 id) internal view returns (FreelanceEscrow.Status) {
        return escrow.getEscrow(id).status;
    }

    function _str(uint256 n) internal pure returns (string memory) {
        bytes memory b = new bytes(n);
        for (uint256 i = 0; i < n; ++i) {
            b[i] = "a";
        }
        return string(b);
    }
}
