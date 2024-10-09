//SPDX-License-Identifier: Apache-2.0

/**
 * @title: AuthorComissions
 * @author: Jeremias Pini
 * @license: Apache License 2.0
 */

/**
 * Development notes:
 * 
 * program whose aim is to provide a platform for authors to get a comission on the transactions made
 * within a library, and the books that are lent to the readers.
 * The PLAN would be to create a mapping of addresses from book to the address of registered authors,
 * so that through a platform they can receive a small sum for every book of them that is lended.
 * This could also imply that daily transactions in libraries would have to be made through the
 * blockchain, if this would carry any force. OR that the system through which the payments are delivered does 
 * deliver onchain data.
 * OR if the transactions are not made through the blockchain, then at least, be "notified" in some manner
 *  through the blockchain. Reducing the extra work and liability for the libraries would no doubt be 
 * one aim in interests of the project.
 * Using the AggregatorV3Interface it could be possible to define in USD the fix comission each library
 * might determine to add onto their current pricing, to know how much to transfer.
 * 
 *
 * 
 * 
 * Definition of the system requirements:
 * It would be needed of the program to register libraries, authors, and books.
 * Registration could be manually done. An authomatic proccess
 * Would be even better.
 * Registration could be done with the assertion performed with another system,
 * or setting a registration formal proccess performed by the project personnel, or both.
 * Registration of books could be related to the registration of authors.
 * The only use of the library funds will be paying the mentioned comissions. Nothing else
 * The contract could charge a small sums to registering authors.
 * The contract needs to allow books to receive payments from the libraries. Receive those payments in the contract, 
 * deliver to the authors.
 * 
 * To allow books to send payments knowing the author of the book/book itself.
 * MAYBE, allow users to send donations to the authors they like. Might be a more exposed dynamic, and more risky.
 * 
 * 
 * 
 * 
 * The system could even futurely be expanded to something similar, and yet slightly different for donations:
 * Register a set of addresses for any particular project (think a movie),
 *  receive the authorization from all those addresses,
 * and allow the participants of the aforementioned project to receive donations in relation to their work in the project
 * and according to the split they could have previously defined or hereby define for the donations.
 * Sounds akin to paying for the product, but without the material expenses, and changing "for" to "to"
 * Yet, in this identity assertions might be an actual headache. And wherever this becomes freer, it would need an oracle
 * or datafeed that could solve this. At least for copyright holders, it doesn't seem like a solved problem as far as I could see.
 * 
 * 
 *
 * 
 * Problems: 
 * There is little benefit and incentive for the libraries
 * It might possibly be tolerable as far as the economic situation, both nationally and internally for a library 
 * allows it, and more so if it was a complete software with administrative benefits.
 * 
 * It might be wise to create a full suite for library management accompanied by this feature,
 * that could be the main innovation of the project.
 * 
 * 
 * Is there any way to on-board authors in a decentralized way into the project? 
 * Seems hardly possible, unless we find a way to confirm the identity of an account holder, and contrast it
 * with the copyright holder of the book.  
 * 
 * Perhaps something accross the lines of an association between
 *  the copyright holder and wallets can be an interesting project
 * 
 * 
 * 
 * Is it possible to in a decentralized manner on board authors?
 * Is it possible to in a decentralized manner on board libraries?
 * A possible solution could be through the growth of the project / network, and in democratic representation
 * of the relevant investors of the protoccol (i.e. participating libraries in our case)
 * 
 * ISSUES:
 * The repo needs to get some order, its really messy.
 * It needs debugging.
 * It looks like the mappings and declarations have redundancies. And some things could be simpler than they are. 
 * 
 * Requirements of the main users of this contract:
 * Libraries: load cash, extract cash, send donation to author, register, unregister
 * Author: extract funds,   register, unregister,     load books, unload books
 * Administrator (decentralized): register, unregister      Load books / unload them?
 * A way to safely register/unregister, and load/unload data that is also decentralized is needed
 */



pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../src/PriceConverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AuthorComissions is Ownable, ReentrancyGuard{

  address s_owner;
  //address[] private s_libraries;
  //address[] private s_authors;

//It might be wise to define an external index, non related to the storage
  struct Book{
    string s_bookTitle;
    string s_authorName;
    uint256 s_id;
    address author;
  }

  /*mapping that defines a mapping from referencing index aka ID (never changing for stability and security reasons)
   to the real data storage index (might change with deletions)*/
  mapping(uint256 virtualIndex => uint256 realIndex) private indexToStorageIndex;

  Book[] s_books;

  AggregatorV3Interface public s_priceFeed;

  uint256 public constant MINIMUM_USD = 10e18;
  
  error HasntEnoughBalance();
  error AddressIsntARegisteredLibrary();
  error AddressIsntARegisteredAuthor();
  error AddressCantWithdraw();
  error BalanceIsLessThanSetComission();
  error BelowMinValue();
  error WithdrawalFailed();
  error AddressCantGetBalance();

  //address to boolean describing whether the address is part of the protocol
  //Currently, probably all the checks featuring this might be replaceable with something else, to avoid having these
  //two. 
  mapping(address => bool) private isLibrary;
  mapping(address => bool) private isAuthor;

  //These Store the balance of an address, and the NAME of the address defined in the protocol 
  //Both mappings work for libraries and authors
  mapping(address => uint256) private addressToBalance;
  mapping(address => string) private addressToName; //particularly useful for authors
  
  //Returns the comission value that the library sets for their own contributions
  mapping(address => uint256) private libraryComissionInUsd;

  //Gets exact names for books registered for that author, useful for transactions.
  //It is necessary to remove books written by an author from the contract.

  mapping(address author => uint256[] books) public authorToBooks;
  mapping(string book => string author) public bookToAuthor;


  /*Internally relevant for the contract, does fetch the address(es) to deposit to based on the bookname*/
  mapping(string bookname => mapping(string authorname => address authorsAddress)) private bookToAuthorsAddress;



///////////////////////////////
///// FUNCTIONS ///////////////
///////////////////////////////

constructor(AggregatorV3Interface priceFeed) Ownable(msg.sender){
s_priceFeed = priceFeed;
}


/**
 * 
 * @param bookname Name of book as specified in authorToBooks
 * @param authorname Name of the Author
 * Function that allows an address (Library) to make deposits for a particular book/author. 
 * lets maybe add an author parameter for security reasons? and then check that address is two-way correct (looks safer)
 */
  function depositComission(string memory bookname, string memory authorname) public returns(bool success){
    if(isLibrary[msg.sender] == false)
    {
      revert AddressIsntARegisteredLibrary();
    }
    if( addressToBalance[msg.sender] < getComissionInEth(libraryComissionInUsd[msg.sender]) ){
      revert BalanceIsLessThanSetComission();
    }
    
    address payable author = payable(bookToAuthorsAddress[bookname][authorname]);
    uint256 comission = libraryComissionInUsd[msg.sender];
    addressToBalance[msg.sender] -= comission;
    addressToBalance[author] += comission;

    return true;
}



  /** Adds ETH to the Library Account for it to make deposits.
  * Conditions:
  * 1. The address is a registered library
  * 2. The amount of ETH is above the minimum deposit in USD
  */
function addCapital() public payable returns(bool success){
  if(PriceConverter.getConversionRate(msg.value, s_priceFeed) < MINIMUM_USD){
    revert BelowMinValue();
  }
  if(isLibrary[msg.sender] == false){
    revert AddressIsntARegisteredLibrary();
  }

  addressToBalance[msg.sender] += msg.value;
  return true;
}


  /*
  * Allows both Authors and libraries to extract their balance from the contract.
  * Conditions: 
  * 1. The address is a registered library/author
  * 2. It has more balance than the minimum stablished for transactions
  */
function Withdraw() public returns(bool success){

  if(isLibrary[msg.sender] == true || isAuthor[msg.sender] == true){
    revert AddressCantWithdraw();
  } 
  if(isAboveMinValue(addressToBalance[msg.sender])){
    revert  HasntEnoughBalance();
  }

  //makes the transaction, and reverts if something doesn't go well
  (bool callSuccess, ) = payable(msg.sender).call{value: addressToBalance[msg.sender]}("");
    if(callSuccess == false){
      revert WithdrawalFailed();
    }
    
  addressToBalance[msg.sender] -= addressToBalance[msg.sender];
  return true;
}



//The aim in all of these onlyOwner modifiers is creating an engine that governs the contract,
//Where approvals, elections, votes, endorsements/etc do happen through it
//So that the program, addition of libraries, authors, and books can be done in a decentralized manner

function addLibrary(address newLibrary, string memory libraryName, uint256 comissionSet) 
external onlyOwner{
  isLibrary[newLibrary] = true;
  addressToName[newLibrary] = libraryName;
  libraryComissionInUsd[newLibrary] = comissionSet;
}


function addAuthor(string memory name, address payable author)
 external onlyOwner{
  isAuthor[author] = true;
  addressToName[author] = name;
}


function addBook(string memory bookName, string memory authorName, address payable author)
 external onlyOwner returns (uint256 id){
  id = s_books.length;
  s_books.push(Book(bookName, authorName, id, author));

  //dubious yet
  authorToBooks[author].push(id);

  return id;
}



function removeLibrary(address libraryToRemove) 
external onlyOwner {
  isLibrary[libraryToRemove] = false;
  addressToName[libraryToRemove] = "";
  libraryComissionInUsd[libraryToRemove] = 0;
}


function removeAuthor(address authorToRemove) 
external onlyOwner{
    //  mapping(string author => uint256[] books) public authorToBooks;
  isAuthor[authorToRemove] = false;
  addressToName[authorToRemove] = "";

  for(uint256 i; i < authorToBooks[authorToRemove].length; i++){
    removeBook(authorToBooks[authorToRemove][i]);
  }


}


/**
 * Removes a book from the system
 * @param id ID of the book
 */
function removeBook(uint256 id) 
 public onlyOwner{
    uint256 storageIndex = indexToStorageIndex[id];

  s_books[storageIndex] = s_books[s_books.length - 1];
  (,, uint256 movedBookId,) = getBookDataByStorageIndex(storageIndex);

  indexToStorageIndex[movedBookId] = storageIndex; 
  s_books.pop();
}


/**
 * 
 * @param index current storage index of the book in this contract
 * @return bookName Name of the book
 * @return authorName Name of its author
 * @return id Its uinque and permanent ID
 * @return author the address of that author
 */
function getBookDataByStorageIndex(uint256 index) internal view
returns(string memory bookName, string memory authorName, uint256 id, address author){
  return (s_books[index].s_bookTitle, 
  s_books[index].s_authorName, 
  s_books[index].s_id, 
  s_books[index].author);
}

function getBookDataById(uint256 id) public view 
returns(string memory bookTitle, string memory authorName, uint256 bookId){

  uint256 storageIndex = indexToStorageIndex[id];
  (bookTitle, authorName, id,)=getBookDataByStorageIndex(storageIndex);

  //Thought of returning the id according to the fetch, just in case
  return (bookTitle, authorName, id);
}


function getAllBookDataById(uint256 id) external view onlyOwner
returns(string memory bookTitle, string memory authorName, uint256 bookId, address author)
{

  uint256 storageIndex = indexToStorageIndex[id];
  (bookTitle, authorName, id,)=getBookDataByStorageIndex(storageIndex);

  //Thought of returning the id according to the fetch, just in case
  return (bookTitle, authorName, id, author);
}



/**
 * @notice Transfers ownership of the contract.
 * a small override of the OpenZeppelin implementantion to show the owner of the contract
 * on the s_owner state variable
 */
function _transferOwnership(address newOwner) internal override{
    s_owner = newOwner;
    Ownable.transferOwnership(newOwner);
}



/**
 * @notice Checks if the amount is above the minimum value set for transactions and returns a boolean
 * asserting whether or not it is.
 * The minimum value is relevant mainly for gas concerns, 
 * and hence network deployment is relevant in defining its value (constructor).
 * @param ethAmount ETH amount to evaluate in wei
 */
  function isAboveMinValue(uint256 ethAmount) private view returns(bool){
     uint256 usdValue = PriceConverter.getConversionRate(ethAmount, s_priceFeed);
      if(usdValue >= MINIMUM_USD){
        return true;
      }else{
        return false;
      }
  }


  fallback() external payable {
        addCapital();
  }

  receive() external payable {
        addCapital();
  }

/**
 * @notice Checks if the address is an author, and returns a boolean. The check sees that it has a name assigned.
 * @param caller The address to check
 * 
 */
function addressIsAuthor(address caller) external view returns(bool){
    if(keccak256(bytes(addressToName[caller])) != keccak256(bytes(""))){
      return true;
    }
  return false;
}

function addressIsLibrary(address caller) external view returns(bool){
if(keccak256(bytes(addressToName[caller])) != keccak256(bytes(""))){
      return true;
    }
  return false;
}

function getName(address caller) external view returns(string memory){
  return addressToName[caller];
}

function getComissionInEth(uint256 comissionInUsd) public view returns(uint256 comissionInEth){
  uint256 ethPrice = PriceConverter.getConversionRate(1, s_priceFeed);
  comissionInEth = comissionInUsd * ethPrice;
  return comissionInEth;
}


function getBalance(address user) external view returns(uint256){
  if(user != msg.sender && msg.sender != s_owner){
    revert AddressCantGetBalance();
  }

  return addressToBalance[user];
}


}
