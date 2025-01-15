//SPDX-License-Identifier: Apache-2.0

/**
 * @title: AuthorComissions
 * @author: Jeremias Pini
 * @license: MIT
 */



// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions




/**
 * Development notes:
 * 
 * program whose aim is to provide a platform for authors to get a comission on the transactions made
 * within a library, and the books that are lent to the readers.
 * 
 * >> It would be needed of the program to register libraries, authors, and books.
 * >> some ideas for that could be = manually, an authomatic proccess, with the assertion performed with another system, 
 *                                    a formal proccess performed by the project participant's, etc)
 * >> Registration of books will be tied to a particular author.
 * >> The only use of library funds will be those deposits/comissions.
 * >> The contract could charge a small sums to registering authors.
 * >> The contract needs to allow libraries to send payments for particular books. Receive those payments in the contract, 
 *    and delivering them to the authors.
 *
 *  Fundamental issue = the project doesn't greatly sound like it would especially benefit from blockchain.
 *  No doubt, any financial-related project can benefit from the security and ease of payment that blockchains provide. But as things stand now,
 *  the acceptance / development / usage and perhaps features that blockchain technology has, is not enough to justify its usage
 *  for any and all financial purposes. Many changes would be expected on the way to those circunstances, in which the landscape and tools at our disposal
 *  would also become different. 
 *  Even with all this, it is a nice experience and practice.
 * 
 * 
 * Problems: 
 * 
 * In-development issues:  
 * >> It might be wise to create a full suite for library management accompanied by this feature,
 * as the main innovation of the project.
 * >> Is there any way to on-board authors in a secure manner (blockchain's sort of secure)? 
 *      Seems hardly possible, unless we find a way to utopically confirm the identity of an account holder, and contrast it
 *      with the copyright holder of the book.  
 * A possible (easier) solution could be a democratic representation of the relevant investors of the protoccol (i.e. participating libraries in our case.)
 * 
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



/*/////////////////////////////////////////////////////////////////
                          ERRORS
/////////////////////////////////////////////////////////////////*/

  error HasntEnoughBalance();
  error AddressIsntARegisteredLibrary();
  error AddressIsntARegisteredAuthor();
  error AddressCantWithdraw();
  error BalanceIsLessThanSetComission();
  error BelowMinValue();
  error WithdrawalFailed();
  error AddressCantGetBalance();
  error AuthorComissions__AuthorNameIsIncorrect();
                      
/*/////////////////////////////////////////////////////////////////
                        VARIABLES
/////////////////////////////////////////////////////////////////*/

  address s_owner;
  uint256 booksCount;
  Book[] s_books;
  
  AggregatorV3Interface public s_priceFeed;
  uint256 public constant MINIMUM_USD = 10e18;
  enum ProtocolRole{ NON_PARTICIPANT, LIBRARY, AUTHOR }


  /*mapping that connects unique indexes of books (its single unique ID, never changing) to the actual
  array index (which changes every time an item is deleted)*/
  mapping(uint256 virtualIndex => uint256 realIndex) private indexToStorageIndex;

  //These Store the balance of an address, and the NAME of the address defined in the protocol 
  mapping(address => uint256) private addressToBalance;
  mapping(address => string) private addressToName; //A Enum or something akin can be added to the stored-value
  mapping(address => ProtocolRole) addressToRole;
  //Returns the comission value that the library sets for their own contributions
  mapping(address => uint256) private libraryComissionInUsd;

  //Gets exact names for books registered for that author, useful for transactions.
  mapping(address author => uint256[] books) private authorToBooks; //<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<CHECK
       //The default value of book ID is probably used, and authorToBooks probably has it checked for everyone. NEEDS TO BE reviewed. 
     //It could cause some problems, think of empty book IDs, and any author "having it", by default. <<--Check this overall in the contract


  /*Internally relevant for the contract, does fetch the address(es) to deposit to based on the
  bookname and authorname pair*/
  //THIS ALSO FEELS BAD. SEEMS LIKE WE USE TWO REPEATABLE VALUES. Probably would create conflicts 
  //FOR example, overwritting an author name, and bookname, with a new author. What would you do then?

  //Maybe, maybe replace bookname with bookId. It could work better.
  mapping(uint256 bookId => address authorsAddress) private bookToAuthorsAddress;



  struct Book{
    string s_bookTitle;
    string s_authorName;
    uint256 s_id;
    address author;
  }



