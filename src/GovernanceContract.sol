//SPDX-License-Identifier: Apache-2.0

/**
 * @title: GovernanceContract
 * @author: Jeremias Pini
 * @license: MIT
 */
pragma solidity ^0.8.18;


/**
 * @title GovernanceContract
 * @author Jeremias Pini
 * @notice The goal of this contract is to administrate in a decentralized manner what 
 * can't be algorythmically performed in BookComissions.sol without compromising the safety/security of the 
 * protocol.
 * - Asserting that the registered Libraries are indeed libraries, 
 * - asserting that authors are the people they claim up to be, 
 * - managing books loading and unloading, and unregistering of any address, be it a library or an author.
 * 
 * The main way in which this aims to be achieved is through careful reviewing of the data provided by a 
 * group democratically chosen by the participants of the protocol.
 * We may call such a group Validators or also Reviewers. In the performance of their labor they might be awarded
 * an economical incentive. 
 * For the approval of each proposal (registering, unregistering), 
 * a percentage of favorable votes is deemed necessary in relation to the total number of reviewers.
 * If reviewers answer goes according to the final decision, their incentive is awarded. 
 * If an appeal to the decision is finally carried out to success, a penalty is awarded, and successive incentives
 * become smaller.

    WARNING, this contract is still an uncomplete draft, and is quite a mess. Take it with a grain (or two) of salt.
    */



/**
 * Layout and general plan:
 * 
 * 1. We need Reviewers/validators. A group of people/users who validate the input and output of
 *  important data for the protocol.
 * 2. A system to choose validators, and general users with permissions.
 * 3. A way to introduce new authors and libraries, members of the protocol.
 *      (validators validate them, probably)
 * 4. We need a system to propose and validate new books. (Validators probably, once again.)
 * 5. We need a way to unregister authors, libraries and books. A similar proccess.
 
 * 6. We need an algorithm for the work division and management which has to be random and decentralized.
 *          Probably Chainlink random functions.
 * 7. We need a way to know when validators fullfill their work properly.
 *          Maybe we don't, as a democratic representation of the right of a library to function properly,
 *          But could still proccure it, for the better functioning of the protocol.
 * 8. A way to reward active validators, who do fullfill their function
 * 9. A way to deal with unactive validators
 * 10. A way to stablish communication between validators and users.
 *  
 */



/**
 * A non-coding related issue:
 * Political, social, individual biased aspects, can steer the behaviour of privately in-own-interest choosen reviewers.
 * But as far as this governance system is concerned with the funds of the aforementioned libraries, then beyond the political interpretation and moral or social 
 * evaluation of the decisions taken, it seems that their representation is in fact if not totally, as long as this is a good-hearted donation system for such institutions, what is mostly needed.
 *  A bigger problem would result if the object was to have a normal usersToAuthors donation system. But in this case, a LibraryToAuthors transfer of funds is the implementation. 
 * The weaknesses of democracy remain present in the system, but its strengths overcome any other present option in lack of an algorythmic datafeed for an oracle solution to access this identity-person/related data.
 * As far as I see, no solution for these shortcomings is currently possible.
 */



