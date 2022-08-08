//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {

  address payable owner;

  using Counters for Counters.Counter;
  Counters.Counter private _tokenId;
  Counters.Counter private _tokenSold;    // This can stored the token id's which are sold

  uint listPrice = 0.01 ether;    // This is the listing fee of this market place

  constructor() ERC721("NFTMarketplace", "NFTM") {
    owner = payable(msg.sender);
  }

  struct ListedToken {
    uint tokenId;
    address payable owner;
    address payable seller;
    uint price;
    bool currentlyListed;
  }

  mapping(uint => ListedToken) private idToListedToken;   // This mapping works when you retrive a item from collection. mapping(token_id => metadata)

  function updateListPrice(uint _listPrice) public payable {    // This function helps the owner to update the list price of the market place
    require(owner == msg.sender, "Only owner csn update the listing price");
    listPrice = _listPrice;
  }

  function getListPrice() public view returns(uint) {
    return listPrice;
  }

  function getLatestIdToListedToken() public view returns(ListedToken memory) {
    uint currentTokenId = _tokenId.current();
    return idToListedToken(currentTokenId);
  }

  function getListedForTokenId(uint tokenId) public view returns(ListedToken memory) {
    return idToListedToken[tokenId];    // It returns the token information for the perticular tokenId
  }

  function getCurrentToken() public view returns(uint) {
    return _tokenId.current();
  }

  function createToken(string memory tokenURI, uint price) payable public returns(uint) {
    require(msg.value == listPrice, "Send enough ether to list");
    require(price > 0, "Price should be greater then zero");

    uint currentTokenId = _tokenId.current();
    _safeMint(msg.sender, currentTokenId);

    _setTokenURI(currentTokenId, tokenURI);

    createListedToken(currentTokenId, price);

    return currentTokenId;
  }

  function createListedToken(uint tokenId, uint price) private {
    idToListedToken[tokenId] = ListedToken (
      tokenId,
      payable(address(this)),
      payable(msg.sender),
      price,
      true
    );

    _transfer(msg.sender, address(this), tokenId);
  }

  function getAllNFTs() public view returns(ListedToken[] memory) {
    uint nftCount = _tokenId.current();
    ListedToken[] memory tokens = new ListedToken[](nftCount);
    uint currentIndex = 0;

    //at the moment currentlyListed is true for all, if it becomes false in the future we will 
    //filter out currentlyListed == false over here
    for(uint i=0;i<nftCount;i++)
    {
      uint currentId = i + 1;
      ListedToken storage currentItem = idToListedToken[currentId];
      tokens[currentIndex] = currentItem;
      currentIndex += 1;
    }
    //the array 'tokens' has the list of all NFTs in the marketplace
    return tokens;
  }

  function getMyNFTs() public view returns (ListedToken[] memory) {
    uint totalItemCount = _tokenId.current();
    uint itemCount = 0;
    uint currentIndex = 0;
        
    //Important to get a count of all the NFTs that belong to the user before we can make an array for them
    for(uint i=0; i < totalItemCount; i++)
    {
      if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender){
        itemCount += 1;
      }
    }

    //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
    ListedToken[] memory items = new ListedToken[](itemCount);
    for(uint i=0; i < totalItemCount; i++) {
      if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender) {
        uint currentId = i+1;
        ListedToken storage currentItem = idToListedToken[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items; 
  }

  function executeSale(uint256 tokenId) public payable {
    uint price = idToListedToken[tokenId].price;
    address seller = idToListedToken[tokenId].seller;
    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

    //update the details of the token
    idToListedToken[tokenId].currentlyListed = true;
    idToListedToken[tokenId].seller = payable(msg.sender);
    _itemsSold.increment();

    //Actually transfer the token to the new owner
    _transfer(address(this), msg.sender, tokenId);
    //approve the marketplace to sell NFTs on your behalf
    approve(address(this), tokenId);

    //Transfer the listing fee to the marketplace creator
    payable(owner).transfer(listPrice);
    //Transfer the proceeds from the sale to the seller of the NFT
    payable(seller).transfer(msg.value);
  }

  //We might add a resell token function in the future
  //In that case, tokens won't be listed by default but users can send a request to actually list a token
  //Currently NFTs are listed by default

}