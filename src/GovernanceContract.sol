//SPDX-License-Identifier: Apache-2.0


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




// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// constant variables
// Type declarations
// Other state variables
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


import {AuthorComissions} from "../src/AuthorComissions.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PriceConverter} from "../src/PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract GovernanceContract is ReentrancyGuard, VRFConsumerBaseV2Plus{


/**
 * @dev Many things currently being worked on. The structures aren't being properly used.
 * Book proposal can be more efficient and dependant on the structure and less on mappings.
 * Less mappings could exist.
 * Author proposals could be reviewed so they are also chiefly structure-based, rather than using
 * many many mappings.
 * some functions haven't been implemented.
 * and a few are half-way developed, with the remaining code being dimly suggested.
 */

error AddressIsntALibrary();
error AddressIsntAuthor();
error ValueIsTooSmall();
error NameIsIncorrect();
error TitleCantBeEmpty();
error InsufficientEth();
error NameSizeIsIncorrect();
error AddressIsntAReviewer();
error BookDataIsIncorrect();
error TitleIsIncorrect();
error AddressIsntAnAuthorOrLibrary();
error TooManyElements();
error CantVoteTwice();
error AddressIsAlreadyRegistered();
error CallFailed();




uint256 constant OP_COMISSION_USD = 10;
uint32 constant REVIEWERS_PER_VALIDATION= 5;

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }

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
    uint256 votes;
    address[REVIEWERS_PER_VALIDATION] reviewers;
    uint256 totalPaidEth;
  }


/**
 * struct that must be used to propose a new address to the protocol
 */
  struct AddressProposal{
    AddressType addressType;
    address proposedAddress;
    int256 voteScore;
    address[REVIEWERS_PER_VALIDATION] reviewers;
    uint256 votes;
    string name;
    uint256 totalPaidEth;
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
 * structs for the stack of data to be deleted in the next upkeep.
 * The timestamp is added to ensure that there's a 30 days enforced delay before the actual removal.
 */
  struct RemoveBookStack{
    uint256 id;
    uint256 timestamp;
  }
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



//vrf
    
    bytes32 private immutable i_keyhash; /*gasLane*/
    uint32 private immutable i_callbackGasLimit;       
    uint16 private immutable i_requestConfirmations = 3; //The minimum value, change if you want
    uint256 private immutable i_subscriptionId;
    uint32 private constant NUM_WORDS = 3;
    mapping(uint256 => RequestStatus) public s_requests;
    uint256[3] unusedRequestIds; //we take the first, move one spot to the left the other two, and make a call
                                    //THE CALL that gets random numbers probably needs to update the third
    uint256 private s_setsOfRandomWordsToAdd;

//reviewers stack
address[] s_reviewers;

//Stack of proposed books, and addresses to be added to the protocol.
AddressProposal[] s_proposedLibrariesAndAuthors;
BookProposal[] s_proposedBooks;
//WHY aren't we using simply a stack of addresses, and then a mapping of address to data?

//Instantations of both removal-stacks types, used for data in the upkeep functions
RemoveBookStack[] private removeBookStack;
RemoveAddressStack[] removeAddressStack;

//other contracts needed by this contract.
AuthorComissions comissContract;
AggregatorV3Interface s_priceFeed;


    
    event RequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);


//can probably go around proposedAddressToname using the stack
mapping(address proposedAddress => string name) proposedAddressToName;
mapping(address proposedAddress => uint256 comission) proposedAddressToLibraryComission;
//This could be inside the struct
//But due to typecast problems and the nested struct, it becomes impossible to add elements, so this is neccessary
mapping(address proposedAddress => mapping(address reviewer => Vote)) addressAndReviewerToVote;
//proposed address to its index on the struct's stack.
mapping(address proposedAddress => uint256 index) proposedAddressToIndex;


mapping(address => string) reviewerEmail; //email of reviewer
mapping(address libraryAddress => address _reviewerAddress) libraryToReviewerAddress; //library to its representing reviewer

