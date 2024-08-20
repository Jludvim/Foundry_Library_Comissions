//SPDX-License-Identifier: MIT


/**
 * Documentation for BookComissions.
 * 
 * program whose aim is to provide a platform for authors to get a comission on the transactions made
 * within a library, and the books that are lent to the readers.
 * The PLAN would be to create a mapping of addresses from book to the address of registered authors,
 * so that through a platform they can receive a small sum for every book of them that is lended.
 * Apparently, this could also imply that the transactions for the libraries would have to be made through the
 * blockchain, if this would carry any force soever. OR that the system through which the payments are delivered DOES 
 * perforce carry onchain data.
 * OR if the transactions are not made through the blockchain, then at least, be notified through the blockchain
 * in which case the payment of the transactions would remain absolutely contingent, and entirely upon the 
 * library owner, as an extra work and liability. Reducing this to a bare minimum would no doubt be 
 * one aim. 
 * There is Celo that aims to connect web2 to web3, considering it for the development of the
 * project would be a possibility, as other platforms and projects with a similar scope and aim.
 * Using the AggregatorV3Interface it could be possible to define in USDT the fix comission each library
 * might determine to add onto their current pricing, to know how much to transfer.
 * 
 * It is necessary to evaluate the possibility of running an entire library system, through a blockchain.
 * It would require probably defining a library contract for each of them. And for starters 
 * defining the general lineout for their development, and connect that to a main contract that hosts
 * the book to author address.
 * The book to author contract would most likely need someone in charge of the identification of the
 * individuals that present their address. Sounds like a well-defined bussiness, for which there are also many AI-powered
 * projects, and it is relevantly applied, for example, in exchanges and most financial accounts registration.
 * 
 * It would seem at first sight that this is an excellent protocol to create and define. But on the other hand,
 * None of this does imply that this will by any means be profitable for the creator, as hereby defined.
 * This is an important deterrent for the development of the infrastructure and work required by it.
 * Maybe a way to finance the project would be to ask for a small fee by the author for his registration. 
 * Asking for a comission on his work's comissions would on most views probably be inappropiate.
 * One problem that this might on turn generate, is that being that for the system to work, it does NEED
 * authors to be registered, so that the comissions can ever begin to flow, asking for payment before the
 * bussiness is defined can be an odd decision from the perspective of the registerer. And understandingly so.
 * One way around it, could be giving free registration during a settled period that might make the project
 * advance.
 * And contacting libraries to gauge interest, so as to allow them to register for this money-losing project. (Yay!)
 * And evaluate the support.
 * Gauge the market for the project, and its viability.
 *
 * 
 * 
 * Definition of the system requirements:
 * It would be needed of the program to register libraries, authors, and books.
 * Registration of libraries could be less strict, and manually done. An authomatic proccess
 * Would be even better.
 * Registration of authors could be done with the assertion performed with another system,
 * or setting a registration formal proccess performed by the project personnel.
 * Registration of books could be done either manually or finding a suiting system for automation or 
 * semi-automation, yet in any case well related to the REGISTRATION of AUTHORS. And TIED to it. 
 * Receiving funds that won't be delivered would be inappropiate.
 * To allow books to receive payments from the libraries. Receive those payments in the contract, 
 * deliver to the authors AND proccur to keep the addresses of the authors safe.
 * 
 * To allow books to send payments knowing the author of the book/book itself.
 * MAYBE, allow users to send donations to the authors they like. Might be less safe.
 * 
 * The system could even futurely be expanded to something similar, and yet slightly different:
 * Donations system:
 * Register a set of addresses for any particular project, receive the authorization from all those addresses
 * and allow the participants of the aforementioned project to receive donations in relation to their work in the project
 * and according to the split they could have previously defined or hereby define for the donations.
 * Yet, in this case identity assertions might be an actual headache.
 * 
 * 
 * Issues:
 * There is little benefit and incentive for the libraries!
 * That might probably be affordable as far as the system to develop is easy and complete enough
 * to be of benefit.
 * So? It might be wise to create a full suite for library management accompanied by this feature,
 * that could be the main innovation of the project, and it is no small one too.
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
 * 
 * 
 * Libraries: load cash, extract cash, send donation to author, register, unregister
 * Author: extract funds,   register, unregister,     load books, unload books
 * Administrator (decentralized): register, unregister      Load books / unload them?
 * A way to safely register/unregister, and load/unload data that is also decentralized is needed
 */


/**
 * @title: BookComissions
 * @author: Jeremias Pini
 * @license: MIT
 */
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../src/PriceConverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

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
  mapping(address => bool) private isLibrary;
  mapping(address => bool) private isAuthor;

  //These Store the balance of an address, and the NAME of the address defined in the protocol 
  //Both mappings work for libraries and authors
  mapping(address => uint256) private addressToBalance;
  mapping(address => string) private addressToName; //particularly useful for authors
  
  //Returns the comission value that the library sets for their own contributions
  mapping(address => uint256) private libraryComissionInUsd;

  //Gets exact names for books registered for that author, useful for transactions.
  //Seems actually little relevant, little useful //DELETE?
  //Not really. It is necessary to remove books written by an author from the contract.

  mapping(address author => uint256[] books) public authorToBooks;
  mapping(string book => string author) public bookToAuthor;


  /*Internally relevant for the contract, does fetch the address(es) to deposit to based on the bookname */
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
 * Function that allows any address to make deposits in name of a particular book.
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



//The aim in all of these onlyOwner function is creating an engine that governs the contract,
//Where approvals, elections, votes, endorsements/etc do happen
//So that the program, addition of libraries, authors, and books can be done in a decentralized manner
//The external version HAS to be declared onlyOwner.

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


//removes a book from the contract
//Id needed for removal, author asked purely for security
//Should move the author thing to the external version of this function
function removeBook(uint256 id) 
 public onlyOwner{
  uint256 storageIndex = indexToStorageIndex[id];

s_books[storageIndex] = s_books[s_books.length - 1];
(,, uint256 movedBookId,) = getBookDataByStorageIndex(storageIndex);

indexToStorageIndex[movedBookId] = storageIndex; 
s_books.pop();
}


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
 * a small override of the OpenZeppelin implementantion, so that the owner of the contract
 * can be displayed and freely seen on the s_owner state variable
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


function addressIsAuthor(address caller) external view returns(bool){
    if(isAuthor[caller]){
      return true;
    }
  return false;
}

function addressIsLibrary(address caller) external view returns(bool){
    if(isLibrary[caller]){
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