/*//////////////////////////////////////////////////
                    FUNCTIONS 
//////////////////////////////////////////////////*/

  constructor(AggregatorV3Interface priceFeed) 
  Ownable(msg.sender){
    s_priceFeed = priceFeed;
    booksCount = 1; 
    //booksCount starts at 1 to avoid any risk related to default values

  }






/*///////////////////////////////////////////////////////////
                    External functions 
///////////////////////////////////////////////////////////*/

    fallback() external payable {
        addCapital(); //if the address isn't part of the protocol, the call reverts
  }

  receive() external payable {
        addCapital();
  }


/**
 * 
 * @param bookId Unique ID of the book in the protocol
 * @param authorname Name of the Author
 * Function that allows an address (Library) to make deposits for a particular book/author. 
 */
  function depositComission(uint256 bookId, string memory authorname) external returns(bool success){
    if(addressToRole[msg.sender] != ProtocolRole.LIBRARY)
    {
      revert AddressIsntARegisteredLibrary();
    }
    if( addressToBalance[msg.sender] < getComissionInEth(libraryComissionInUsd[msg.sender]) ){
      revert BalanceIsLessThanSetComission();
    }

    address payable author = payable(bookToAuthorsAddress[bookId]);

    if(keccak256(abi.encode(addressToName[author])) != keccak256(abi.encode(authorname))){
        revert AuthorComissions__AuthorNameIsIncorrect();
    }
    

    uint256 comission = libraryComissionInUsd[msg.sender];
    addressToBalance[msg.sender] -= comission;
    addressToBalance[author] += comission;

    return true;
}




/**
 * adds a library to the contract. 
 * If the owner is the governanceContract (it should), it  does performs many checks before calling.
 * 
 * @param newLibrary address of EOW of the library.
 * @param libraryName alphanumeric name of the library
 * @param comissionSet comission choosen by the library for lending instances
 */
function addLibrary(address newLibrary, string memory libraryName, uint256 comissionSet) 
external onlyOwner{
  addressToRole[newLibrary] = ProtocolRole.LIBRARY;
  addressToName[newLibrary] = libraryName;
  libraryComissionInUsd[newLibrary] = comissionSet;
}




/**
 * function used by the governanceContract to add an author to the contract.
 * @param name Name of the author
 * @param author Wallet address of the author
 */
function addAuthor(string memory name, address payable author)
external onlyOwner{
  addressToRole[author] = ProtocolRole.AUTHOR;
  addressToName[author] = name;
}



/**
 * Function used by the governanceContract to add a book. 
 * Books are proposed by authors in that contract, which upon their approval does call this function
 * @param bookName alphanumeric name of the book
 * @param authorName name of the author
 * @param author address of the author
 */
//This looks sorta prone to reentrancy issues.
function addBook(string memory bookName, string memory authorName, address payable author)
 external onlyOwner returns (uint256 id){
  id = booksCount;
  booksCount++;
  s_books.push(Book(bookName, authorName, id, author));
  //dubious yet
  authorToBooks[author].push(id);

  return id;
}


/**
 * function called by the manager to remove a library from the protocol.
 * @param libraryToRemove address of the library to be removed
 */
function removeLibrary(address libraryToRemove) 
external onlyOwner{
  addressToRole[libraryToRemove] = ProtocolRole.NON_PARTICIPANT;
  addressToName[libraryToRemove] = "";
  libraryComissionInUsd[libraryToRemove] = 0;
    if(addressToBalance[libraryToRemove] > 0){
      addressToBalance[libraryToRemove] = 0;
      Withdraw();
  }
}