//Mappings for book approval to the protocol
/**these might need to be checked after we write the remaining functions*/
//Can be moved either to the bookProposal's struct, or to a reviewers struct, or to a different new struct
mapping(uint256 storedBookIndex => address[] reviewers) bookIndexToReviewers;
mapping(uint256 storedBookIndex => mapping(address reviewer => Vote)) bookIndexAndReviewerToVote;
mapping(uint256 id => uint256 stackIndex) idToStackBookIndex; //This is the actual storage index 


////////////////////////////
////// FUNCTIONS ///////////
///////////////////////////

/**
 * constructor
 * @param comContract, authorComissions contract, the contract to be managed (and owned) by this one.
 */
constructor(address payable comContract,
            uint32 callbackGasLimit,
            bytes32 keyhash,
            uint256 subscriptionId,
            address vrfCoordinator
) VRFConsumerBaseV2Plus(vrfCoordinator)
{
i_callbackGasLimit = callbackGasLimit;
i_keyhash = keyhash;
i_subscriptionId = subscriptionId;
comissContract = AuthorComissions(comContract);
s_priceFeed = comissContract.s_priceFeed();
s_reviewers.push(msg.sender); //contract is added as the first reviewer.
}






/*///////////////////////////////////////////////////////////
                EXTERNAL FUNCTIONS
//////////////////////////////////////////////////////////*/



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
    if(PriceConverter.getConversionRate(msg.value, s_priceFeed) < OP_COMISSION_USD) 
    {
        revert InsufficientEth();
    } else if (PriceConverter.getConversionRate(msg.value, s_priceFeed) > OP_COMISSION_USD)
        {
            //Return excess ether. Implement.
        } 
    if(!comissContract.addressIsAuthor(msg.sender)){
        revert AddressIsntAuthor();
    }
    if(keccak256(bytes(authorName)) != keccak256(bytes(comissContract.getName(msg.sender)))){
        revert NameIsIncorrect();
    }
    if(keccak256(bytes(bookTitle)) == ""){
        revert TitleCantBeEmpty();
    }


    address[REVIEWERS_PER_VALIDATION] memory reviewers = pickReviewers();
    //Add data, if things went ok through all these checks
    s_proposedBooks.push
    (
    BookProposal(bookTitle, authorName, s_proposedBooks.length, msg.sender,  0 /*starting voteScore*/, 0, reviewers, msg.value)
    );

    getSetOfRandomWords();

    //PICK REVIEWERS
    //SEND A MESSAGE TO THEM
    //return email list

    //If the function is non-reentrant, this last line is all we need for index assignation    
    idToStackBookIndex[s_proposedBooks[s_proposedBooks.length-1].id] = s_proposedBooks.length-1;
}







/**
 * @notice through this function libraries can change and add reviewers that operate in name of their institution
 * @param newReviewer address to be added as a reviewer for the protocol
 * @param replacingReviewer boolean value to know whether to revert or not if a reviewer is already set
 */
function AddReviewer(address newReviewer, bool replacingReviewer, string memory email) external payable
    /*returns(string memory email)*/
    {
    //If the user that wants something reviewed is contacted, then the possibility of getting scammed lies on him
    //If it is the other way around, and the reviewer is contacted by the user, at least users won't be the failure point
    //It could give a higher work-load to reviewers, navigating through messages, with their address being 'public'.

    /*Maybe finding a eth-based email protocol? */
    //A system of communication might be needed. For clients to contact reviewers.
    //And then: 1. a way to store those means of contact. 2. A way for users to access those means.

    if(!comissContract.addressIsLibrary(msg.sender))
    {
        revert AddressIsntALibrary();
    }

    if(
        libraryToReviewerAddress[msg.sender] != address(0) &&
        replacingReviewer == false
      ){
        revert AddressIsAlreadyRegistered();
    }

    s_reviewers.push(newReviewer);
    reviewerEmail[msg.sender] = email;
}


