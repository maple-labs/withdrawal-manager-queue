// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract ViewFunctionsTests is TestBase {

    function testFuzz_isInExitWindow(address account_) external {
        assertTrue(withdrawalManager.isInExitWindow(account_));
    }

    function test_lockedLiquidity() external {
        assertEq(withdrawalManager.lockedLiquidity(), 0);
    }

    function test_lockedShares(address account_, uint256 shares_) external {
        withdrawalManager.__setManualSharesAvailable(account_, shares_);
        assertEq(withdrawalManager.lockedShares(account_), shares_);
    }

    function test_previewWithdraw(address account_, uint256 shares_) external {
        ( uint256 redeemableAssets, uint256 redeemableShares ) = withdrawalManager.previewWithdraw(account_, shares_);
        assertEq(redeemableAssets, 0);
        assertEq(redeemableShares, 0);
    }

    function test_requests_by_owner() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");
        address lp4 = makeAddr("lp4");

        uint256 assetsDeposited_ = 100e18;

        withdrawalManager.__setRequest(1, lp1, assetsDeposited_);
        withdrawalManager.__setRequest(2, lp2, assetsDeposited_);
        withdrawalManager.__setRequest(3, lp3, assetsDeposited_);
        withdrawalManager.__setRequest(4, lp4, assetsDeposited_);
        withdrawalManager.__setRequest(5, lp1, assetsDeposited_);

        withdrawalManager.__setUserRequestCount(lp1, 2, assetsDeposited_ * 2);
        withdrawalManager.__setUserRequestCount(lp2, 1, assetsDeposited_);
        withdrawalManager.__setUserRequestCount(lp3, 1, assetsDeposited_);
        withdrawalManager.__setUserRequestCount(lp4, 1, assetsDeposited_);

        withdrawalManager.__setQueue(1, 5);

        (uint128[] memory requestIdsLp1_, uint256[] memory sharesLp1_) = withdrawalManager.requestsByOwner(lp1);
        (uint128[] memory requestIdsLp2_, uint256[] memory sharesLp2_) = withdrawalManager.requestsByOwner(lp2);
        (uint128[] memory requestIdsLp3_, uint256[] memory sharesLp3_) = withdrawalManager.requestsByOwner(lp3);
        (uint128[] memory requestIdsLp4_, uint256[] memory sharesLp4_) = withdrawalManager.requestsByOwner(lp4);


        assertEq(requestIdsLp1_.length, 2);
        assertEq(requestIdsLp1_[0], 1);
        assertEq(requestIdsLp1_[1], 5);

        assertEq(sharesLp1_.length, 2);
        assertEq(sharesLp1_[0], assetsDeposited_);
        assertEq(sharesLp1_[1], assetsDeposited_);

        assertEq(requestIdsLp2_.length, 1);
        assertEq(requestIdsLp2_[0], 2);

        assertEq(sharesLp2_.length, 1);
        assertEq(sharesLp2_[0], assetsDeposited_);

        assertEq(requestIdsLp3_.length, 1);
        assertEq(requestIdsLp3_[0], 3);

        assertEq(sharesLp3_.length, 1);
        assertEq(sharesLp3_[0], assetsDeposited_);

        assertEq(requestIdsLp4_.length, 1);
        assertEq(requestIdsLp4_[0], 4);

        assertEq(sharesLp4_.length, 1);
        assertEq(sharesLp4_[0], assetsDeposited_);
    }

    function test_requests_by_requestId() external {
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");
        address lp4 = makeAddr("lp4");

        uint256 assetsDeposited_ = 100e18;

        withdrawalManager.__setRequest(1, lp, assetsDeposited_);
        withdrawalManager.__setRequest(2, lp2, assetsDeposited_);
        withdrawalManager.__setRequest(3, lp3, assetsDeposited_);
        withdrawalManager.__setRequest(4, lp4, assetsDeposited_);
        withdrawalManager.__setRequest(5, lp, assetsDeposited_);

        withdrawalManager.__setUserRequestCount(lp,  2, assetsDeposited_ * 2);
        withdrawalManager.__setUserRequestCount(lp2, 1, assetsDeposited_);
        withdrawalManager.__setUserRequestCount(lp3, 1, assetsDeposited_);
        withdrawalManager.__setUserRequestCount(lp4, 1, assetsDeposited_);

        withdrawalManager.__setQueue(1, 5);

        (address ownerLp1_, uint256 sharesLp1_) = withdrawalManager.requests(1);
        (address ownerLp2_, uint256 sharesLp2_) = withdrawalManager.requests(2);
        (address ownerLp3_, uint256 sharesLp3_) = withdrawalManager.requests(3);
        (address ownerLp4_, uint256 sharesLp4_) = withdrawalManager.requests(4);
        (address ownerLp1_2_, uint256 sharesLp1_2_) = withdrawalManager.requests(5);

        assertEq(ownerLp1_, lp);
        assertEq(sharesLp1_, assetsDeposited_);

        assertEq(ownerLp2_, lp2);
        assertEq(sharesLp2_, assetsDeposited_);

        assertEq(ownerLp3_, lp3);
        assertEq(sharesLp3_, assetsDeposited_);

        assertEq(ownerLp4_, lp4);
        assertEq(sharesLp4_, assetsDeposited_);

        assertEq(ownerLp1_2_, lp);
        assertEq(sharesLp1_2_, assetsDeposited_);
    }

}
