// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleWithdrawalManagerStorage } from "../interfaces/IMapleWithdrawalManagerStorage.sol";

contract MapleWithdrawalManagerStorage is IMapleWithdrawalManagerStorage {

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    struct Queue {
        uint128 nextRequestId;  // Identifier of the next request that will be processed.
        uint128 lastRequestId;  // Identifier of the last created request.
        mapping(uint128 => WithdrawalRequest) requests;  // Maps withdrawal requests to their positions in the queue.
    }

    struct UserRequestSummary {
        uint256 requestCount;
        uint256 escrowedSharesTotal;  // Escrowed shares yet to be processed.
    }

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override pool;
    address public override poolManager;

    uint256 public override totalShares;  // Total amount of shares pending redemption.

    Queue public override queue;

    mapping(address => bool) public override isManualWithdrawal;  // Defines which users use automated withdrawals (false by default).

    mapping(address => uint128) public override lastRequestIds;  // Maps users to their last withdrawal request.

    mapping(address => uint256) public override manualSharesAvailable;  // Shares available to withdraw for a given manual owner.

    mapping(address => UserRequestSummary) public override userRequestSummaries;  // Maps users to their request summaries.
}
