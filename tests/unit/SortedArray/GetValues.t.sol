// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedLinkedListTestBase } from "../../utils/TestBase.sol";

contract GetValuesTests is SortedLinkedListTestBase {

    function test_getValues_emptyList() external {
        uint128[] memory values_ = list.getValues(0, 10);
        assertEq(values_.length, 0);
    }

    function test_getValues_zeroLimit() external {
        list.push(1);
        list.push(3);

        uint128[] memory values_ = list.getValues(0, 0);
        assertEq(values_.length, 0);
    }

    function test_getValues_startAtSize() external {
        list.push(2);
        list.push(4);

        uint128[] memory values_ = list.getValues(2, 1);
        assertEq(values_.length, 0);
    }

    function test_getValues_startBeyondSize() external {
        list.push(2);
        list.push(4);

        uint128[] memory values_ = list.getValues(3, 1);
        assertEq(values_.length, 0);
    }

    function test_getValues_headOnly() external {
        list.push(1);
        list.push(3);
        list.push(5);

        uint128[] memory values_ = list.getValues(0, 1);
        assertEq(values_.length, 1);
        assertEq(values_[0],     1);
    }

    function test_getValues_fullListExactLimit() external {
        list.push(1);
        list.push(3);
        list.push(5);

        uint128[] memory values_ = list.getValues(0, 3);
        assertEq(values_.length, 3);
        assertEq(values_[0],     1);
        assertEq(values_[1],     3);
        assertEq(values_[2],     5);
    }

    function test_getValues_limitBeyondSize() external {
        list.push(1);
        list.push(3);
        list.push(5);

        uint128[] memory values_ = list.getValues(0, 10);
        assertEq(values_.length, 3);
        assertEq(values_[0],     1);
        assertEq(values_[1],     3);
        assertEq(values_[2],     5);
    }

    function test_getValues_middleSlice() external {
        list.push(1);
        list.push(3);
        list.push(5);
        list.push(7);

        uint128[] memory values_ = list.getValues(1, 2);
        assertEq(values_.length, 2);
        assertEq(values_[0],     3);
        assertEq(values_[1],     5);
    }

    function test_getValues_lastElement() external {
        list.push(1);
        list.push(3);
        list.push(5);

        uint128[] memory values_ = list.getValues(2, 1);
        assertEq(values_.length, 1);
        assertEq(values_[0],     5);
    }

    function test_getValues_lastElementWithLargeLimit() external {
        list.push(1);
        list.push(3);
        list.push(5);

        uint128[] memory values_ = list.getValues(2, 10);
        assertEq(values_.length, 1);
        assertEq(values_[0],     5);
    }

}
