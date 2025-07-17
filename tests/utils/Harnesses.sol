// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleWithdrawalManager } from "../../contracts/MapleWithdrawalManager.sol";

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

    function __setLastRequest(address owner_, uint128 requestId_) external {
        lastRequestIds[owner_] = requestId_;
    }

    function __setQueue(uint128 nextRequestId_, uint128 lastRequestId_) external {
        queue.nextRequestId = nextRequestId_;
        queue.lastRequestId = lastRequestId_;
    }

    function __setRequest(uint128 requestId_, address owner_, uint256 shares_) external {
        queue.requests[requestId_] = WithdrawalRequest(owner_, shares_);
        lastRequestIds[owner_] = requestId_;
    }

    function __setTotalShares(uint256 totalShares_) external {
        totalShares = totalShares_;
    }

    function __setUserRequestCount(address owner_, uint256 requestCount_, uint256 escrowSharesTotal_) external {
        userRequestSummaries[owner_].requestCount = requestCount_;
        userRequestSummaries[owner_].escrowedSharesTotal = escrowSharesTotal_;
    }

}
