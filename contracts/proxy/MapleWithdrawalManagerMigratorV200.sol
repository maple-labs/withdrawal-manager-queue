// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleProxiedInternals } from "../../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { SortedArray } from "../utils/SortedArray.sol";

import { MapleWithdrawalManagerStorage } from "./MapleWithdrawalManagerStorage.sol";

contract MapleWithdrawalManagerMigratorV200 is MapleProxiedInternals, MapleWithdrawalManagerStorage {

    fallback() external {
        uint128 nextRequestId_ = queue.nextRequestId;
        uint128 lastRequestId_ = queue.lastRequestId;

        for (uint128 i = nextRequestId_; i <= lastRequestId_; ++i) {
            WithdrawalRequest memory request_ = queue.requests[i];

            if (request_.owner == address(0)) continue;

            userEscrowedShares[request_.owner] += request_.shares;

            SortedArray.push(_userRequests[request_.owner], i);
        }
    }

}
