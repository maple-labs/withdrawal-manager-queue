
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedArrayTestBase } from "../../utils/TestBase.sol";

// TODO: Update tests to use sequential numbers with gaps. 
contract PushTests is SortedArrayTestBase {

    function test_push_failed_outOfOrder() external {
        array.push(3);

        vm.expectRevert("SA:P:NOT_LARGEST");
        array.push(1);
    }

    function test_push_singleValue() external {
        array.push(1);

        uint128[] memory expectedValues = new uint128[](1);
        expectedValues[0]               = 1;

        assertArray(expectedValues);
        assertElementAtIndex(0, 1);

        assertEq(array.length(), 1);
    }

    function test_push_multipleValues_inOrder() external {
        array.push(1);
        array.push(2);
        array.push(3);

        uint128[] memory expectedValues = new uint128[](3);
        expectedValues[0]               = 1;
        expectedValues[1]               = 2;
        expectedValues[2]               = 3;

        assertArray(expectedValues);
        assertElementAtIndex(0,  1);
        assertElementAtIndex(1,  2);
        assertElementAtIndex(2,  3);
        assertEq(array.length(), 3);
    }

}