import {AuthorComissions} from "../src/AuthorComissions.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PriceConverter} from "../src/PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GovernanceContract is ReentrancyGuard{

error AddressIsntALibrary();
error AddressIsntAnAuthor();
error ValueIsTooSmall();
error NameIsIncorrect();
error TitleCantBeEmpty();
error InsufficientEth();
error NameSizeIsIncorrect();
error AddressIsntAReviewer();
error BookDataIsIncorrect();
error AddressIsntAuthorOfBook();
error TitleIsIncorrect();
error AddressIsntAnAuthorOrLibrary();
error TooManyElements();
error CantVoteTwice();
error AddressIsAlreadyRegistered();




/**
 * @dev Many things currently being worked on. The structures aren't being properly used.
 * Book proposal can be more efficient and dependant on the structure and less on mappings.
 * Less mappings could exist.
 * Author proposals could be reviewed so they are also chiefly structure-based, rather than using
 * many many mappings.
 * some functions haven't been implemented.
 * and a few are half-way developed, with the remaining code being dimly suggested.
 */




/**
 * enum that differenciates between the two types of participant addresses (i.e, library and author). 
 * Used all accross the contract.
 */
   enum AddressType{
     Author, Library
    }


/**
 * struct that must be used to propose a book / addition to the protocol
 */
 struct BookProposal{
    string bookTitle;
    string authorName;
    uint256 id;
    address author;
    int256 voteScore;
    uint256 voters;
  }


/**
 * struct that must be used to propose a new address to the protocol
 */
  struct AddressProposal{
    AddressType addressType;
    address proposedAddress;
    int256 voteScore;
    uint256 voters;
    string name;
  }



/**
 * struct to store data sent by the checkUpkeep function to the performupkeep for removals.
 * Approvals for addition are performed with voting functions and outcome ratios. 
 * Only removals are handled with upkeeps.
 */
  struct UpkeepData{
    uint256 bookIdsLength; //amount of books to be removed.
    uint256[100] bookIds;   //bookIds, max 100, actual used values determined by bookIdsLength.
    uint256 addressesLength; //Amount of addresses to be deleted.
    RemoveAddressStack[100] addresses; //stack of addresses, actual used addresses determined in addressesLength
    }






/**
 * struct for the stack of books to be deleted in the next upkeep.
 * The timestamp is added to ensure that there's a 30 days enforced delay before the actual removal.
 */
  struct RemoveStack{
    uint256 id;
    uint256 timestamp;
  }



/**
 * struct used for the stack of addresses to be deleted inside the next upkeep.
 */
  struct RemoveAddressStack{
    address userAddress;
    uint256 timestamp;
    AddressType addressType;
  }




/**struct used by a mapping, to track the votes of reviewers*/
  struct Vote{
    bool hasVoted;
    bool approval;
  }
  //If we actually replace proposedbooks with this type, we can remove the mapping that stores
  //index to reviewingScores, and use the variable within this structure
  //Some tweaks to the s_proposedBooks accesses and calls might possibly be necessary.


//reviewers and proposed reviewers stack
address[] s_reviewers;
address[] s_proposedReviewers; //requires a certain rate of approval by other validators

//address[] s_proposedAuthors;
//address[] s_proposedLibraries;

//Stack of proposed books, and addresses to be added to the protocol.
AddressProposal[] s_proposedLibrariesAndAuthors;
BookProposal[] s_proposedBooks;

//Instantations of both removal-stacks for the upkeep functions
RemoveStack[] private removeStack;
RemoveAddressStack[] removeAddressStack;

//other contracts needed by this contract.
AuthorComissions comissContract;
AggregatorV3Interface s_priceFeed;



//Variables for book approval to the protocol
//mapping(uint256 bookIndex => mapping(address s_reviewers => bool approval)) addressAndBookToVote;
mapping(uint256 bookindex => address[] reviewers) bookIndexToReviewers;
mapping(uint256 bookindex => mapping(address reviewer => Vote)) bookIndexAndReviewerToVote;
//mapping(uint256 bookIndex => int256 voteScore) bookToVoteScore; //can be removed
mapping(uint256 id => uint256 storageIndex) idToStorageIndex; 
//Not sure if it is needed. I think it is needed since bookProposals are a stack, and if it isn't a stack but a map, 
//the storage will probably keep growing undefinedly.



// names, comissions and Libraries2Reviewers
mapping(address libraryAddress => address _reviewerAddress) libraryToReviewerAddress;
mapping(address => bool) addressIsReviewer; //could be address to address too, but for now I see no use for that


//temporal storage of data related to a still in votation address
mapping(address proposedAddress => string name) proposedAddressToName;
mapping(address proposedAddress => uint256 comission) proposedAddressToLibraryComission;


// Variables for address approval to the protocol
//Check these back after reading the contract>>>>>>>>!!!!!
mapping(address proposedAddress => mapping(address reviewer =>Vote)) addressAndReviewerToVote;
//mapping(address proposedAddress => int256 voteScore) addressToVoteScore;
mapping(address proposedAddress => uint256 index) proposedAddressToIndex;




uint256 constant MINIMUM_USD = 10;


////////////////////////////
////// FUNCTIONS ///////////
///////////////////////////

/**
 * constructor
 * @param comContract, authorComissions contract, the contract to be managed (and owned) by this one.
 */
constructor(address payable comContract){
comissContract = AuthorComissions(comContract);
s_priceFeed = comissContract.s_priceFeed();
s_reviewers.push(msg.sender); //contract is added as the first reviewer.
}

/**
 * @notice function through which authors can propose a book they wish to add to the protocol.
 * Authors need to be the ones to propose them, so that their address is linked to it.
 * If the book is approved by the reviewers, then it is added to the main protocol.
 * 
 * @param bookTitle title of the book to be proposed
 * @param authorName string name of the author of the book
 */
function AddBook(string memory bookTitle, string memory authorName) external payable nonReentrant{ 
    //A comission is asked, to both avoid spam and also feed the protocol    

    if((msg.value < 0.01 ether)) 
    {
        revert InsufficientEth();
    } 
    else if (msg.value > 0.01 ether)
    {
        //Return excess ether. Implement.
    } 

    if(!comissContract.addressIsAuthor(msg.sender)){
        revert AddressIsntAnAuthor();
    }
    if(keccak256(bytes(authorName)) != keccak256(bytes(comissContract.getName(msg.sender)))){
        revert NameIsIncorrect();
    }
    if(keccak256(bytes(bookTitle)) == ""){
        revert TitleCantBeEmpty();
    }

    //Add data, if things went ok through all these checks
    s_proposedBooks.push
    (
    BookProposal(bookTitle, authorName, s_proposedBooks.length, msg.sender, 0 /*voters*/, 0 /*starting voteScore*/)
    );



    idToStorageIndex[s_proposedBooks[s_proposedBooks.length-1].id] = s_proposedBooks.length-1; 
    //If the function is non-reentrant, this last line is all we need for index assignation    

}




////////////////////////////////////////////////////
/////My review got to this point.
////////////////////////////////////////////////////





/**
 * @notice through this function libraries can change and add reviewers that operate in name of their institution
 * @param newReviewer address to be added as a reviewer for the protocol
 * @param replaceValidator boolean value to know whether to revert or not if a reviewer is already set
 */
function AddReviewer(address newReviewer, bool replaceValidator) external payable returns(string memory email){
//At first seems not strictly necessary, but adding a voting system for reviewers might be valuable
/* not sure what the email address was meant to be for when I added it
Maybe finding a eth-based email protocol? */
//A system of communication might be needed. For clients to contact reviewers.
//And then: 1. a way to store those means of contact. 2. A way for users to access those means.
    if((msg.value < 0.01 ether))
    {
        revert InsufficientEth();
    }

    if(!comissContract.addressIsLibrary(msg.sender))
    {
        revert AddressIsntALibrary();
    }

    if(
        libraryToReviewerAddress[msg.sender] != address(0) &&
        replaceValidator == false
      ){
        revert AddressIsAlreadyRegistered();
    }
    s_proposedReviewers.push(newReviewer);

    //add email returner
}



function AddAuthor(string memory name) external payable{
    //author proposes himself
    //A contact to follow the procedure is shared
    //A comission is asked, to both avoid spam and also feed the protocol
    //A review is started

    if((msg.value < 0.01 ether)) //these values could probably be set in a variable, 
                                  //and updated to something that makes sense
    {
        revert InsufficientEth();
    }

    uint256 namelength = checkStringLength(name);
    if(namelength == 0 || namelength > 50){
        revert NameSizeIsIncorrect();
    }

    if(keccak256(bytes(comissContract.getName(msg.sender))) != keccak256(bytes(""))){
        revert AddressIsAlreadyRegistered();
    }

    

    //address to index = address => s_proposedLibrariesAndAuthors.length
    s_proposedLibrariesAndAuthors.push(AddressProposal(AddressType.Author, msg.sender, 0, 0, name));
    proposedAddressToIndex[msg.sender] = s_proposedLibrariesAndAuthors.length - 1;
    proposedAddressToName[msg.sender] = name; //This seems removable. Are names needed in the long term? Maybe for libraries, hardly for authors.
    // They also exist in the main contract. Has to be thought.

}


/**
 * @dev Library-user proposes to add himself into the protocol
 * @param name Name of the library
 * @param comissionSetInUsd Comission that the library finds confortable donating per author on a given period, expressed in USD
 * @param email the function returns an email address through which establishing contact will be possible, in order to follow the procedure
 * The function takes a small comission, in order to both avoid spam and feed the protocol.
 */
function AddLibrary(string memory name, uint256 comissionSetInUsd) external returns(string memory email){

    //Basic integrity checks
    uint256 namelength = checkStringLength(name);
    if(namelength == 0 || namelength > 50){
        revert NameSizeIsIncorrect();
    }

    if(comissionSetInUsd < 0 /*here a usd conversion is needed*/){
        revert ValueIsTooSmall();
    }

    s_proposedLibrariesAndAuthors.push(AddressProposal(AddressType.Library, msg.sender, 0, 0, name));
    proposedAddressToIndex[msg.sender] = s_proposedLibrariesAndAuthors.length - 1;
    proposedAddressToName[msg.sender] = name; //This seems removable. Are names needed in the long term? Maybe for libraries, hardly for authors.
    // They also exist in the main contract. Has to be thought.

    proposedAddressToLibraryComission[msg.sender] = comissionSetInUsd;

    //Function to get an email()

    return "";
}


/**
 * @dev protocol validators vote a book proposal. After a certain percentage of validation, Books are added to AuthorComissions.
 * @param bookName Name of the book being voted (requested for security purposes)
 * @param authorName Name of the author whose book is being voted (requested for security purposes, again)
 * @param localId The local ID of the book being voted. (If it enters the protocol, a new ID is assigned in the main contract)
 * @param approval Whether the book is approved or not
 */
function ValidateBook(string memory bookName, string memory authorName, uint256 localId, bool approval) 
external{

    //Security and integrity checks for the votes:
    uint256 index = idToStorageIndex[localId];
    if(addressIsReviewer[msg.sender] == false){
        revert AddressIsntAReviewer();
    }

    if(
      keccak256(bytes(s_proposedBooks[index].bookTitle)) != keccak256(bytes(bookName)) || 
      keccak256(bytes(s_proposedBooks[index].authorName)) != keccak256(bytes(authorName))
    ){
        revert BookDataIsIncorrect();
    }

    if(bookIndexAndReviewerToVote[index][msg.sender].hasVoted == true){
        revert CantVoteTwice();
    }


    //The vote is added:
    if(approval == false){
        s_proposedBooks[index].voteScore = s_proposedBooks[index].voteScore -1;
    }
    if(approval == true){
        s_proposedBooks[index].voteScore = s_proposedBooks[index].voteScore +1;
    }

    bookIndexAndReviewerToVote[index][msg.sender].approval = approval;
    bookIndexAndReviewerToVote[index][msg.sender].hasVoted = true;
    

   
    //Current votation progress is evaluated:
    //If the bookScore absolute value is greater than the pending reviews, the book evaluation is finished
    //This might possibly be changed before deployment, to something requiring even more than 50% positive votes, or gas-saving adjustments
    //In deployment, removing type conversions and the variable declarations below might be a source of gas saves
     uint256 amountOfReviews = bookIndexToReviewers[index].length;
    uint256 totalReviewers = s_reviewers.length;
    uint256 pendingReviews = totalReviewers - amountOfReviews;

        /*If the Absolute value of the score is greater than the pending reviews, 
        the votation is finished, and results evaluated*/
     if(
    s_proposedBooks[index].voteScore > int256(pendingReviews) || 
    s_proposedBooks[index].voteScore < -1*int256(pendingReviews)
    )
    {
        if(s_proposedBooks[index].voteScore > 0){
            comissContract.addBook
                (
                 s_proposedBooks[index].bookTitle, 
                 s_proposedBooks[index].authorName, 
                 payable(s_proposedBooks[index].author)
                );
          }
          
            //After adding (or not) the book, the solved proposal is deleted, and storage optimised
            delete s_proposedBooks[index];
            if(index != s_proposedBooks.length-1){
            s_proposedBooks[index] = s_proposedBooks[s_proposedBooks.length-1];
            idToStorageIndex[s_proposedBooks[index].id] = index;
            }
            //It seems that this function can be reentrant with Addbook. Probably needs something to avoid that.

/**
 * This clearly needs some time constrains. 
 * Possibly one that starts after the first or few first reviewers have voted.
 * AND has a time limit that is neither too long nor too short.
 * AND maybe some solutions depending on the state of the score at the limit time. 
 */

}

}

function ValidateAddress(address author, string memory authorName, bool approval) external{
  //Reviewers assert validation of an author through this function
  //After a certain percentage of validation, it is added to the list of authors

    if(addressIsReviewer[msg.sender] == false){
        revert AddressIsntAReviewer();
    }
  
    if(addressAndReviewerToVote[author][msg.sender].hasVoted == true){
        revert CantVoteTwice();
    }
  
  if( keccak256(bytes(authorName)) != keccak256(bytes(proposedAddressToName[author])) ){
    revert NameIsIncorrect();
  }


    uint256 index = proposedAddressToIndex[author];


       //The vote is added:
    if(approval == false){
        s_proposedLibrariesAndAuthors[index].voteScore = s_proposedLibrariesAndAuthors[index].voteScore - 1;

    }
    if(approval == true){
         s_proposedLibrariesAndAuthors[index].voteScore  = s_proposedLibrariesAndAuthors[index].voteScore + 1;
    }

    addressAndReviewerToVote[author][msg.sender].approval = approval;
    addressAndReviewerToVote[author][msg.sender].hasVoted = true;

    //Current votation progress is evaluated:
    //If more than 20% reviewers have voted, the protocol starts to see if a 20% approval is reached.
    //Once reached, it is approved, if that is ultimately not reached, it is rejected
    
    uint256 amountOfReviews = s_proposedLibrariesAndAuthors[index].voters;
    uint256 totalReviewers = s_reviewers.length;
    uint256 pendingReviews = totalReviewers - amountOfReviews;
    if( 
    s_proposedLibrariesAndAuthors[index].voteScore  > int256(pendingReviews) ||
    s_proposedLibrariesAndAuthors[index].voteScore  < -1*int256(pendingReviews)
    )
    {
        if(
            s_proposedLibrariesAndAuthors[index].voteScore > 0
          )
          {
            comissContract.addAuthor(
                s_proposedLibrariesAndAuthors[proposedAddressToIndex[author]].name,
                payable(author)
            );
          }

        delete s_proposedLibrariesAndAuthors[index];
        delete proposedAddressToIndex[author];

        /*If author is not the last item of the stack, the current last element is moved to its position*/
        if(index != s_proposedLibrariesAndAuthors.length - 1){
        s_proposedLibrariesAndAuthors[index] = s_proposedLibrariesAndAuthors[s_proposedLibrariesAndAuthors.length-1];
        proposedAddressToIndex[s_proposedLibrariesAndAuthors[index].proposedAddress] = index;
        s_proposedLibrariesAndAuthors.pop();
        }
        else{ //if the author is the last one in the list, last item is deleted
            s_proposedLibrariesAndAuthors.pop();
        }
    }

    //Time constrains are needed here    
}
/*///////////////////////////////////////////////////////////////////////
 * There was both an approvelibrary() function and approveauthor() here,
 *  but it was simply unified into the above function, approveAddresses
 *////////////////////////////////////////////////////////////////////


/**
 * @notice function to be used by an author to delete a book.
 * @param bookId unique id of the book to be deleted.
 * @param title string title of the book, as stored by the protocol.
 */
function RemoveBook(uint256 bookId, string memory title) external{

  if(comissContract.addressIsAuthor(msg.sender) == false){
    revert AddressIsntAnAuthor(); //maybe put isnt author of book and isnt an author together as AddressisntAuthor()
  }

  //msg.sender would be this contract, so this call works
  (string memory bookTitle,,, address author) = comissContract.getAllBookDataById(bookId);

 if(msg.sender != author){
    revert AddressIsntAuthorOfBook();
 }

 if(keccak256(bytes(title)) != keccak256(bytes(bookTitle))){
    revert TitleIsIncorrect();
 }

 removeStack.push(RemoveStack(bookId, block.timestamp));
 //checkupkeep will probably run every 15 days. 
 //If required elapsed time is similar, the book will be removed within a lapse of 15-29 days
}



/**
 * @notice in this function both libraries and authors can initiate an exit proccess from the protocol.
 */
function RemoveAddress() external{

    if(comissContract.addressIsAuthor(msg.sender)){
        removeAddressStack.push(RemoveAddressStack(msg.sender, block.timestamp, AddressType.Author));
    }

    else if(comissContract.addressIsLibrary(msg.sender)){
    removeAddressStack.push(RemoveAddressStack(msg.sender, block.timestamp, AddressType.Library));
    }

    else{
        revert AddressIsntAnAuthorOrLibrary();
    }

}


/**
 * @notice If trouble arises between validators, members, etc, 
 * democratically removing an address can somewhat make sense.
 * not implemented yet, but maybe needed.
 */
function addressRemovalByReviewers() internal{
/**
 * This should probably take a really strong consensus
 * function content goes here
 */
}



/**
 * @notice returns the length of a string passed as an argument
 * @param str string to get the length of in uint256
 */
function checkStringLength(string memory str) public pure returns (uint256){
    bytes memory strBytes = bytes(str);
    return strBytes.length - 1;
}


/**
 * @notice function necessary for the use of chainlink upkeep.
 * it checks whether there are removal (deletion) proposals for either addresses or books where the wait-time has
 * been fulfilled. 
 * And returns:
 * @param upkeepNeeded a boolean stating whether the condition is fullfilled, and points out which addresses those are.
 * @param performData a bytes object that holds the indexes of the addresses/books to be deleted.
 */
function checkUpkeep(
    /*bytes calldata checkData*/
) public view returns (bool upkeepNeeded, bytes memory performData)
{

    UpkeepData memory upkeepData;
        
    //these loops actually run off-chain
    for(uint256 i =0; i< removeStack.length; i++){

        if(block.timestamp - removeStack[i].timestamp > 30 days){ 
            //if the lapse has passed, data is added to our upkeepData struct
        RemoveStack memory removeStackItem = removeStack[i];
        upkeepData.bookIds[upkeepData.bookIdsLength] = removeStackItem.id;
        upkeepData.bookIdsLength++;
        }
    }

    for(uint256 i =0; i< removeAddressStack.length; i++){
        if(block.timestamp - removeAddressStack[i].timestamp > 30 days){
            
            upkeepData.addresses[upkeepData.addressesLength] = removeAddressStack[i];
            upkeepData.addressesLength++;

        }

    }

    if( upkeepData.bookIdsLength != 0 ||
        upkeepData.addressesLength != 0
    ){
        upkeepNeeded = true;
        performData = abi.encode(upkeepData);
    }

    return(upkeepNeeded, performData);
}




function performUpkeep(bytes calldata performData) public{
UpkeepData memory upkeepData = 
abi.decode(
    performData, 
    (UpkeepData)
    );

//minimal risk checks before running any loop
if(upkeepData.bookIdsLength > 100 || upkeepData.addressesLength > 100){ 
/*having more than a hundred book deletions approved in a short span would probably be beyond any
 estimated work-rate I could assume for the protocol*/
    revert TooManyElements();
}

for(uint256 i = 0; i <upkeepData.bookIdsLength; i++){
    //As the time is fullfilled, Books are removed from the main contract
    comissContract.removeBook(
        upkeepData.bookIds[i],
        false /*deletingAllbooks, only set to true inside AuthorComissions_removeAuthor*/ 
        );
}

for(uint256 i = 0; i <upkeepData.addressesLength; i++){
    //As time has been fullfilled, addresses are removed from the main contract
    //IF the address is an author, his books are removed from the protocol
    //IF it is a library, his funds are returned
    upkeepData.addresses[i];
    if(upkeepData.addresses[i].addressType == AddressType.Author){
        comissContract.removeAuthor(upkeepData.addresses[i].userAddress);
    }
    if(upkeepData.addresses[i].addressType == AddressType.Library){
        comissContract.removeLibrary(upkeepData.addresses[i].userAddress);
    }
}




}




}