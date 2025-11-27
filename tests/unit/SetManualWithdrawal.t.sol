// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract SetManualWithdrawalTests is TestBase {

    function test_setManualWithdrawal_protocolPaused() external {
        globals.__setFunctionPaused(true);

        vm.expectRevert("WM:PAUSED");
        withdrawalManager.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_notPoolDelegateOrOpsAdmin() external {
        vm.expectRevert("WM:NOT_POOL_DELEG_OR_OPS_ADMIN");
        withdrawalManager.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_governotNotAllowed() external {
        vm.prank(governor);
        vm.expectRevert("WM:NOT_POOL_DELEG_OR_OPS_ADMIN");
        withdrawalManager.setManualWithdrawal(lp, true);
    }

    function test_setManualWithdrawal_success() external {
        assertEq(withdrawalManager.isManualWithdrawal(lp), false);

        vm.expectEmit();
        emit ManualWithdrawalSet(lp, true);

        vm.prank(poolDelegate);
        withdrawalManager.setManualWithdrawal(lp, true);

        assertEq(withdrawalManager.isManualWithdrawal(lp), true);
    }

}