/**
 * @notice function used by an address to propose himself as a new author to be added to the protocol
 * @param name argument that specifies the name of 
 */
function AddAuthor(string memory name) external payable returns(string[REVIEWERS_PER_VALIDATION] memory emails){
    //author proposes himself
    //A contact to follow the procedure is shared
    //A comission is asked, to both avoid spam and also feed the protocol
    //A review is started
    

    //if eth isn't enough to pay comissions
    if((PriceConverter.getConversionRate(msg.value, s_priceFeed) < OP_COMISSION_USD)) 
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



    address[REVIEWERS_PER_VALIDATION] memory reviewers = pickReviewers();

    s_proposedLibrariesAndAuthors.push(
            AddressProposal(AddressType.Author,
            msg.sender,
            0,
            reviewers, //<-- Variable length. struct inside struct. We have to cast the struct
            0,
            name,
            msg.value)
        );
    proposedAddressToIndex[msg.sender] = s_proposedLibrariesAndAuthors.length - 1;
    proposedAddressToName[msg.sender] = name;

    getSetOfRandomWords();

    emails = getReviewersEmailsAsAString(reviewers);
    //We return the addresses to which the user has to send a single email to, in order to follow the procedure
    return (emails);

    //PICK REVIEWERS
    //GET EMAILS,
    //TIE EMAILS to the string
    //RETURN string
}




/**
 * @dev Library-user proposes to add himself into the protocol
 * @param name Name of the library
 * @param comissionSetInUsd Comission that the library finds confortable donating per author on a given period, expressed in USD
 * @param emailAddresses the function returns an email address through which establishing contact will be possible, in order to follow the procedure
 * The function takes a small comission, in order to both avoid spam and feed the protocol.
 * Might be possible to unify it with the addAuthor
 */
function AddLibrary(string memory name, uint256 comissionSetInUsd) external payable
 returns(string[REVIEWERS_PER_VALIDATION] memory emailAddresses){

    if(PriceConverter.getConversionRate(msg.value, s_priceFeed) < OP_COMISSION_USD){
        revert InsufficientEth();
    }

    //Basic integrity checks
    uint256 namelength = checkStringLength(name);
    if(namelength == 0 || namelength > 50){
        revert NameSizeIsIncorrect();
    }

    if(comissionSetInUsd <= 0){
        revert ValueIsTooSmall();
    }

    
    address[REVIEWERS_PER_VALIDATION] memory reviewers = pickReviewers();

    s_proposedLibrariesAndAuthors.push(
        AddressProposal(AddressType.Library, msg.sender, 0, reviewers, 0, name, msg.value)
        );
    proposedAddressToIndex[msg.sender] = s_proposedLibrariesAndAuthors.length - 1;
    proposedAddressToName[msg.sender] = name;

    proposedAddressToLibraryComission[msg.sender] = comissionSetInUsd;

        emailAddresses = getReviewersEmailsAsAString(reviewers);
    //We return the addresses to which the user has to send a single email to, in order to follow the procedure
    return (emailAddresses);


    //PICK REVIEWERS
    //GET EMAILS,
    //TIE EMAILS to the string
    //RETURN string

}




/**
 * @dev protocol validators vote a book proposal. After a certain percentage of validation, Books are added to AuthorComissions.
 * @param bookName Name of the book being voted (requested for security purposes)
 * @param authorName Name of the author whose book is being voted (requested for security purposes, again)
 * @param localId The local ID of the book being voted. (If it enters the protocol, a new ID is assigned in the main contract)
 * @param approval Whether the book is approved or not
 */
