// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleWithdrawalManagerStorage } from "../interfaces/IMapleWithdrawalManagerStorage.sol";

import { SortedLinkedList } from "../utils/SortedLinkedList.sol";

contract MapleWithdrawalManagerStorage is IMapleWithdrawalManagerStorage {

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    struct Queue {
        uint128 __deprecated_nextRequestId;  // Identifier of the next request that will be processed.
        uint128 lastRequestId;  // Identifier of the last created request.
        mapping(uint128 => WithdrawalRequest) requests;  // Maps withdrawal requests to their positions in the queue.
    }

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override pool;
    address public override poolManager;

    uint256 public override totalShares;  // Total amount of shares pending redemption.

    Queue internal _queue;

    mapping(address => bool) public override isManualWithdrawal;  // Defines which users use automated withdrawals (false by default).

    mapping(address => uint128) internal __deprecated_requestIds;  // Maps users to their last withdrawal request.

    mapping(address => uint256) public override manualSharesAvailable;  // Shares available to withdraw for a given manual owner.

    mapping(address => uint256) public override userEscrowedShares;  // Maps users to their escrowed shares yet to be processed.

    mapping(address => SortedLinkedList.List) internal _userRequests;  // Maps users to their withdrawal requests.

    SortedLinkedList.List internal _pendingRequestIds;  // Tracks all pending withdrawal request IDs.

}
