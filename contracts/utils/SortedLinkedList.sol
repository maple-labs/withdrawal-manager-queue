// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library SortedLinkedList {

    struct Node {
        uint128 next;
        uint128 prev;
        bool exists;
    }

    struct List {
        uint128 head;
        uint128 tail;
        uint256 size;

        mapping(uint128 => Node) nodes;
    }

    /**************************************************************************************************************************************/
    /*** Write Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     * @dev   Pushes a value to the list.
     *        It is expected that the value is biggest so far so it will be added at the end of the list.
     * @param list   The list to push the value to.
     * @param value_ The value to push to the list.
     */
    function push(List storage list, uint128 value_) internal {
        uint128 tail_ = list.tail;

        require(value_ > 0,              "SLL:P:ZERO_VALUE");
        require(!contains(list, value_), "SLL:P:VALUE_EXISTS");
        require(value_ > tail_,          "SLL:P:NOT_LARGEST");

        list.nodes[value_] = Node({
            next:   0,
            prev:   tail_,
            exists: true
        });

        if (tail_ != 0) {
            list.nodes[tail_].next = value_;
        }

        list.tail = value_;

        if (list.head == 0) {
            list.head = value_;
        }

        list.size++;
    }

    /**
     * @dev   Removes a value from the list in O(1) time.
     * @param list   The list to remove the value from.
     * @param value_ The value to remove from the list.
     */
    function remove(List storage list, uint128 value_) internal {
        require(contains(list, value_), "SLL:R:VALUE_NOT_EXISTS");

        uint128 prev_ = list.nodes[value_].prev;
        uint128 next_ = list.nodes[value_].next;

        if (prev_ != 0) {
            list.nodes[prev_].next = next_;
        } else {
            list.head = next_;
        }

        if (next_ != 0) {
            list.nodes[next_].prev = prev_;
        } else {
            list.tail = prev_;
        }

        delete list.nodes[value_];
        list.size--;
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     * @dev    Gets the length of the list.
     * @param  list    The list to get the length of.
     * @return length_ The length of the list.
     */
    function length(List storage list) internal view returns (uint256 length_) {
        length_ = list.size;
    }

    /**
     * @dev    Gets all values from the list.
     * @param  list    The list to get the values from.
     * @return values_ All values from the list.
     */
    function getAllValues(List storage list) internal view returns (uint128[] memory values_) {
        values_ = new uint128[](list.size);

        uint128 current_ = list.head;
        uint256 size_    = list.size;

        for (uint256 i = 0; i < size_; i++) {
            values_[i] = current_;
            current_   = list.nodes[current_].next;
        }
    }

    /**
     * @dev    Gets values from the list with pagination.
     * @param  list    The list to get the values from.
     * @param  start_  Number of elements to skip from the head.
     * @param  limit_  Maximum number of elements to return.
     * @return values_ Paginated values from the list.
     */
    function getValues(List storage list, uint256 start_, uint256 limit_) internal view returns (uint128[] memory values_) {
        uint256 total_ = list.size;

        if (start_ >= total_ || limit_ == 0) return new uint128[](0);

        uint256 available_ = total_ - start_;
        uint256 size_      = limit_ < available_ ? limit_ : available_;

        values_ = new uint128[](size_);

        uint128 current_ = list.head;
        uint256 skipped_;
        uint256 index_;

        while (current_ != 0 && index_ < size_) {
            if (skipped_ < start_) {
                ++skipped_;
            } else {
                values_[index_] = current_;
                ++index_;
            }

            current_ = list.nodes[current_].next;
        }
    }

    /**
     * @dev    Gets the last value in the list.
     * @param  list   The list to get the last value from.
     * @return value_ The last value in the list.
     */
    function getLast(List storage list) internal view returns (uint128 value_) {
        value_ = list.tail;
    }

    /**
     * @dev    Checks if a value exists in the list.
     * @param  list    The list to check.
     * @param  value_  The value to check for.
     * @return exists_ True if the value exists in the list.
     */
    function contains(List storage list, uint128 value_) internal view returns (bool exists_) {
        exists_ = list.nodes[value_].exists;
    }

}
