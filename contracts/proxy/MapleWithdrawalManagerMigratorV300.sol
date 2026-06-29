// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleProxiedInternals } from "../../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { SortedLinkedList } from "../utils/SortedLinkedList.sol";

import { MapleWithdrawalManagerStorage } from "./MapleWithdrawalManagerStorage.sol";

contract MapleWithdrawalManagerMigratorV300 is MapleProxiedInternals, MapleWithdrawalManagerStorage {

    fallback() external {
        uint128 nextRequestId_ = _queue.__deprecated_nextRequestId;
        uint128 lastRequestId_ = _queue.lastRequestId;

        for (uint128 i = nextRequestId_; i <= lastRequestId_; ++i) {
            WithdrawalRequest memory request_ = _queue.requests[i];
            if (request_.owner == address(0)) continue;

            SortedLinkedList.push(_pendingRequestIds, i);
        }

        _queue.__deprecated_nextRequestId = 0;
    }

}
