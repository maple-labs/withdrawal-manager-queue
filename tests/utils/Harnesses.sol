// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleWithdrawalManager } from "../../contracts/MapleWithdrawalManager.sol";

import { SortedArray } from "../../contracts/utils/SortedArray.sol";

contract MapleWithdrawalManagerHarness is MapleWithdrawalManager {

    function locked() external view returns (uint256) {
        return _locked;
    }

    function __setManualSharesAvailable(address owner_, uint256 shares_) external {
        manualSharesAvailable[owner_] = shares_;
    }

    function __setManualWithdrawal(address owner_, bool isManual_) external {
        isManualWithdrawal[owner_] = isManual_;
    }

    function __setLastRequest(address owner_, uint256 requestId_) external {
        SortedArray.push(userRequests[owner_], requestId_);
        queue.lastRequestId = _toUint128(requestId_);
    }

    function __setQueue(uint256 nextRequestId_, uint256 lastRequestId_) external {
        queue.nextRequestId = _toUint128(nextRequestId_);
        queue.lastRequestId = _toUint128(lastRequestId_);
    }

    function __setRequestLegacy(uint128 requestId_, address owner_, uint256 shares_) external {
        // Used to setup the withdrawal manager storage in the old format.
        // This function is only used to unit test the migrator so we can setup wm storage without pushing to the sorted array.
        queue.lastRequestId        = requestId_;
        queue.requests[requestId_] = WithdrawalRequest(owner_, shares_);

        __deprecated_requestIds[owner_] = requestId_;
    }

    function __setRequest(uint128 requestId_, address owner_, uint256 shares_) external {
        queue.lastRequestId        = requestId_;
        queue.requests[requestId_] = WithdrawalRequest(owner_, shares_);

        SortedArray.push(userRequests[owner_], requestId_);
    }

    function __setTotalShares(uint256 totalShares_) external {
        totalShares = totalShares_;
    }

    function __setUserRequestCount(address owner_, uint256 requestCount_, uint256 escrowSharesTotal_) external {
        uint256 currentRequestCount_ = SortedArray.length(userRequests[owner_]);

        if (requestCount_ < currentRequestCount_) {
            for (uint256 i = requestCount_; i < currentRequestCount_; i++) {
                SortedArray.remove(userRequests[owner_], _toUint128(i));
            }
        } else {
            for (uint256 i = currentRequestCount_; i > requestCount_; i++) {
                SortedArray.push(userRequests[owner_], _toUint128(i));
            }
        }

        userEscrowedShares[owner_] = escrowSharesTotal_;
    }

}

contract SortedArrayHarness {

    SortedArray.Array array;

    function push(uint256 value_) external {
        SortedArray.push(array, value_);
    }

    function remove(uint256 value_) external {
        SortedArray.remove(array, value_);
    }

    function get(uint256 index_) external view returns (uint256) {
        return SortedArray.get(array, index_);
    }

    function length() external view returns (uint256) {
        return SortedArray.length(array);
    }

    function getAllValues() external view returns (uint256[] memory) {
        return SortedArray.getAllValues(array);
    }

    function getLast() external view returns (uint256) {
        return SortedArray.getLast(array);
    }

}           