/**
 * function called by the manager to remove an author from the protocol.
 * @param authorToRemove address of the author to be removed
 */
function removeAuthor(address authorToRemove) 
external onlyOwner{
  addressToRole[authorToRemove] = ProtocolRole.NON_PARTICIPANT;
  addressToName[authorToRemove] = "";
  if(addressToBalance[authorToRemove] > 0){
      addressToBalance[authorToRemove] = 0;
      Withdraw();
  }
  
  uint256 i=0;
  
  //A loop is needed here, length cant be predicted

  bool removingAuthor = true;
  for(i; i < authorToBooks[authorToRemove].length; i++){
    removeBook(authorToBooks[authorToRemove][i], removingAuthor);
    //CHECK WHETHER 0 IS A USED INDEX. it shouldn't.
    if(i == authorToBooks[authorToRemove].length-1){
      delete authorToBooks[authorToRemove];
    }

  }
}


/*///////////////////////////////////////////////////////////
                PUBLIC FUNCTIONS
///////////////////////////////////////////////////////////*/


 /** Adds ETH to the contract in name of the Library Account for deposits to get paid.
  * Conditions:
  * 1. The address is a registered library
  * 2. The amount of ETH is above the minimum deposit in USD
  */
function addCapital() public 
payable returns(bool success)
{
  if(PriceConverter.getConversionRate(msg.value, s_priceFeed) < MINIMUM_USD){
    revert BelowMinValue();
  }
  if(addressToRole[msg.sender] != ProtocolRole.LIBRARY){
    revert AddressIsntARegisteredLibrary();
  }

  addressToBalance[msg.sender] += msg.value;
  return true;
}




  /*
  * Allows both Authors and libraries to extract their balance from the contract.
  * Conditions: 
  * 1. The address is a registered library/author
  * 2. It has more balance than the minimum established for transactions 
  */
  function Withdraw() public returns(bool success)
  {

    if(
      keccak256(abi.encodePacked(addressToName[msg.sender])) == keccak256(abi.encodePacked(""))
    )//all members of the protocol should have a name
    { 
      revert AddressCantWithdraw();
    } 
    if(isAboveMinValue(addressToBalance[msg.sender])){
      revert  HasntEnoughBalance();
    }

    //executes the transaction, and reverts if something doesn't go well
    (bool callSuccess, ) = payable(msg.sender).call{value: addressToBalance[msg.sender]}("");
      if(callSuccess == false){
        revert WithdrawalFailed();
      }
      
    addressToBalance[msg.sender] -= addressToBalance[msg.sender];
    return true;
  }




/**
 * Function to be called by the manager (governanceContract) to remove a book from the protocol.
 * Book removals are proposed in the governanceContracts by authors, and upon approval, this code is executed.
 * @param id ID of the book
 * @param deletingAllBooks argument that asserts whether we are looping through all books from the author, and if so the elimination of that list
 * will be handled by the removeAuthor function.
 */
function removeBook(uint256 id, bool deletingAllBooks) //<< INCOMPLETE
public onlyOwner
{
  uint256 storageIndex = indexToStorageIndex[id];

  s_books[storageIndex] = s_books[s_books.length - 1];
  (,, uint256 movedBookId,) = getBookDataByStorageIndex(storageIndex);

  indexToStorageIndex[movedBookId] = storageIndex; 
  s_books.pop();


  /*If deletingAllBooks is true, we can't update metadata halfway through deletions.
  removeAuthor (caller) handles it.*/
  if(deletingAllBooks == false){
      address author = bookToAuthorsAddress[id];
      uint256 length = authorToBooks[author].length;
      
      for(uint256 i=0; i < length-1; i++){  //Find the book on the list
        if(authorToBooks[author][i] == id){ 
          authorToBooks[author][i] = authorToBooks[author][length-1]; //Replace it with the last
          authorToBooks[author].pop();  //delete the last spot
        }
      }
  }

}





