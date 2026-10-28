// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Plain 6-decimal mock token with open mint.
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Token whose transfer / transferFrom can be switched to return false or revert.
/// Mode: 0 = normal, 1 = return false, 2 = revert.
contract ToggleToken is MockERC20 {
    uint8 public transferMode;
    uint8 public transferFromMode;

    function setTransferMode(uint8 m) external {
        transferMode = m;
    }

    function setTransferFromMode(uint8 m) external {
        transferFromMode = m;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (transferMode == 1) return false;
        if (transferMode == 2) revert("transfer disabled");
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (transferFromMode == 1) return false;
        if (transferFromMode == 2) revert("transferFrom disabled");
        return super.transferFrom(from, to, value);
    }
}

/// @dev Fee-on-transfer token: burns 1% of every wallet-to-wallet transfer.
contract FeeOnTransferToken is MockERC20 {
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value / 100;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

/// @dev Malicious token: while the target escrow moves tokens, it calls back into the
/// target with an arbitrary payload (release / fund / refund). The callback's msg.sender
/// is this token. If `bubble`, a failed re-entry reverts the outer transfer with the same data.
contract ReentrantToken is MockERC20 {
    address public target;
    bytes public payload;
    bool public bubble;
    bool public armed;
    bool public inHook;
    bool public hookRan;
    bool public lastSuccess;
    bytes public lastReturn;

    function arm(address target_, bytes calldata payload_, bool bubble_) external {
        target = target_;
        payload = payload_;
        bubble = bubble_;
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (armed && !inHook && (from == target || to == target)) {
            inHook = true;
            hookRan = true;
            (bool ok, bytes memory ret) = target.call(payload);
            lastSuccess = ok;
            lastReturn = ret;
            inHook = false;
            if (!ok && bubble) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
    }
}

/// @dev Contract acting as client: creates, funds, releases and refunds through the escrow.
/// Used to test a contract actor that tries to re-enter from its own context.
interface IEscrowLike {
    function createEscrow(address, uint96, uint64, string calldata, string calldata) external returns (uint256);
    function fund(uint256) external;
    function release(uint256) external;
    function claimExpiredRefund(uint256) external;
    function refundByFreelancer(uint256) external;
}

/// @dev Contract freelancer that tries to double-dip after being paid.
contract GreedyFreelancer {
    IEscrowLike public escrow;
    bool public lastRefundOk;

    constructor(IEscrowLike e) {
        escrow = e;
    }

    function tryRefund(uint256 id) external {
        try escrow.refundByFreelancer(id) {
            lastRefundOk = true;
        } catch {
            lastRefundOk = false;
        }
    }

    function refund(uint256 id) external {
        escrow.refundByFreelancer(id);
    }
}
