// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


/*
* The contract has been taken from Patrick@Cyfrin
* getInverseConversionRate was added to it.
*/
//import {AggregatorV3Interface} from "@chainlink/interfaces/AggregatorV3Interface.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


//I'm currently checking what the aggregatorV3Interface latestRoundData returns, 
//to see if getInverseConversionRate is correct.

library PriceConverter {

    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        // Sepolia ETH / USD Address
        // https://docs.chain.link/data-feeds/price-feeds/addresses
     //   AggregatorV3Interface priceFeed = AggregatorV3Interface(
      //      0x694AA1769357215DE4FAC081bf1f309aDC325306
       // );
        (, int256 answer, , , ) = priceFeed.latestRoundData();

        // ETH/USD rate in 18 digit
        return uint256(answer * 10000000000);
    }

    // 1000000000
    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        // the actual ETH/USD conversion rate, after adjusting the extra 0s.
        return ethAmountInUsd;
    }

}