/**
 * function that returns the data of a book by the unique never-changing ID number of a book.
 * (logical index)
 * This function is the one called to fetch any book's data.
 * @param id id value of the book to fetch
 * @return bookTitle Alphanumeric title of the book
 * @return authorName Alphanumeric title of the author
 * @return bookId Id of the book (same as calling param)
 */
function getBookDataById(uint256 id) public view 
returns(string memory bookTitle, string memory authorName, uint256 bookId)
{
//id argument and bookId returned value are the exact same parameter
  uint256 storageIndex = indexToStorageIndex[id];
  (bookTitle, authorName, bookId,) = getBookDataByStorageIndex(storageIndex);

   return (bookTitle, authorName, bookId);
}


/**
 * function that returns the commission value set by the library (USD) to ETH.
 * @param comissionInUsd value in USD to convert to eth.
 * @return comissionInEth value in eth.
 */
function getComissionInEth(uint256 comissionInUsd) public view returns(uint256 comissionInEth){
  uint256 ethPrice = PriceConverter.getConversionRate(1, s_priceFeed);
  comissionInEth = comissionInUsd * ethPrice;
  return comissionInEth;
}



/*/////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
/////////////////////////////////////////////////////////*/

/**
 * @notice Transfers ownership of the contract.
 * a small override of the OpenZeppelin implementantion to show the owner of the contract
 * on the s_owner state variable
 * @param newOwner address to which ownership is transferred
 */
function _transferOwnership(address newOwner) internal override{
    s_owner = newOwner;
    Ownable.transferOwnership(newOwner);
}



/**
 * function that returns the data of a book by its actual array index. 
 * Only to be called by the getBookDataById function
 * @param index current storage index of the book in the array
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



/*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
//////////////////////////////////////////////////////////////*/


/**
 * @notice Checks if the amount is above the minimum value set for transactions and returns a boolean
 * asserting whether or not it is.
 * The minimum value is relevant mainly for gas concerns, 
 * and hence network deployment is relevant in defining its value.
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



/*///////////////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
///////////////////////////////////////////////////////////*/


/**
 * function that returns the data of a book, including the author's wallet address. 
 * Used for checks with GovernanceContract.
 * @param id unique ID of the book
 * @return bookTitle Title of the book
 * @return authorName name of the author
 * @return bookId unique ID of the book (returned again)
 * @return author address of the book's author
 */
function getAllBookDataById(uint256 id) external view onlyOwner
returns(string memory bookTitle, string memory authorName, uint256 bookId, address author)
{

  uint256 storageIndex = indexToStorageIndex[id];
  (bookTitle, authorName, id,) = getBookDataByStorageIndex(storageIndex);

  return (bookTitle, authorName, id, author);
}



/**
 * @notice Checks if the address is an author recognized by the protocol.
 * @param caller The address to check
 */
function addressIsAuthor(address caller) external view returns(bool){
   //Checks whether there is a string-name assigned to the address
    if(addressToRole[caller] == ProtocolRole.AUTHOR)
    {
      return true;
    }
  return false;
}

/**
 * @notice function that returns a boolean asserting whether the argument address belongs to a library
 * @param caller address for which role wants to be confirmed
 * 
 */
function addressIsLibrary(address caller) external view returns(bool){
if(addressToRole[caller] == ProtocolRole.LIBRARY){
      return true;
    }
  return false;
}



/**
 * function that returns the alphanumeric name assigned to an address inside the protocol
 * @param caller address to get the name of. 
 * @notice This actually has a lot of trouble. Anyone can call it. Anyone can get any name.
 * The param says caller. It seems to have to do with the manager?
 * <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<CHECK THAT
 */
function getName(address caller) external view returns(string memory){
  return addressToName[caller];
}


/**
 * function to be used by the contract to see the balance of a participant of the protocol.
 * @param user address from which the contract balance wants to be read.
 * Any people can see data stored onchain. So it isn't actually private. 
 * But in order to make it slightly harder to get it is protected.
 */
function getBalance(address user) external view returns(uint256){
  if(user != msg.sender && msg.sender != s_owner){
    revert AddressCantGetBalance();
  }

  return addressToBalance[user];
}


}
