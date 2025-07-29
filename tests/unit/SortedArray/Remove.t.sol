// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedArrayTestBase } from "../../utils/TestBase.sol";

contract RemoveTests is SortedArrayTestBase {

    function test_remove_singleValue() external {
        array.push(1);
        array.remove(1);

        uint128[] memory expectedValues = new uint128[](0);
        assertArray(expectedValues);

        assertEq(array.length(), 0);
    }

    function test_remove_multipleValues() external {
        array.push(1);
        array.push(2);
        array.push(3);

        array.remove(2);

        uint128[] memory expectedValues = new uint128[](2);
        expectedValues[0]               = 1;
        expectedValues[1]               = 3;

        assertArray(expectedValues);
        assertElementAtIndex(0, 1);
        assertElementAtIndex(1, 3);

        assertEq(array.length(), 2);

        array.remove(1);

        expectedValues    = new uint128[](1);
        expectedValues[0] = 3;

        assertArray(expectedValues);
        assertElementAtIndex(0, 3);

        assertEq(array.length(), 1);

        array.remove(3);

        assertArray(new uint128[](0));
        assertEq(array.length(), 0);
    }

}
