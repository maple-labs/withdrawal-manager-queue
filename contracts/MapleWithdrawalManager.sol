// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper }           from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleWithdrawalManager } from "./interfaces/IMapleWithdrawalManager.sol";

import {
    IERC20Like,
    IGlobalsLike,
    IPoolLike,
    IPoolManagerLike
} from "./interfaces/Interfaces.sol";

import { MapleWithdrawalManagerStorage } from "./proxy/MapleWithdrawalManagerStorage.sol";

import { SortedLinkedList } from "./utils/SortedLinkedList.sol";

/*

    ███╗   ███╗ █████╗ ██████╗ ██╗     ███████╗
    ████╗ ████║██╔══██╗██╔══██╗██║     ██╔════╝
    ██╔████╔██║███████║██████╔╝██║     █████╗
    ██║╚██╔╝██║██╔══██║██╔═══╝ ██║     ██╔══╝
    ██║ ╚═╝ ██║██║  ██║██║     ███████╗███████╗
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝

    ██╗    ██╗██╗████████╗██╗  ██╗██████╗ ██████╗  █████╗ ██╗    ██╗ █████╗ ██╗
    ██║    ██║██║╚══██╔══╝██║  ██║██╔══██╗██╔══██╗██╔══██╗██║    ██║██╔══██╗██║
    ██║ █╗ ██║██║   ██║   ███████║██║  ██║██████╔╝███████║██║ █╗ ██║███████║██║
    ██║███╗██║██║   ██║   ██╔══██║██║  ██║██╔══██╗██╔══██║██║███╗██║██╔══██║██║
    ╚███╔███╔╝██║   ██║   ██║  ██║██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║  ██║███████╗
    ╚══╝╚══╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝

    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗
    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝

    ██╗   ██╗██████╗  ██████╗  ██████╗
    ██║   ██║╚════██╗██╔═████╗██╔═████╗
    ██║   ██║ █████╔╝██║██╔██║██║██╔██║
    ╚██╗ ██╔╝██╔═══╝ ████╔╝██║████╔╝██║
    ╚████╔╝ ███████╗╚██████╔╝╚██████╔╝
    ╚═══╝  ╚══════╝ ╚═════╝  ╚═════╝

*/

