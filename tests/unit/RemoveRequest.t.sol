// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract RemoveRequestTests is TestBase {

    function setUp() public override {
        super.setUp();

        pool.mint(pm, 4);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), 4);
    }

    function test_removeRequest_protocolPaused() external {
        globals.__setFunctionPaused(true);

        vm.expectRevert("WM:PAUSED");
        withdrawalManager.removeRequest(lp, new uint256[](0));
    }

    function test_removeRequest_notAuthorized() external {
        globals.__setIsInstanceOf(false);

        vm.expectRevert("WM:NOT_REDEEMER");
        withdrawalManager.removeRequest(lp, new uint256[](0));
    }

    function test_removeRequest_notInQueue() external {
        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RR:NOT_IN_QUEUE");
        withdrawalManager.removeRequest(lp, requestIds_);
    }

    function test_removeRequest_failedTransfer() external {
        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        pool.burn(address(withdrawalManager), 1);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RR:TRANSFER_FAIL");
        withdrawalManager.removeRequest(lp, requestIds_);
    }

    function test_removeRequest_success() external {
        uint256 lastRequestIdLp_;

        vm.prank(pm);
        withdrawalManager.addShares(2, lp);

        assertEq(withdrawalManager.userEscrowedShares(lp), 2);

        ( , uint256 lastRequestId_ ) = withdrawalManager.queue();

        ( address owner_, uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestIdLp_, ) = getLastRequestByOwner(lp);

        assertEq(shares_,                         2);
        assertEq(withdrawalManager.totalShares(), 2);
        assertEq(lastRequestId_,                  1);
        assertEq(lastRequestIdLp_,                lastRequestId_);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = lastRequestId_;

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(lp, requestIds);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( owner_, shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestIdLp_, )            = getLastRequestByOwner(lp);
        ( uint256 lastRequestByOwner_, ) = getLastRequestByOwner(owner_);

        assertEq(lastRequestId_,                  1);
        assertEq(shares_,                         0);
        assertEq(owner_,                          address(0));
        assertEq(lastRequestIdLp_,                0);
        assertEq(lastRequestByOwner_,             0);
        assertEq(withdrawalManager.totalShares(), 0);

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
    }

    function test_removeRequest_multiple_requests_success() external {
        uint256 lastRequestIdLp_;

        vm.startPrank(pm);
        withdrawalManager.addShares(1, lp);
        withdrawalManager.addShares(1, lp);
        withdrawalManager.addShares(1, lp);
        vm.stopPrank();

        ( , uint256 lastRequestId_ ) = withdrawalManager.queue();

        ( address owner_, uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestIdLp_, ) = getLastRequestByOwner(lp);

        assertEq(shares_,                         1);
        assertEq(withdrawalManager.totalShares(), 3);
        assertEq(lastRequestId_,                  3);
        assertEq(lastRequestIdLp_,                lastRequestId_);

        assertEq(withdrawalManager.userEscrowedShares(lp), 3);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = 2;

        vm.expectEmit();
        emit RequestRemoved(2);

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(lp, requestIds);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( owner_, shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestIdLp_, )            = getLastRequestByOwner(lp);
        ( uint256 lastRequestByOwner_, ) = getLastRequestByOwner(owner_);

        assertEq(lastRequestId_,                  3);
        assertEq(shares_,                         1);
        assertEq(owner_,                          lp);
        assertEq(lastRequestIdLp_,                3);
        assertEq(lastRequestByOwner_,             3);
        assertEq(withdrawalManager.totalShares(), 2);

        assertEq(withdrawalManager.userEscrowedShares(lp), 2);

        requestIds = new uint256[](2);
        requestIds[0] = 1;
        requestIds[1] = 3;

        vm.expectEmit();
        emit RequestRemoved(1);
        emit RequestRemoved(3);

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(lp, requestIds);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( owner_, shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestIdLp_, )    = getLastRequestByOwner(lp);
        ( lastRequestByOwner_, ) = getLastRequestByOwner(owner_);

        assertEq(lastRequestId_,                  3);
        assertEq(shares_,                         0);
        assertEq(owner_,                          address(0));
        assertEq(lastRequestIdLp_,                0);
        assertEq(lastRequestByOwner_,             0);
        assertEq(withdrawalManager.totalShares(), 0);

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
    }

}