function ValidateBook(string memory bookName, string memory authorName, uint256 localId, bool approval) 
external nonReentrant
{
    /*Here we have an issue. This will call addBook. If addbook is non-reentrant, and the conditions for adding a book
    are met, and another book is currently being added, then execution will fail. (Vote wont be added)
    But the vote wont be added, and then
    If we make a call that will execute addbook, and the previous call of this function finished, 
    but the execution of addbook did not, we could get reentrant there
    */

    //Security and integrity checks for the votes:
    uint256 index = idToStackBookIndex[localId];
    if(keccak256(bytes(reviewerEmail[msg.sender])) == keccak256(bytes(""))){
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

    bookIndexAndReviewerToVote[index][msg.sender].hasVoted = true;
    bookIndexAndReviewerToVote[index][msg.sender].approval = approval;

   
    //Current votation progress is evaluated:
    //If the bookScore absolute value is greater than the pending reviews, the book evaluation is finished
    //This might possibly be changed before deployment, to something requiring even more than 50% positive votes, or gas-saving adjustments
    //In deployment, removing type conversions and the variable declarations below might be a source of gas saves
     uint256 amountOfReviews = s_proposedBooks[index].votes;
    uint256 totalReviewers = s_reviewers.length;
    uint256 pendingReviews = totalReviewers - amountOfReviews;

        /*If the Absolute value of the score is greater than the pending reviews, 
        the votation is finished, and results evaluated*/
     if(
    s_proposedBooks[index].voteScore > int256(pendingReviews) || 
    s_proposedBooks[index].voteScore < -1*int256(pendingReviews)
    )
    {

        address[] memory awardedReviewers;
        uint256 totalValue = s_proposedBooks[index].totalPaidEth;
        uint256 counter; //push method is only available for storage, and not memory arrays
        bool approvalResult;
        if(s_proposedBooks[index].voteScore > 0){
                approvalResult = true;

            comissContract.addBook
                (
                 s_proposedBooks[index].bookTitle, 
                 s_proposedBooks[index].authorName, 
                 payable(s_proposedBooks[index].author)
                );
         
          }
          else{
                approvalResult = false;
            }

                //those whose answer was the same as the result, are rewarded
                for(uint256 i=0;i< REVIEWERS_PER_VALIDATION;i++){
                    address reviewer = s_proposedLibrariesAndAuthors[index].reviewers[i];
                    if(bookIndexAndReviewerToVote[index][reviewer].approval == approvalResult){
                        awardedReviewers[counter] = reviewer;
                    }
                }
                for(uint256 i=0; i<awardedReviewers.length; i++){
                    (bool callSuccess, ) = payable(awardedReviewers[i]).call{value: totalValue/awardedReviewers.length}("");
                    if(callSuccess == false){
                        revert CallFailed();
                    }
                }

            //After adding (or not) the book, the solved proposal is deleted, and storage optimised
            delete s_proposedBooks[index];
            if(index != s_proposedBooks.length-1){
            s_proposedBooks[index] = s_proposedBooks[s_proposedBooks.length-1];
            idToStackBookIndex[s_proposedBooks[index].id] = index;
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



/**
 * @notice function used for reviewers to validate an address proposed to the protocol.
 * Once a certain percentage of votes is reached (such that the result cannot possibly be changed,
 * regardless of future votes), the query is solved <--- this needs to be fixed. Not everyone is rewarded, so
 * not everyone will vote. Timeframes have to be added.
 * @param libraryOrAuthor address to be approved (name prone to change to something more address-type agnostic)
 * @param name name of the address proposed for the protocol
 * @param approval the vote emited by the reviewer calling the function
 */
function ValidateAddress(address libraryOrAuthor, string memory name, bool approval) external{
  //Reviewers assert validation of an author through this function
  //After a certain percentage of validation, it is added to the list of authors

    if(keccak256(bytes(reviewerEmail[msg.sender])) == keccak256(bytes(""))){
        revert AddressIsntAReviewer();
    }
  
    if(addressAndReviewerToVote[libraryOrAuthor][msg.sender].hasVoted == true){
        revert CantVoteTwice();
    }
  
  if( keccak256(bytes(name)) != keccak256(bytes(proposedAddressToName[libraryOrAuthor])) ){
    revert NameIsIncorrect();
  }


    uint256 index = proposedAddressToIndex[libraryOrAuthor];


       //The vote is added:
    if(approval == false){
        s_proposedLibrariesAndAuthors[index].voteScore = s_proposedLibrariesAndAuthors[index].voteScore - 1;

    }
    if(approval == true){
         s_proposedLibrariesAndAuthors[index].voteScore  = s_proposedLibrariesAndAuthors[index].voteScore + 1;
    }
    s_proposedLibrariesAndAuthors[index].votes++;


    addressAndReviewerToVote[libraryOrAuthor][msg.sender].approval = approval;
    addressAndReviewerToVote[libraryOrAuthor][msg.sender].hasVoted = true;
    
    //Current votation progress is evaluated:
    uint256 amountOfReviews = s_proposedLibrariesAndAuthors[index].votes;
    uint256 totalReviewers = s_reviewers.length;
    uint256 pendingReviews = totalReviewers - amountOfReviews;
   
    //Whenever an irreversible (either positive or negative) result is attained, the votation proccess finishes
    if( 
    s_proposedLibrariesAndAuthors[index].voteScore  > int256(pendingReviews) ||
    s_proposedLibrariesAndAuthors[index].voteScore  < -1*int256(pendingReviews)
    )
    {

        address[] memory awardedReviewers;
        uint256 totalValue = s_proposedLibrariesAndAuthors[index].totalPaidEth;
        uint256 counter; //push method is only available for storage, and not memory arrays
        address proposedAddress = s_proposedLibrariesAndAuthors[index].proposedAddress;
        bool approvalResult;
        if(
            s_proposedLibrariesAndAuthors[index].voteScore > 0 //If the end result is positive
          )
          {
            approvalResult = true;

                comissContract.addAuthor(
                    s_proposedLibrariesAndAuthors[proposedAddressToIndex[libraryOrAuthor]].name,
                    payable(libraryOrAuthor)
                );
            
          }else{
                approvalResult = false;  //If the end result is negative
          }

                //The protocol gives rewards according to reviewers votes and the result, where they are equal
                for(uint256 i=0;i< REVIEWERS_PER_VALIDATION;i++){
                    address reviewer = s_proposedLibrariesAndAuthors[index].reviewers[i];
                    if(addressAndReviewerToVote[proposedAddress][reviewer].approval == approvalResult){
                        awardedReviewers[counter] = reviewer;
                    }
                }
                //We divide the total comissions of the proccess between the reviewers who voted like the majority did
                for(uint256 i=0; i<awardedReviewers.length; i++){
                    (bool callSuccess, ) = payable(awardedReviewers[i]).call{value: totalValue/awardedReviewers.length}("");
                    if(callSuccess == false){
                        revert CallFailed();
                    }
                }



        delete s_proposedLibrariesAndAuthors[index];
        delete proposedAddressToIndex[libraryOrAuthor];

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



/**
 * @notice function to be used by an author to delete a book.
 * @param bookId unique id of the book to be deleted.
 * @param title string title of the book, as stored by the protocol.
 */
function RemoveBook(uint256 bookId, string memory title) external{

  if(comissContract.addressIsAuthor(msg.sender) == false){
    revert AddressIsntAuthor(); //maybe put isnt author of book and isnt an author together as AddressisntAuthor()
  }

  //msg.sender would be this contract, so this call works
  (string memory bookTitle,,, address author) = comissContract.getAllBookDataById(bookId);

 if(msg.sender != author){
    revert AddressIsntAuthor();
 }

 if(keccak256(bytes(title)) != keccak256(bytes(bookTitle))){
    revert TitleIsIncorrect();
 }

 removeBookStack.push(RemoveBookStack(bookId, block.timestamp));
 //checkupkeep will probably run every 15 days. 
 //If required elapsed time is similar, the book will be removed within a lapse of 15-29 days
}



/**
 * @notice in this function both libraries and authors can initiate an exit proccess from the protocol.
 */
function RemoveAddress(bool remove) external nonReentrant{
    
         if(!comissContract.addressIsAuthor(msg.sender)){
        if(!comissContract.addressIsLibrary(msg.sender)){
            revert AddressIsntAnAuthorOrLibrary();
        }
        }


    if(remove==true){
        //here there is no protection against putting more than one request
        //That looks like something important to address
        removeAddressStack.push(RemoveAddressStack(msg.sender, block.timestamp, AddressType.Library));
    }else{
        for(uint256 i=0; i<removeAddressStack.length ; i++){
            if(removeAddressStack[i].userAddress == msg.sender){
                removeAddressStack[i] = removeAddressStack[removeAddressStack.length-1];
                removeAddressStack.pop();

            }
        }
    }
}

/*/////////////////////////////////////////////////////////
                PUBLIC FUNCTIONS
/////////////////////////////////////////////////////////*/

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
 * it checks whether there are removal (deletion) proposals for either addresses or books where the wait-time
 * (15 days) has been fulfilled. 
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
    for(uint256 i =0; i< removeBookStack.length; i++){

        if(block.timestamp - removeBookStack[i].timestamp > 15 days){ 
            //if the lapse has passed, data is added to our upkeepData struct
        RemoveBookStack memory removeStackItem = removeBookStack[i];
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




function performUpkeep(bytes calldata performData) 
public{
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





/*////////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
////////////////////////////////////////////////////////////*/



/**
 * @notice function called by Chainlink to return provable random values
 * @param _requestId Id of our request
 * @param _randomWords set of random values requested
 */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override 
    {
        
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );

     

    }



/**
 * @notice function that requests a new batch of random words to the vrf
 */
    function getSetOfRandomWords() internal{
        uint256 requestId;
                      // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyhash,
                subId: i_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: REVIEWERS_PER_VALIDATION,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }


/**
 * @notice function that returns a batch of random numbers (randomWords). Random words
 *  are used in the protocol to randomly assign reviewers to a particular addition/removal-proposal
 * THIS probably needs a loop on the unusedRequestIds.
 */
function fetchSetOfRandomWords() internal nonReentrant 
returns(uint256[] memory){

    //gets randomWords
    uint256 requestId = unusedRequestIds[0];
    uint256[] memory randomWords = s_requests[requestId].randomWords;

    //updates unusedRequestIds' stack
    unusedRequestIds[0] = unusedRequestIds[1];
    unusedRequestIds[1] = unusedRequestIds[2];
    s_setsOfRandomWordsToAdd += 1; //asks for a new randomWord

    return randomWords;
}


/**
 * @notice function that picks (a set of) reviewers to work on a particular approval proccess
 * @return reviewersAddresses returned stack of addresses with the reviewers that were randomly picked
 */
function pickReviewers() internal
returns(address[REVIEWERS_PER_VALIDATION] memory reviewersAddresses){

    //If this function calls a non-reentrant function (like, fetchSetOfRandomWords), it might work just well.
    uint256[] memory randomWords = fetchSetOfRandomWords();

    uint256 poolOfReviewers = s_reviewers.length;
    uint256[REVIEWERS_PER_VALIDATION] memory indexReviewers;   
    /*converts randomWords in a value within 0 and poolOfReviewers
    Assigns the reviewers using those values*/
    for(uint256 i=0; i < REVIEWERS_PER_VALIDATION; i++){
        randomWords[i] = randomWords[i] % poolOfReviewers;
        indexReviewers[i] = randomWords[i];
        reviewersAddresses[i] = s_reviewers[indexReviewers[i]];
    }

    return (reviewersAddresses);
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
 * @notice a internal function that returns the emails of the choosen reviewers as a string array
 * @param reviewerAddress array of addresses to fetch the email's of
 * @return emails email addresses to be returned
 */
function getReviewersEmailsAsAString(address[REVIEWERS_PER_VALIDATION] memory reviewerAddress) internal view
returns(string[REVIEWERS_PER_VALIDATION] memory emails){
        for(uint256 i=0;i<REVIEWERS_PER_VALIDATION;i++){
            emails[i] = reviewerEmail[reviewerAddress[i]];
        }
    return emails;
}








}