contract MapleWithdrawalManager is IMapleWithdrawalManager, MapleWithdrawalManagerStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "WM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyPoolDelegateOrOperationalAdmin {
        address globals_ = globals();

        require(
            msg.sender == IPoolManagerLike(poolManager).poolDelegate() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "WM:NOT_POOL_DELEG_OR_OPS_ADMIN"
        );

        _;
    }

    modifier onlyPoolManager {
        require(msg.sender == poolManager, "WM:NOT_PM");

        _;
    }

    modifier onlyRedeemer {
        address globals_ = globals();

        require(
            IGlobalsLike(globals_).isInstanceOf("WITHDRAWAL_REDEEMER", msg.sender) ||
            msg.sender == IPoolManagerLike(poolManager).poolDelegate() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "WM:NOT_REDEEMER"
        );

        _;
    }

    modifier whenProtocolNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "WM:PAUSED");
        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenProtocolNotPaused {
        require(msg.sender == _factory(),        "WM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "WM:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenProtocolNotPaused {
        require(msg.sender == _factory(), "WM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenProtocolNotPaused {
        address poolDelegate_ = poolDelegate();

        require(msg.sender == poolDelegate_ || msg.sender == securityAdmin(), "WM:U:NOT_AUTHORIZED");

        IGlobalsLike mapleGlobals_ = IGlobalsLike(globals());

        if (msg.sender == poolDelegate_) {
            require(mapleGlobals_.isValidScheduledCall(msg.sender, address(this), "WM:UPGRADE", msg.data), "WM:U:INVALID_SCHED_CALL");

            mapleGlobals_.unscheduleCall(msg.sender, "WM:UPGRADE", msg.data);
        }

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions - OnlyPoolManager                                                                                     ***/
    /**************************************************************************************************************************************/

    function addShares(uint256 shares_, address owner_) external override onlyPoolManager returns (uint256 lastRequestId_) {
        require(shares_ > 0, "WM:AS:ZERO_SHARES");

        lastRequestId_ = _addRequest(owner_, shares_);
    }

    function processExit(
        uint256 shares_,
        address owner_
    )
        external override onlyPoolManager returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        ( redeemableShares_, resultingAssets_ ) = owner_ == address(this)
            ? _calculateRedemption(shares_)
            : _processManualExit(shares_, owner_);
    }

    function removeShares(uint256 shares_, address owner_) external override onlyPoolManager returns (uint256 sharesReturned_) {
        require(shares_ > 0, "WM:RS:ZERO_SHARES");

        uint256 totalEscrowedShares_ = userEscrowedShares[owner_];

        require(totalEscrowedShares_ >= shares_, "WM:RS:INSUFFICIENT_SHARES");

        while (sharesReturned_ < shares_) {
            uint256 requestId_                = SortedLinkedList.getLast(_userRequests[owner_]);
            WithdrawalRequest memory request_ = _queue.requests[_toUint128(requestId_)];

            uint256 sharesToRemove_ = _min(shares_ - sharesReturned_, request_.shares);
            sharesReturned_        += _removeShares(requestId_, sharesToRemove_, owner_, request_.shares);
        }
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions - OnlyRedeemer                                                                                        ***/
    /**************************************************************************************************************************************/

    function processRedemptions(uint256[] calldata requestIds_) external override whenProtocolNotPaused nonReentrant onlyRedeemer {
        require(requestIds_.length > 0, "WM:PR:ZERO_REQUESTS");

        uint256 totalSharesToProcess_;

        for (uint256 i = 0; i < requestIds_.length; ++i) {
            WithdrawalRequest memory request_ = _queue.requests[_toUint128(requestIds_[i])];

            if (request_.owner == address(0)) continue;

            totalSharesToProcess_ += request_.shares;
        }

        if (totalSharesToProcess_ == 0) return;

        ( uint256 redeemableShares_, uint256 totalAssets_ ) = _calculateRedemption(totalSharesToProcess_);

        // Revert if there are insufficient assets to redeem all shares.
        require(totalSharesToProcess_ == redeemableShares_, "WM:PR:LOW_LIQUIDITY");

        for (uint256 i = 0; i < requestIds_.length; ++i) {
            uint256 requestId_ = requestIds_[i];

            WithdrawalRequest memory request_ = _queue.requests[_toUint128(requestId_)];

            if (request_.owner == address(0)) continue;

            uint256 assetsForManual_;

            if (isManualWithdrawal[request_.owner]) {
                assetsForManual_ = totalAssets_ * request_.shares / totalSharesToProcess_; // This value is only used for emitting events.
            }

            _processRequest(requestId_, request_, assetsForManual_);
        }
    }

    // NOTE: Not to be used in a router based system where the router is managing user requests.
    function removeRequest(
        address owner_,
        uint256[] calldata requestIds_
    )
        external override whenProtocolNotPaused onlyRedeemer
    {
        require(owner_ != address(0),   "WM:RR:ZERO_OWNER");
        require(requestIds_.length > 0, "WM:RR:ZERO_REQUESTS");

        uint256 sharesToRemove_;

        WithdrawalRequest memory withdrawalRequest_;

        for (uint256 i = 0; i < requestIds_.length; ++i) {
            withdrawalRequest_ = _queue.requests[_toUint128(requestIds_[i])];

            require(withdrawalRequest_.shares > 0,      "WM:RR:NOT_IN_QUEUE");
            require(withdrawalRequest_.owner == owner_, "WM:RR:NOT_OWNER");

            _removeRequest(owner_, requestIds_[i]);

            sharesToRemove_ += withdrawalRequest_.shares;
        }

        require(ERC20Helper.transfer(pool, owner_, sharesToRemove_), "WM:RR:TRANSFER_FAIL");

        totalShares -= sharesToRemove_;
    }

    function setManualWithdrawal(
        address owner_,
        bool isManual_
    )
        external override whenProtocolNotPaused onlyPoolDelegateOrOperationalAdmin
    {
        isManualWithdrawal[owner_] = isManual_;

        emit ManualWithdrawalSet(owner_, isManual_);
    }

    /**************************************************************************************************************************************/
    /*** Unprivileged External Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function removeSharesById(
        uint256 requestId_,
        uint256 sharesToRemove_
    )
        external override whenProtocolNotPaused nonReentrant returns (uint256 sharesReturned_, uint256 sharesRemaining_)
    {
        WithdrawalRequest memory request_ = _queue.requests[_toUint128(requestId_)];

        require(request_.owner != address(0),       "WM:RSBI:INVALID_REQUEST");
        require(request_.owner == msg.sender,       "WM:RSBI:NOT_OWNER");
        require(sharesToRemove_ != 0,               "WM:RSBI:NO_CHANGE");
        require(sharesToRemove_ <= request_.shares, "WM:RSBI:INSUFFICIENT_SHARES");

        // Removes shares and will cancel the request if there are no shares remaining.
        sharesReturned_  = _removeShares(requestId_, sharesToRemove_, request_.owner, request_.shares);
        sharesRemaining_ = request_.shares - sharesToRemove_;
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _addRequest(address owner_, uint256 shares_) internal returns (uint256 lastRequestId_) {
        lastRequestId_ = ++_queue.lastRequestId;

        _queue.requests[_toUint128(lastRequestId_)] = WithdrawalRequest(owner_, shares_);
        userEscrowedShares[owner_]                 += shares_;

        SortedLinkedList.push(_userRequests[owner_], _toUint128(lastRequestId_));
        SortedLinkedList.push(_pendingRequestIds,    _toUint128(lastRequestId_));

        // Increase the number of shares locked.
        totalShares += shares_;

        require(ERC20Helper.transferFrom(pool, msg.sender, address(this), shares_), "WM:AS:FAILED_TRANSFER");

        emit RequestCreated(lastRequestId_, owner_, shares_);
    }

    function _removeShares(
        uint256 requestId_,
        uint256 sharesToRemove_,
        address owner_,
        uint256 currentShares_
    )
        internal returns (uint256 sharesReturned_)
    {
        uint256 sharesRemaining_ = currentShares_ - sharesToRemove_;

        totalShares -= sharesToRemove_;

        // If there are no shares remaining, cancel the withdrawal request.
        if (sharesRemaining_ == 0) {
            _removeRequest(owner_, requestId_);
        } else {
            _queue.requests[_toUint128(requestId_)].shares = sharesRemaining_;
            userEscrowedShares[owner_]                    -= sharesToRemove_;

            emit RequestDecreased(requestId_, sharesToRemove_);
        }

        require(ERC20Helper.transfer(pool, owner_, sharesToRemove_), "WM:RS:TRANSFER_FAIL");

        sharesReturned_ = sharesToRemove_;
    }

    function _calculateRedemption(uint256 sharesToRedeem_) internal view returns (uint256 redeemableShares_, uint256 resultingAssets_) {
        IPoolManagerLike poolManager_ = IPoolManagerLike(poolManager);

        uint256 totalSupply_           = IPoolLike(pool).totalSupply();
        uint256 totalAssetsWithLosses_ = poolManager_.totalAssets() - poolManager_.unrealizedLosses();
        uint256 availableLiquidity_    = IERC20Like(asset()).balanceOf(pool);
        uint256 requiredLiquidity_     = totalAssetsWithLosses_ * sharesToRedeem_ / totalSupply_;

        bool partialLiquidity_ = availableLiquidity_ < requiredLiquidity_;

        redeemableShares_ = partialLiquidity_ ? sharesToRedeem_ * availableLiquidity_ / requiredLiquidity_ : sharesToRedeem_;
        resultingAssets_  = totalAssetsWithLosses_ * redeemableShares_  / totalSupply_;
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function _processManualExit(
        uint256 shares_,
        address owner_
    )
        internal returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        require(shares_ > 0,                              "WM:PE:NO_SHARES");
        require(shares_ <= manualSharesAvailable[owner_], "WM:PE:TOO_MANY_SHARES");

        ( redeemableShares_ , resultingAssets_ ) = _calculateRedemption(shares_);

        require(shares_ == redeemableShares_, "WM:PE:NOT_ENOUGH_LIQUIDITY");

        manualSharesAvailable[owner_] -= redeemableShares_;

        emit ManualSharesDecreased(owner_, redeemableShares_);

        // Unlock the reserved shares.
        totalShares -= redeemableShares_;

        require(ERC20Helper.transfer(pool, owner_, redeemableShares_), "WM:PE:TRANSFER_FAIL");
    }

    function _processRequest(uint256 requestId_, WithdrawalRequest memory request_, uint256 assetsForManual_) internal {
        uint256 assets_;

        // If the owner opts for manual redemption, increase the account's available shares.
        if (isManualWithdrawal[request_.owner]) {
            manualSharesAvailable[request_.owner] += request_.shares;

            emit ManualSharesIncreased(requestId_, request_.owner, request_.shares);
            assets_ = assetsForManual_;
        } else {
            // Otherwise, just adjust totalShares and perform the redeem.
            totalShares -= request_.shares;

            assets_ = IPoolLike(pool).redeem(request_.shares, request_.owner, address(this));
        }

        emit RequestProcessed(requestId_, request_.owner, request_.shares, assets_);

        _removeRequest(request_.owner, requestId_);
    }

    function _removeRequest(address owner_, uint256 requestId_) internal {
        uint128 requestId__ = _toUint128(requestId_);

        userEscrowedShares[owner_] -= _queue.requests[requestId__].shares;

        SortedLinkedList.remove(_userRequests[owner_], requestId__);
        SortedLinkedList.remove(_pendingRequestIds,    requestId__);
        delete _queue.requests[requestId__];

        emit RequestRemoved(requestId_);
    }

    function _toUint128(uint256 input_) internal pure returns (uint128 output_) {
        require(input_ <= uint256(type(uint128).max), "WM:TU:UINT256_CAST");
        output_ = uint128(input_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function asset() public view override returns (address asset_) {
        asset_ = IPoolLike(pool).asset();
    }

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IMapleProxyFactory(_factory()).mapleGlobals();
    }

    function governor() public view override returns (address governor_) {
        governor_ = IGlobalsLike(globals()).governor();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function maxRedeem(address owner_) external view override returns (uint256 maxRedeemableShares_) {
        maxRedeemableShares_ = manualSharesAvailable[owner_];
    }

    function poolDelegate() public view override returns (address poolDelegate_) {
        poolDelegate_ = IPoolManagerLike(poolManager).poolDelegate();
    }

    function pendingRequestIds(uint256 start_, uint256 limit_)
        external view override returns (
            uint256[] memory requestIds_,
            address[] memory owners_,
            uint256[] memory shares_
        )
    {
        uint128[] memory pendingRequestIds_ = SortedLinkedList.getValues(_pendingRequestIds, start_, limit_);

        requestIds_ = new uint256[](pendingRequestIds_.length);
        owners_     = new address[](pendingRequestIds_.length);
        shares_     = new uint256[](pendingRequestIds_.length);

        for (uint256 i = 0; i < pendingRequestIds_.length; ++i) {
            requestIds_[i] = pendingRequestIds_[i];
            owners_[i]     = _queue.requests[pendingRequestIds_[i]].owner;
            shares_[i]     = _queue.requests[pendingRequestIds_[i]].shares;
        }
    }

    function previewRedeem(
        address owner_,
        uint256 shares_
    )
        public view override returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        uint256 sharesAvailable_ = manualSharesAvailable[owner_];

        if (sharesAvailable_ == 0) return ( 0, 0 );

        require(shares_ <= sharesAvailable_, "WM:PR:TOO_MANY_SHARES");

        ( redeemableShares_, resultingAssets_ ) = _calculateRedemption(shares_);  // NOTE: Recommend using convertToExitAssets instead
    }

    function previewWithdraw(address owner_, uint256 assets_)
        external pure override returns (uint256 redeemableAssets_, uint256 resultingShares_)
    {
        owner_; assets_; redeemableAssets_; resultingShares_;  // Silence compiler warnings
        return ( redeemableAssets_, resultingShares_ );  // NOTE: Withdrawal not implemented use redeem instead
    }

    function queue() external view override returns (uint128 nextRequestId_, uint128 lastRequestId_) {
        lastRequestId_ = _queue.lastRequestId;
        nextRequestId_ = _pendingRequestIds.head;

        if (nextRequestId_ == 0) nextRequestId_ = lastRequestId_ + 1;
    }

    function requestIds(address owner_) external view override returns (uint256 requestId_) {
        requestId_ = SortedLinkedList.getLast(_userRequests[owner_]);
    }

    function requests(uint256 requestId_) external view override returns (address owner_, uint256 shares_) {
        owner_  = _queue.requests[_toUint128(requestId_)].owner;
        shares_ = _queue.requests[_toUint128(requestId_)].shares;
    }

    function requestsByOwner(address owner_) external view override returns (uint256[] memory requestIds_, uint256[] memory shares_) {
        uint128[] memory requestIdsByOwner_ = SortedLinkedList.getAllValues(_userRequests[owner_]);

        requestIds_ = new uint256[](requestIdsByOwner_.length);
        shares_     = new uint256[](requestIdsByOwner_.length);

        for (uint256 i = 0; i < requestIdsByOwner_.length; ++i) {
            requestIds_[i] = requestIdsByOwner_[i];
            shares_[i]     = _queue.requests[requestIdsByOwner_[i]].shares;
        }
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

}
