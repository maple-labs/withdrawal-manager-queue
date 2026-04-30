// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract EndToEndTests is TestBase {

    // Helper storage variable for fuzz test
    mapping(uint256 => address) lpsRequest;
    mapping(address => bool)    manualLps;
    mapping(address => uint256) lpShares;

    function setUp() public override {
        super.setUp();
    }

    function test_e2e_cherrypick_manual_and_auto_flow() external {
        // Start with 3 users
        address lp1 = makeAddr("lp1");  // Automatic
        address lp2 = makeAddr("lp2");  // Manual
        address lp3 = makeAddr("lp3");  // Automatic

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;
        uint256 shares3 = 300e18;

        uint256 totalInitialShares = shares1 + shares2 + shares3;

        uint256 requestId_;

        // Simulate shares being sent to PM
        pool.mint(pm, totalInitialShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalInitialShares);

        vm.prank(poolDelegate);
        withdrawalManager.setManualWithdrawal(lp2, true);

        assertFalse(withdrawalManager.isManualWithdrawal(lp1));
        assertTrue(withdrawalManager.isManualWithdrawal(lp2));
        assertFalse(withdrawalManager.isManualWithdrawal(lp3));

        // All users are added to the queue
        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        assertQueue({  nextRequestId: 1, lastRequestId: 1 });
        assertRequest({ requestId: 1, shares: shares1, owner: lp1 });

        ( requestId_, ) = getLastRequestByOwner(lp1);

        assertEq(requestId_,                                 1);
        assertEq(pool.balanceOf(address(withdrawalManager)), shares1);

        withdrawalManager.addShares(shares2, lp2);
        assertQueue({ nextRequestId: 1, lastRequestId: 2 });
        assertRequest({ requestId: 2, shares: shares2, owner: lp2 });

        ( requestId_, ) = getLastRequestByOwner(lp2);

        assertEq(requestId_,                                 2);
        assertEq(pool.balanceOf(address(withdrawalManager)), shares1 + shares2);

        withdrawalManager.addShares(shares3, lp3);
        assertQueue({ nextRequestId: 1, lastRequestId: 3 });
        assertRequest({ requestId: 3, shares: shares3, owner: lp3 });

        ( requestId_, ) = getLastRequestByOwner(lp3);

        assertEq(requestId_,                                 3);
        assertEq(pool.balanceOf(address(withdrawalManager)), shares1 + shares2 + shares3);

        vm.stopPrank();

        asset.mint(address(pool), totalInitialShares);
        poolManager.__setTotalAssets(totalInitialShares);

        assertEq(withdrawalManager.totalShares(),            totalInitialShares);
        assertEq(pool.balanceOf(address(withdrawalManager)), totalInitialShares);

        // Pool Delegate processes request 3 first (cherry-picked)
        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 3;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertQueue({ nextRequestId: 1, lastRequestId: 3 });
        assertRequest({ requestId: 3, shares: 0, owner: address(0) });
        assertEq(withdrawalManager.totalShares(), shares1 + shares2);

        // Pool Delegate processes remaining requests
        requestIds_ = new uint256[](2);
        requestIds_[0] = 1;
        requestIds_[1] = 2;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertQueue({ nextRequestId: 4, lastRequestId: 3 });

        // Manual shares remain available until exit
        assertEq(withdrawalManager.totalShares(),              shares2);
        assertEq(withdrawalManager.manualSharesAvailable(lp2), shares2);

        assertRequest({ requestId: 1, shares: 0, owner: address(0) });
        assertRequest({ requestId: 2, shares: 0, owner: address(0) });

        vm.prank(pm);
        withdrawalManager.processExit(shares2, lp2);

        assertEq(withdrawalManager.totalShares(),              0);
        assertEq(withdrawalManager.manualSharesAvailable(lp2), 0);
    }

    function testFuzz_cherrypick_all_requests_manual_shares_retained(
        address[10] memory lps, 
        bool[10] memory isManual, 
        uint256[10] memory shares
    ) external {
        uint256 totalShares;
        uint256 manualShares;
        uint256 inQueue;
        uint256 requestId_;

        // Iterate through all users and add shares to pool manager
        for (uint256 i = 0; i < 10; i++) {
            vm.assume(lps[i] != address(0));

            ( requestId_, ) = getLastRequestByOwner(lps[i]);

            // If it's a unique user, add to the queue
            if (requestId_ == 0) {
                uint256 sharesRequested = bound(shares[i], 1, 1e18);

                // Save each LP value to verify later
                lpsRequest[++inQueue] = lps[i];
                lpShares[lps[i]]      = sharesRequested;
                totalShares           += sharesRequested;

                _addSharesToPoolManager(sharesRequested);

                if (isManual[i]) {
                    vm.prank(poolDelegate);
                    withdrawalManager.setManualWithdrawal(lps[i], true);
                    manualLps[lps[i]] = true;
                    manualShares     += sharesRequested;
                }

                vm.prank(pm);
                withdrawalManager.addShares(sharesRequested, lps[i]);
            }
        }

        asset.mint(address(pool), totalShares);
        poolManager.__setTotalAssets(totalShares);

        // Assert queue state
        assertQueue({ nextRequestId: 1, lastRequestId: inQueue });

        assertEq(withdrawalManager.totalShares(), totalShares);

        // Process all pending requests
        uint256[] memory requestIds_ = new uint256[](inQueue);

        for (uint256 i = 0; i < inQueue; i++) {
            requestIds_[i] = i + 1;
        }

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        // Check the queue is fully processed
        assertQueue({ nextRequestId: inQueue + 1, lastRequestId: inQueue });

        // Verify processed requests and manual shares
        for (uint256 i = 1; i <= inQueue; i++) {
            address lp = lpsRequest[i];

            assertRequest({ requestId: i, shares: 0, owner: address(0) });

            if (manualLps[lp]) {
                assertEq(withdrawalManager.manualSharesAvailable(lp), lpShares[lp]);
            } else {
                assertEq(withdrawalManager.manualSharesAvailable(lp), 0);
            }
        }

        assertEq(withdrawalManager.totalShares(), manualShares);
    }

    function test_e2e_cherrypick_duplicate_ids_revert_low_liquidity() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;
        uint256 shares3 = 300e18;

        uint256 totalShares = shares1 + shares2 + shares3;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        withdrawalManager.addShares(shares3, lp3);
        vm.stopPrank();

        asset.mint(address(pool), totalShares);
        poolManager.__setTotalAssets(totalShares);

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(lp2, _singleElementArray(2));

        uint256[] memory requestIds_ = new uint256[](4);
        requestIds_[0] = 3;
        requestIds_[1] = 3;
        requestIds_[2] = 2;
        requestIds_[3] = 1;

        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_e2e_cherrypick_duplicate_ids_sufficient_liquidity_process_once() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");
        address lp4 = makeAddr("lp4");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;
        uint256 shares3 = 300e18;
        uint256 shares4 = 400e18;

        uint256 totalShares = shares1 + shares2 + shares3 + shares4;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        withdrawalManager.addShares(shares3, lp3);
        withdrawalManager.addShares(shares4, lp4);
        vm.stopPrank();

        asset.mint(address(pool), 900e18);
        poolManager.__setTotalAssets(totalShares);

        uint256[] memory requestIds_ = new uint256[](4);
        requestIds_[0] = 3;
        requestIds_[1] = 3;
        requestIds_[2] = 2;
        requestIds_[3] = 1;

        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares1, lp1, address(withdrawalManager)),
            1
        );
        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares2, lp2, address(withdrawalManager)),
            1
        );
        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares3, lp3, address(withdrawalManager)),
            1
        );

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertRequest({ requestId: 1, shares: 0,       owner: address(0) });
        assertRequest({ requestId: 2, shares: 0,       owner: address(0) });
        assertRequest({ requestId: 3, shares: 0,       owner: address(0) });
        assertRequest({ requestId: 4, shares: shares4, owner: lp4 });

        assertQueue({ nextRequestId: 4, lastRequestId: 4 });

        assertEq(withdrawalManager.totalShares(), shares4);
    }

    function test_e2e_remove_request_then_process_including_removed() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;
        uint256 shares3 = 300e18;

        uint256 totalShares = shares1 + shares2 + shares3;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        withdrawalManager.addShares(shares3, lp3);
        vm.stopPrank();

        asset.mint(address(pool), totalShares);
        poolManager.__setTotalAssets(totalShares);

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(lp2, _singleElementArray(2));

        uint256[] memory requestIds_ = new uint256[](3);
        requestIds_[0] = 1;
        requestIds_[1] = 2;
        requestIds_[2] = 3;

        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares1, lp1, address(withdrawalManager)),
            1
        );
        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares3, lp3, address(withdrawalManager)),
            1
        );

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertRequest({ requestId: 1, shares: 0, owner: address(0) });
        assertRequest({ requestId: 2, shares: 0, owner: address(0) });
        assertRequest({ requestId: 3, shares: 0, owner: address(0) });

        assertQueue({ nextRequestId: 4, lastRequestId: 3 });

        assertEq(withdrawalManager.totalShares(), 0);
    }

    function test_e2e_remove_request_then_process_remaining_only() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;
        uint256 shares3 = 300e18;

        uint256 totalShares = shares1 + shares2 + shares3;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        withdrawalManager.addShares(shares3, lp3);
        vm.stopPrank();

        asset.mint(address(pool), totalShares);
        poolManager.__setTotalAssets(totalShares);

        vm.prank(poolDelegate);
        withdrawalManager.removeRequest(lp2, _singleElementArray(2));

        uint256[] memory requestIds_ = new uint256[](2);
        requestIds_[0] = 1;
        requestIds_[1] = 3;

        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares1, lp1, address(withdrawalManager)),
            1
        );
        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", shares3, lp3, address(withdrawalManager)),
            1
        );

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertRequest({ requestId: 1, shares: 0, owner: address(0) });
        assertRequest({ requestId: 2, shares: 0, owner: address(0) });
        assertRequest({ requestId: 3, shares: 0, owner: address(0) });

        assertQueue({ nextRequestId: 4, lastRequestId: 3 });

        assertEq(withdrawalManager.totalShares(), 0);
    }

    function test_e2e_cherrypick_reverts_on_low_liquidity() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;

        uint256 totalShares = shares1 + shares2;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        vm.stopPrank();

        asset.mint(address(pool), totalShares - 1);
        poolManager.__setTotalAssets(totalShares);

        uint256[] memory requestIds_ = new uint256[](2);
        requestIds_[0] = 1;
        requestIds_[1] = 2;

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_e2e_cherrypick_manual_and_auto_mixed_order() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;
        uint256 shares3 = 300e18;

        uint256 totalShares = shares1 + shares2 + shares3;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.prank(poolDelegate);
        withdrawalManager.setManualWithdrawal(lp2, true);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        withdrawalManager.addShares(shares3, lp3);
        vm.stopPrank();

        asset.mint(address(pool), totalShares);
        poolManager.__setTotalAssets(totalShares);

        uint256[] memory requestIds_ = new uint256[](2);
        requestIds_[0] = 3;
        requestIds_[1] = 2;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertRequest({ requestId: 2, shares: 0, owner: address(0) });
        assertRequest({ requestId: 3, shares: 0, owner: address(0) });

        assertEq(withdrawalManager.manualSharesAvailable(lp2), shares2);
        assertEq(withdrawalManager.totalShares(), shares1 + shares2);
    }

    function test_e2e_cherrypick_empty_queue_next_request_id() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        uint256 shares1 = 100e18;
        uint256 shares2 = 200e18;

        uint256 totalShares = shares1 + shares2;

        pool.mint(pm, totalShares);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), totalShares);

        vm.startPrank(pm);
        withdrawalManager.addShares(shares1, lp1);
        withdrawalManager.addShares(shares2, lp2);
        vm.stopPrank();

        asset.mint(address(pool), totalShares);
        poolManager.__setTotalAssets(totalShares);

        uint256[] memory requestIds_ = new uint256[](2);
        requestIds_[0] = 1;
        requestIds_[1] = 2;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertQueue({ nextRequestId: 3, lastRequestId: 2 });
    }

    function _addSharesToPoolManager(uint256 shares_) internal {
        pool.mint(pm, shares_);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), shares_);
    }

    function _singleElementArray(uint256 value_) internal pure returns (uint256[] memory values_) {
        values_ = new uint256[](1);
        values_[0] = value_;
    }

}
