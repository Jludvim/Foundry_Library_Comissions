//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {AuthorComissions} from "../src/AuthorComissions.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DeployAuthorComissions is Script{
    function run(address owner) external returns (AuthorComissions){

        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        
        vm.startBroadcast(owner);
        AuthorComissions authorComissions = new AuthorComissions(AggregatorV3Interface(ethUsdPriceFeed));
        vm.stopBroadcast();

        return authorComissions;
        
    }
}