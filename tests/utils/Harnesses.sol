// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleWithdrawalManager } from "../../contracts/MapleWithdrawalManager.sol";

import { SortedLinkedList } from "../../contracts/utils/SortedLinkedList.sol";

contract MapleWithdrawalManagerHarness is MapleWithdrawalManager {

    function locked() external view returns (uint256) {
        return _locked;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setManualSharesAvailable(address owner_, uint256 shares_) external {
        manualSharesAvailable[owner_] = shares_;
    }

    function __setManualWithdrawal(address owner_, bool isManual_) external {
        isManualWithdrawal[owner_] = isManual_;
    }

    function __setLastRequest(address owner_, uint256 requestId_) external {
        SortedLinkedList.push(_userRequests[owner_], _toUint128(requestId_));
        _queue.lastRequestId = _toUint128(requestId_);
    }

    function __setQueue(uint256 lastRequestId_) external {
        _queue.lastRequestId = _toUint128(lastRequestId_);
    }

    function __setRequestLegacy(uint128 requestId_, address owner_, uint256 shares_) external {
        // Used to setup the withdrawal manager storage in the v2.0.0-rc.2/rc.3 format.
        // This function is only used to unit test the migrator so we can seed state without populating `_pendingRequestIds`.
        _queue.lastRequestId        = requestId_;
        _queue.requests[requestId_] = WithdrawalRequest(owner_, shares_);

        if (owner_ != address(0)) {
            userEscrowedShares[owner_] += shares_;

            SortedLinkedList.push(_userRequests[owner_], requestId_);
        }

        __deprecated_requestIds[owner_] = requestId_;
    }

    function __setRequest(uint128 requestId_, address owner_, uint256 shares_) external {
        _queue.lastRequestId        = requestId_;
        _queue.requests[requestId_] = WithdrawalRequest(owner_, shares_);

        if (owner_ != address(0)) {
            SortedLinkedList.push(_userRequests[owner_], _toUint128(requestId_));
            SortedLinkedList.push(_pendingRequestIds,    _toUint128(requestId_));
        }
    }

    function __setTotalShares(uint256 totalShares_) external {
        totalShares = totalShares_;
    }

    function __setUserRequestCount(address owner_, uint256 requestCount_, uint256 escrowSharesTotal_) external {
        uint256 currentRequestCount_ = SortedLinkedList.length(_userRequests[owner_]);

        if (requestCount_ < currentRequestCount_) {
            for (uint256 i = requestCount_; i < currentRequestCount_; i++) {
                SortedLinkedList.remove(_userRequests[owner_], _toUint128(i));
            }
        } else {
            for (uint256 i = currentRequestCount_; i > requestCount_; i++) {
                SortedLinkedList.push(_userRequests[owner_], _toUint128(i));
            }
        }

        userEscrowedShares[owner_] = escrowSharesTotal_;
    }

}

contract SortedLinkedListHarness {

    SortedLinkedList.List list;

    function push(uint128 value_) external {
        SortedLinkedList.push(list, value_);
    }

    function remove(uint128 value_) external {
        SortedLinkedList.remove(list, value_);
    }

    function length() external view returns (uint256) {
        return SortedLinkedList.length(list);
    }

    function getAllValues() external view returns (uint128[] memory) {
        return SortedLinkedList.getAllValues(list);
    }

    function getValues(uint256 start_, uint256 limit_) external view returns (uint128[] memory) {
        return SortedLinkedList.getValues(list, start_, limit_);
    }

    function getLast() external view returns (uint128) {
        return SortedLinkedList.getLast(list);
    }

}
