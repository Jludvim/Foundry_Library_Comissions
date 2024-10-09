//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AuthorComissions} from "../../src/AuthorComissions.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployAuthorComissions} from "../../script/DeployAuthorComissions.s.sol";

contract AuthorComissionsTest is Test {
address manager;
AuthorComissions authorComissions;
DeployAuthorComissions deployAuthorComissions;
address payable LIBRARY= payable(makeAddr("user"));
address payable AUTHOR = payable(makeAddr("author"));
uint256 constant SEND_VALUE = 0.1 ether;
uint256 constant STARTING_BALANCE=10 ether;
uint256 constant GAS_PRICE = 1;
uint256 constant COMISSION_SET = 5;

function setUp() external{
vm.prank(manager);
authorComissions = deployAuthorComissions.run();
authorComissions.addLibrary(LIBRARY, "Saint Anthony Local Library", COMISSION_SET);
authorComissions.addAuthor("Alice James", AUTHOR);
vm.deal(LIBRARY, STARTING_BALANCE);
}



function testLibraryCanMakeADeposit() public {
    vm.prank(LIBRARY);
    authorComissions.addCapital{value: SEND_VALUE}();

    vm.prank(manager);
    assertEq(authorComissions.getBalance(LIBRARY), SEND_VALUE);
}

}