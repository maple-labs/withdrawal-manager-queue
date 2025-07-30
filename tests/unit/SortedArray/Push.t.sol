
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedArrayTestBase } from "../../utils/TestBase.sol";

contract PushTests is SortedArrayTestBase {

    function test_push_failed_outOfOrder() external {
        array.push(3);

        vm.expectRevert("SA:P:NOT_LARGEST");
        array.push(1);
    }

    function test_push_singleValue() external {
        array.push(3);

        uint128[] memory expectedValues = new uint128[](1);
        expectedValues[0]               = 3;

        assertArray(expectedValues);
        assertElementAtIndex(0, 3);

        assertEq(array.length(), 1);
    }

    function test_push_multipleValues_inOrder() external {
        array.push(1);
        array.push(3);
        array.push(7);

        uint128[] memory expectedValues = new uint128[](3);
        expectedValues[0]               = 1;
        expectedValues[1]               = 3;
        expectedValues[2]               = 7;

        assertArray(expectedValues);
        assertElementAtIndex(0,  1);
        assertElementAtIndex(1,  3);
        assertElementAtIndex(2,  7);
        assertEq(array.length(), 3);
    }

}
