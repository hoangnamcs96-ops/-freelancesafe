// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FreelanceEscrow
 * @notice Non-custodial-role ERC-20 escrow intended for USDC on Arc Testnet.
 * @dev Compiled by the project's Solidity 0.8.28 / Cancun configuration with
 * OpenZeppelin Contracts 5.6.1. The constructor selects the token; no address or
 * decimal count is hardcoded. Amounts are token base units (USDC uses 6 decimals).
 * Only the creating client may fund, cancel an unfunded escrow, or release funds.
 * Release remains client-only and is allowed at any time while Funded.
 * Only the freelancer may voluntarily refund a funded escrow at any time.
 * With a nonzero deadline, the client may refund strictly after that deadline.
 * Without a deadline, the client may refund strictly after 180 days from funding
 * as a fail-safe if payment cannot be released. Deadlines do not prevent funding
 * or release, and do not trigger automatic refunds: eligible
 * transactions are ordered by execution. Released, Refunded and Cancelled are
 * terminal states; the client can never reclaim a released payment.
 * Funding requires the exact balance increase, rejecting fee-on-transfer deposits.
 * The selected token must otherwise have standard, non-rebasing ERC-20 semantics.
 * There is no owner, administrator, upgrade mechanism, rescue or hidden withdrawal.
 * Direct token donations cannot be recovered. No receive or fallback function is
 * provided, so ordinary accidental native-currency sends revert.
 */
