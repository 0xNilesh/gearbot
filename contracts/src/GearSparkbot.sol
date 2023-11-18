// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Balance} from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";
import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import "@aave/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool as ISparkPool} from "@spark/ISparkPool.sol";
import "forge-std/console.sol";

contract GearSparkBot {
    ISparkPool private sparkPool;

    constructor(address _sparkPool) {
        sparkPool = ISparkPool(_sparkPool);
    }

    function executeTrade(
        address _token,
        uint256 _amount,
        address _creditManager,
        address _creditAccount,
        address _ownerOfCreditAccount
    ) external {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = _encode(_creditManager, _creditAccount, _ownerOfCreditAccount);
        uint16 referralCode = 0;

        console.log(_creditManager);

        sparkPool.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        //Logic goes here

        uint256 totalAmount = amount + premium;
        // console.log(IERC20(asset).balanceOf(address(this)));
        // console.log(asset);
        // console.log(amount);
        // console.log(premium);
        // console.log(initiator);
        // console.log(address(this));
        _executeStrategy(params, asset, amount);
        IERC20(asset).approve(address(sparkPool), totalAmount);

        return true;
    }

    function _executeStrategy(bytes calldata params, address _token, uint256 _amount) internal {
        (address _creditManager, address _creditAccount, address _ownerOfCreditAccount) = _decode(params);

        addCollateral(_token, _creditManager, _amount, _creditAccount, _ownerOfCreditAccount);

        address facade = ICreditManagerV3(_creditManager).creditFacade();
        (uint128 minDebt, uint128 maxDebt) = ICreditFacadeV3(facade).debtLimits();

        enableTokens(_creditManager, 0x6B175474E89094C44Da98b954EedeAC495271d0F, _creditAccount);

        borrowFunds(_creditManager, 1e21, _creditAccount);

        withdrawCollateral(_token, _creditManager, _amount, _creditAccount, address(this));

        // addCollateral(_token, _creditManager, 1e21, _creditAccount, _ownerOfCreditAccount);

        // console.log(IERC20(_token).balanceOf(address(this)));
    }

    /// @notice Adds collateral using bot
    /// @param _token token address
    /// @param _creditManager manager address
    /// @param _tokenAmount amount of token
    /// @param _creditAccount address of credit account
    /// @param _ownerOfCreditAccount address of credit account's owner
    function addCollateral(
        address _token,
        address _creditManager,
        uint256 _tokenAmount,
        address _creditAccount,
        address _ownerOfCreditAccount
    ) public {
        // IERC20(_token).transferFrom(
        //     _ownerOfCreditAccount,
        //     address(this),
        //     _tokenAmount
        // );
        IERC20(_token).approve(_creditManager, _tokenAmount);

        MultiCall[] memory calls = new MultiCall[](1);

        address facade = ICreditManagerV3(_creditManager).creditFacade();

        console.log(facade);

        calls[0] = MultiCall({
            target: facade,
            callData: abi.encodeCall(
                ICreditFacadeV3Multicall.addCollateral,
                (_token, _tokenAmount)
            )
        });

        ICreditFacadeV3(facade).botMulticall(_creditAccount, calls);
    }

    /// @notice Withdraw collateral using bot
    /// @param _token token address
    /// @param _creditManager manager address
    /// @param _tokenAmount amount of token
    /// @param _creditAccount address of credit account
    /// @param _withdrawAccount address of credit account's owner
    function withdrawCollateral(
        address _token,
        address _creditManager,
        uint256 _tokenAmount,
        address _creditAccount,
        address _withdrawAccount
    ) public {
        MultiCall[] memory calls = new MultiCall[](1);

        address facade = ICreditManagerV3(_creditManager).creditFacade();

        calls[0] = MultiCall({
            target: facade,
            callData: abi.encodeCall(
                ICreditFacadeV3Multicall.withdrawCollateral,
                (_token, _tokenAmount, _withdrawAccount)
            )
        });

        ICreditFacadeV3(facade).botMulticall(_creditAccount, calls);
    }

    /// @notice Borrow funds using bot
    /// @param _creditManager manager address
    /// @param _tokenAmount amount of token
    /// @param _creditAccount address of credit account
    function borrowFunds(
        address _creditManager,
        uint256 _tokenAmount,
        address _creditAccount
    ) public {
        MultiCall[] memory calls = new MultiCall[](1);

        address facade = ICreditManagerV3(_creditManager).creditFacade();

        calls[0] = MultiCall({
            target: facade,
            callData: abi.encodeCall(
                ICreditFacadeV3Multicall.increaseDebt,
                (_tokenAmount)
            )
        });

        ICreditFacadeV3(facade).botMulticall(_creditAccount, calls);
    }

    /// @notice Borrow funds using bot
    /// @param _creditManager manager address
    /// @param _token amount of token
    /// @param _creditAccount address of credit account
    function enableTokens(
        address _creditManager,
        address _token,
        address _creditAccount
    ) public {
        MultiCall[] memory calls = new MultiCall[](1);

        address facade = ICreditManagerV3(_creditManager).creditFacade();

        calls[0] = MultiCall({
            target: facade,
            callData: abi.encodeCall(
                ICreditFacadeV3Multicall.enableToken,
                (_token)
            )
        });

        ICreditFacadeV3(facade).botMulticall(_creditAccount, calls);
    }

    /// @notice Repay funds using bot
    /// @param _creditManager manager address
    /// @param _tokenAmount amount of token
    /// @param _creditAccount address of credit account
    function repayFunds(
        address _creditManager,
        uint256 _tokenAmount,
        address _creditAccount
    ) public {
        MultiCall[] memory calls = new MultiCall[](1);

        address facade = ICreditManagerV3(_creditManager).creditFacade();

        calls[0] = MultiCall({
            target: facade,
            callData: abi.encodeCall(
                ICreditFacadeV3Multicall.decreaseDebt,
                (_tokenAmount)
            )
        });

        ICreditFacadeV3(facade).botMulticall(_creditAccount, calls);
    }

    /// @notice Execute
    /// @param _creditManager manager address
    /// @param _creditAccount address of credit account
    /// @param _target target address to call
    /// @param _calldata calldata to send in muticall
    function execute(
        address _creditManager,
        address _creditAccount,
        address _target,
        bytes calldata _calldata
    ) external {
        MultiCall[] memory calls = new MultiCall[](1);

        address facade = ICreditManagerV3(_creditManager).creditFacade();

        calls[0] = MultiCall({target: _target, callData: _calldata});

        ICreditFacadeV3(facade).botMulticall(_creditAccount, calls);
    }

    function _encode(
        address _creditManager,
        address _creditAccount,
        address _ownerOfCreditAccount
    ) internal pure returns (bytes memory) {
        return (
            abi.encode(_creditManager, _creditAccount, _ownerOfCreditAccount)
        );
    }

    function _decode(
        bytes memory data
    )
        internal
        pure
        returns (
            address _creditManager,
            address _creditAccount,
            address _ownerOfCreditAccount
        )
    {
        (_creditManager, _creditAccount, _ownerOfCreditAccount) = abi.decode(
            data,
            (address, address, address)
        );
    }

    receive() external payable {}
}
