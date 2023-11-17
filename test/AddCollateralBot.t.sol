// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "@forge-std/Test.sol";
import "forge-std/console.sol";

import {AddCollateralBot} from "../src/AddCollateralBot.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {CreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacadeV3.sol";
import {CreditManagerV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditManagerV3.sol";
import {BotListV3} from "@gearbox-protocol/core-v3/contracts/core/BotListV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {IBotListV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IBotListV3.sol";

contract AddCollateralBotTest is Test {
    AddCollateralBot private bot;
    CreditManagerV3 private manager;
    CreditFacadeV3 private facade;

    address private constant CREDIT_MANAGER = 0x6A489b262A02549c59579811Aa304BF995dbb304; // WETH credit manager
    address private constant CREDIT_FACADE = 0x09a080B42909d12CbDc0c0BB2540FeD129CeaeFB;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address private constant USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private constant EXECUTOR = 0x087F5052fBcD7C02DD45fb9907C57F1EccC2bE25;
    address private constant VITALIK = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    uint192 ADD_COLLATERAL_PERMISSION = 1;
    uint192 REVOKE_ALLOWANCES_PERMISSION = 1 << 7;
    uint192 EXTERNAL_CALLS_PERMISSION = 1 << 16;

    /// ----- ///
    /// SETUP ///
    /// ----- ///

    function setUp() public {
        bot = new AddCollateralBot();
    }

    function test_addCollateral() public {
        MultiCall[] memory calls;
        vm.startPrank(USER);

        console.log(IERC20(DAI).balanceOf(VITALIK));
        console.log(IERC20(USDT).balanceOf(VITALIK));
        console.log(IERC20(USDT).balanceOf(USER));

        // console.log()
        address creditAccountCreated =
            CreditFacadeV3(CREDIT_FACADE).openCreditAccount{value: 1000000000000000000000}(USER, calls, 0);
        console.log(creditAccountCreated);

        uint256 balanceOfUserBefore = IERC20(WETH).balanceOf(USER);
        console.log(balanceOfUserBefore);

        // MultiCall[] memory callsForAddingCollateral = new MultiCall[](1);

        // callsForAddingCollateral[0] = MultiCall({
        //     target: CREDIT_FACADE,
        //     callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (WETH, balanceOfUserBefore))
        // });

        // IERC20(WETH).approve(CREDIT_MANAGER, balanceOfUserBefore);
        IERC20(WETH).approve(address(bot), balanceOfUserBefore);

        // CreditFacadeV3(CREDIT_FACADE).multicall(creditAccountCreated, callsForAddingCollateral);

        uint192 permissionsBitmask =
            ADD_COLLATERAL_PERMISSION | REVOKE_ALLOWANCES_PERMISSION | EXTERNAL_CALLS_PERMISSION;

        CreditFacadeV3(CREDIT_FACADE).setBotPermissions(creditAccountCreated, address(bot), permissionsBitmask);
        vm.stopPrank();

        address botList = CreditFacadeV3(CREDIT_FACADE).botList();
        console.log(address(bot));
        (uint192 permissions, bool forbidden, bool hasSpecialPermissions) =
            IBotListV3(botList).getBotStatus(address(bot), CREDIT_MANAGER, creditAccountCreated);
        console.log(permissionsBitmask);
        console.log(permissions);
        console.log(forbidden);
        console.log(hasSpecialPermissions);

        vm.startPrank(EXECUTOR);

        bot.addCollateral(WETH, CREDIT_MANAGER, balanceOfUserBefore, creditAccountCreated, USER);

        uint256 balanceOfUserAfter = IERC20(WETH).balanceOf(USER);
        console.log(balanceOfUserAfter);
        vm.stopPrank();
    }
}