contract FreelanceEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Lifecycle of an escrow; None denotes an ID that has not been created.
    enum Status { None, Created, Funded, Released, Refunded, Cancelled }

    /// @notice Named escrow fields returned to dashboard clients.
    /// @dev While Funded, only the client may release at any time; the freelancer
    /// may refund at any time. The client may refund strictly after a nonzero
    /// deadline, or strictly after 180 days from funding if no deadline is set.
    /// Released, Refunded and Cancelled are terminal states.
    struct Escrow {
        /// @notice Creator and sole funding/release authority.
        address client;
        /// @notice Payment recipient and voluntary-refund authority at any time while Funded.
        address freelancer;
        /// @notice Fixed payment in token base units.
        uint96 amount;
        /// @notice Creation timestamp in seconds.
        uint64 createdAt;
        /// @notice Client may refund strictly after this timestamp; zero uses 180 days from funding.
        uint64 deadline;
        /// @notice Funding timestamp in seconds; zero before funding. Starts the 180-day no-deadline delay.
        uint64 fundedAt;
        /// @notice Current lifecycle state; Released, Refunded and Cancelled are terminal.
        Status status;
        /// @notice Nonempty title, limited by UTF-8 byte length.
        string title;
        /// @notice Description, limited by UTF-8 byte length.
        string description;
    }

    /// @notice Immutable ERC-20 asset selected at construction.
    IERC20 public immutable token;
    /// @notice Maximum title size in bytes.
    uint256 public constant MAX_TITLE_LENGTH = 100;
    /// @notice Maximum description size in bytes.
    uint256 public constant MAX_DESCRIPTION_LENGTH = 1000;
    /// @notice Client refunds without a deadline require strictly more than this time from funding.
    uint64 public constant NO_DEADLINE_REFUND_DELAY = 180 days;
    /// @notice Number of escrows created; valid IDs run from 1 through this value.
    uint256 public escrowCount;
    /// @dev Escrow records keyed by sequential ID; exposed through validated views.
    mapping(uint256 => Escrow) private escrows;

    /// @notice An address is zero, or the constructor token address has no code.
    error ZeroAddress();
    /// @notice The freelancer is the client, this escrow, the token, an Arc system emitter or a precompile.
    error InvalidFreelancer();
    /// @notice The payment amount must be nonzero.
    error InvalidAmount();
    /// @notice A nonzero creation deadline must lie strictly in the future.
    error InvalidDeadline();
    /// @notice The title is empty or exceeds MAX_TITLE_LENGTH bytes.
    error InvalidTitleLength();
    /// @notice The description exceeds MAX_DESCRIPTION_LENGTH bytes.
    error InvalidDescriptionLength();
    /// @notice The requested ID is zero or has not been created.
    error EscrowNotFound();
    /// @notice Only the escrow's client may perform this operation.
    error NotClient();
    /// @notice Only the escrow's freelancer may perform this operation.
    error NotFreelancer();
    /// @notice The escrow's current state does not permit this operation.
    /// @param current Actual state at the time of the call.
    error InvalidStatus(Status current);
    /// @notice Funding did not increase this contract's balance by exactly the amount.
    error UnexpectedTransferAmount();
    /// @notice The current timestamp is not strictly after the deadline or no-deadline refund threshold.
    error DeadlineNotExpired();

    /// @notice Emitted when a client creates an unfunded escrow.
    /// @param id Sequential escrow ID.
    /// @param client Creating client.
    /// @param freelancer Intended payment recipient.
    /// @param amount Payment in token base units.
    /// @param deadline Refund deadline, or zero for none.
    /// @param title Escrow title.
    /// @param description Escrow description.
    event EscrowCreated(
        uint256 indexed id, address indexed client, address indexed freelancer,
        uint96 amount, uint64 deadline, string title, string description
    );
    /// @notice Emitted after exact funding is received.
    /// @param id Escrow ID.
    /// @param client Funding client.
    /// @param amount Amount received in token base units.
    event EscrowFunded(uint256 indexed id, address indexed client, uint96 amount);
    /// @notice Emitted when the client cancels an unfunded escrow.
    /// @param id Escrow ID.
    /// @param client Cancelling client.
    event EscrowCancelled(uint256 indexed id, address indexed client);
    /// @notice Emitted after a payment is released to the freelancer.
    /// @param id Escrow ID.
    /// @param freelancer Payment recipient.
    /// @param amount Payment in token base units.
    event PaymentReleased(uint256 indexed id, address indexed freelancer, uint96 amount);
    /// @notice Emitted after either authorized refund path returns funds to the client.
    /// @param id Escrow ID.
    /// @param client Refund recipient.
    /// @param amount Refund in token base units.
    /// @param refundedBy Caller that authorized the refund.
    event EscrowRefunded(
        uint256 indexed id, address indexed client, uint96 amount, address indexed refundedBy
    );

    /// @notice Select the immutable payment token; no privileged role is created.
    /// @param token_ ERC-20 contract address; zero or an address without code is rejected.
    constructor(address token_) {
        if (token_ == address(0) || token_.code.length == 0) revert ZeroAddress();
        token = IERC20(token_);
    }

    /// @notice Create an unfunded escrow as its client; IDs begin at one.
    /// @dev Creates a new record rather than accepting an existing ID. Titles and
    /// descriptions are checked in bytes, not Unicode character counts.
    /// @param freelancer Nonzero recipient, not the caller, escrow, token, Arc system emitter or a precompile.
    /// @param amount Nonzero payment in token base units.
    /// @param deadline Future timestamp, or zero for client refunds strictly after 180 days from funding.
    /// @param title Nonempty title of at most MAX_TITLE_LENGTH bytes.
    /// @param description Description of at most MAX_DESCRIPTION_LENGTH bytes.
    /// @return id Newly created escrow ID.
    function createEscrow(
        address freelancer,
        uint96 amount,
        uint64 deadline,
        string calldata title,
        string calldata description
    ) external returns (uint256 id) {
        if (freelancer == address(0)) revert ZeroAddress();
        if (
            freelancer == msg.sender || freelancer == address(this) || freelancer == address(token)
                || freelancer == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE
                || uint160(freelancer) <= 0xFFFF
        ) revert InvalidFreelancer();
        if (amount == 0) revert InvalidAmount();
        if (deadline != 0 && deadline <= block.timestamp) revert InvalidDeadline();
        if (bytes(title).length == 0 || bytes(title).length > MAX_TITLE_LENGTH) {
            revert InvalidTitleLength();
        }
        if (bytes(description).length > MAX_DESCRIPTION_LENGTH) {
            revert InvalidDescriptionLength();
        }

        id = ++escrowCount;
        escrows[id] = Escrow({
            client: msg.sender,
            freelancer: freelancer,
            amount: amount,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            fundedAt: 0,
            status: Status.Created,
            title: title,
            description: description
        });
        emit EscrowCreated(id, msg.sender, freelancer, amount, deadline, title, description);
    }

    /// @notice Fund an existing Created escrow; only its client may call.
    /// @dev Sets Funded before token interactions. Exact balance-delta validation
    /// rejects fee-on-transfer deposits. Allowance, balance or transfer failures
    /// revert the entire transaction, including the status change.
    /// @param id Existing escrow ID.
    function fund(uint256 id) external nonReentrant {
        Escrow storage escrow = _getEscrow(id);
        if (msg.sender != escrow.client) revert NotClient();
        if (escrow.status != Status.Created) revert InvalidStatus(escrow.status);

        escrow.status = Status.Funded;
        escrow.fundedAt = uint64(block.timestamp);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(escrow.client, address(this), escrow.amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != escrow.amount) {
            revert UnexpectedTransferAmount();
        }
        emit EscrowFunded(id, escrow.client, escrow.amount);
    }

    /// @notice Permanently cancel an unfunded Created escrow as its client.
    /// @dev Funded escrows cannot be cancelled; no token transfer occurs here.
    /// @param id Existing escrow ID.
    function cancel(uint256 id) external {
        Escrow storage escrow = _getEscrow(id);
        if (msg.sender != escrow.client) revert NotClient();
        if (escrow.status != Status.Created) revert InvalidStatus(escrow.status);
        escrow.status = Status.Cancelled;
        emit EscrowCancelled(id, escrow.client);
    }

    /// @notice Release a Funded escrow to its freelancer; only its client may call.
    /// @dev Release is allowed even after the deadline. Released is terminal:
    /// the client can never reclaim a released payment through either refund path.
    /// @param id Existing escrow ID.
    function release(uint256 id) external nonReentrant {
        Escrow storage escrow = _getEscrow(id);
        if (msg.sender != escrow.client) revert NotClient();
        if (escrow.status != Status.Funded) revert InvalidStatus(escrow.status);
        escrow.status = Status.Released;
        token.safeTransfer(escrow.freelancer, escrow.amount);
        emit PaymentReleased(id, escrow.freelancer, escrow.amount);
    }

    /// @notice Voluntarily return a Funded escrow to the client as its freelancer.
    /// @dev Allowed at any time while Funded, even without a deadline. Refunded
    /// is terminal; neither a second refund nor a later release is possible.
    /// @param id Existing escrow ID.
    function refundByFreelancer(uint256 id) external nonReentrant {
        Escrow storage escrow = _getEscrow(id);
        if (msg.sender != escrow.freelancer) revert NotFreelancer();
        if (escrow.status != Status.Funded) revert InvalidStatus(escrow.status);
        _refund(id, escrow);
    }

    /// @notice Refund a Funded escrow as its client strictly after its refund threshold.
    /// @dev With a deadline, the client may refund strictly after it; without one,
    /// strictly after 180 days from funding. Equality is insufficient in both cases.
    /// This no-deadline fail-safe permits recovery if release cannot succeed.
    /// The freelancer may refund at any time while Funded; release remains
    /// client-only and allowed at any time while Funded. Released, Refunded and
    /// Cancelled are terminal; the client can never reclaim funds after release.
    /// @param id Existing escrow ID.
    function claimExpiredRefund(uint256 id) external nonReentrant {
        Escrow storage escrow = _getEscrow(id);
        if (msg.sender != escrow.client) revert NotClient();
        if (escrow.status != Status.Funded) revert InvalidStatus(escrow.status);
        if (block.timestamp <= _refundableAfter(escrow)) revert DeadlineNotExpired();
        _refund(id, escrow);
    }

    /// @notice Read all named fields of an existing escrow.
    /// @param id Existing escrow ID; zero and uncreated IDs revert EscrowNotFound.
    /// @return escrow The complete escrow record.
    function getEscrow(uint256 id) external view returns (Escrow memory escrow) {
        return _getEscrow(id);
    }

    /// @notice Whether a client refund is currently permitted by timing and state.
    /// @dev Reports timing and state eligibility, independent of the view caller.
    /// Invalid IDs revert EscrowNotFound, rather than returning false.
    /// @param id Existing escrow ID.
    /// @return refundable True only if Funded and strictly past the deadline, or 180 days from funding without one.
    function isRefundable(uint256 id) external view returns (bool refundable) {
        Escrow storage escrow = _getEscrow(id);
        return escrow.status == Status.Funded && block.timestamp > _refundableAfter(escrow);
    }

    /// @notice Read a contiguous page of escrows in ascending ID order.
    /// @dev Starts at ID one, without offsets. Zero start reverts EscrowNotFound.
    /// Returns empty for zero count or start beyond escrowCount; clamps oversized
    /// count without computing start + count, preventing addition overflow.
    /// @param start First ID to return (inclusive).
    /// @param count Maximum number of records to return.
    /// @return records Records corresponding to start through start + length - 1.
    function getEscrows(uint256 start, uint256 count)
        external view returns (Escrow[] memory records)
    {
        if (start == 0) revert EscrowNotFound();
        if (start > escrowCount || count == 0) return new Escrow[](0);
        uint256 available = escrowCount - start + 1;
        uint256 length = count < available ? count : available;
        records = new Escrow[](length);
        for (uint256 i = 0; i < length; ++i) {
            records[i] = escrows[start + i];
        }
    }

    /// @dev Resolve an existing ID to its stored record before authorization/state checks.
    /// @param id ID to validate.
    /// @return escrow Storage reference to the validated escrow.
    function _getEscrow(uint256 id) private view returns (Escrow storage escrow) {
        if (id == 0 || id > escrowCount) revert EscrowNotFound();
        return escrows[id];
    }

    /// @dev Timestamp strictly after which the client may refund a Funded escrow.
    /// @param escrow Escrow whose deadline or funding timestamp determines eligibility.
    /// @return timestamp Deadline, or funding timestamp plus the 180-day no-deadline delay.
    function _refundableAfter(Escrow storage escrow) private view returns (uint256 timestamp) {
        return escrow.deadline != 0
            ? uint256(escrow.deadline)
            : uint256(escrow.fundedAt) + NO_DEADLINE_REFUND_DELAY;
    }

    /// @dev Complete a refund after the guarded external caller validates existence,
    /// authorization and Funded status. Effects precede the token interaction.
    /// @param id Validated escrow ID.
    /// @param escrow Validated Funded record to refund.
    function _refund(uint256 id, Escrow storage escrow) private {
        escrow.status = Status.Refunded;
        token.safeTransfer(escrow.client, escrow.amount);
        emit EscrowRefunded(id, escrow.client, escrow.amount, msg.sender);
    }
}
