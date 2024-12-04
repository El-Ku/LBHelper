// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "../forge-std/Script.sol";
import {Pool} from "../src/Pool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployPool is Script {
    function run()
        external
        returns (Pool pool, ERC20Mock lenderToken, ERC20Mock collateralToken)
    {
        pool = deployPool();
        lenderToken = deployToken();
        collateralToken = deployToken();
    }

    function deployPool() internal returns (Pool) {
        vm.startBroadcast();
        Pool pool = new Pool();
        vm.stopBroadcast();
        return pool;
    }

    function deployToken() internal returns (ERC20Mock) {
        vm.startBroadcast();
        ERC20Mock token = new ERC20Mock();
        vm.stopBroadcast();
        return token;
    }
}
