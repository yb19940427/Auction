// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NftAuction is Initializable {//is Initializable, UUPSUpgradeable
    struct Auction {
        //卖家
        address seller;
        //拍卖持续时间
        uint256 duration;
        //起始价格
        uint256 startPrice;
        //时间
        uint256 startTime;
        //是否结束
        bool ended;
        //最高出价者
        address highestBidder;
        //最高价格
        uint256 highestBid;
        //NFT ID
        uint256 tokenId; // 如果需要NFT ID，可以添加此字段  
        //NFT合约地址
        address nftContract; // 如果需要NFT地址，可以添加此字段
        //参与竞价的资产类型 0是ETH，其他ERC20
        address tokenAddress; // 如果需要代币地址，可以添加此字段

    }

    // AggregatorV3Interface dataFeed; // 如果需要价格预言机，可以添加此字段

    mapping (address => AggregatorV3Interface) public dataFeeds;

    function getChainlinkDataFeedLatestAnswer(address tokenAddress) public view returns (int) {
        // prettier-ignore
        AggregatorV3Interface dataFeed = dataFeeds[tokenAddress];
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }     
    function setProceETHFeed(address tokenAddress,address _priceFeed) public {
        // dataFeed = AggregatorV3Interface(_priceFeed);
        dataFeeds[tokenAddress] = AggregatorV3Interface(_priceFeed);
    }   

    //状态变量
    mapping (uint256 => Auction) public auctions;
    //下一个变量
    uint256 public nextAuctionId;
    //管理员地址
    address public admin;

    // constructor() {
    //     admin = msg.sender;
    // }
    //继承Initializable，不需要上面构造函数，改成这个
    function initialize() public initializer {
        admin = msg.sender;
    }

    //创建拍卖
    function createAuction(uint256 _duration,uint256 _startPrice,address _nftAddress,uint256 _nfpId)  public {
        //只有管理员可创建拍卖
        require(msg.sender == admin, "only admin can create auction");
        //检查参数
        require(_duration >= 10,"Duration must be greater than 0");
        //_duration
        require(_startPrice > 0,"start proce must be greater than 0");

        //转移nft到合约
        IERC721(_nftAddress).approve(address(this), _nfpId); // 授权合约可以操作NFT  

        auctions[nextAuctionId] = Auction ({
            seller: msg.sender,
            duration: _duration,
            startPrice: _startPrice,
            ended: false,
            highestBidder: address(0),
            highestBid: 0,
            startTime: block.timestamp,
            tokenId: _nfpId, // 如果需要NFT ID，可以添加此字段
            nftContract: _nftAddress,// 如果需要NFT地址，可以添加此字段
            tokenAddress: address(0) // 如果需要代币地址，可以添加此字段
        });
        nextAuctionId++;
    }

    //买家参与买单,ERC20也能参与，需要统一价格，预言机实现
    function placeBid(uint256 _auctionId,uint256 amount,address _tokenAddress) external payable {
        Auction storage auction = auctions[_auctionId];
        //判断当前拍卖是否结束,开始时间加上时间间隔小于当前时间，说明拍卖还没有结束
        require(!auction.ended && auction.startTime + auction.duration > block.timestamp,"auction ended");
        //判断出价是否大于当前最高出价
        uint payValue;
        if (_tokenAddress != address(0)) {
            payValue = amount * uint(getChainlinkDataFeedLatestAnswer(address(_tokenAddress)));
        }else{
            amount = msg.value;
            payValue = amount * uint(getChainlinkDataFeedLatestAnswer(address(0)));
        }
        
        uint erc20Value = amount * uint(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        uint startPriceValue = auction.startPrice * uint(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        uint highestBidValue = auction.highestBid * uint(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        if(erc20Value >= startPriceValue && erc20Value > highestBidValue){
            //转移ERC20到合约
            IERC20(_tokenAddress).transferFrom(msg.sender,address(this),amount);
            if(auction.tokenAddress == address(0)) {
                payable(auction.highestBidder).transfer(auction.highestBid);
            }else{
                //退回之前的ERC20
                IERC20(auction.tokenAddress).transfer(auction.highestBidder,auction.highestBid);

            }
        }
        auction.tokenAddress = _tokenAddress;
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;
            
        
        // require(msg.value >= auction.highestBid,"must high");
        // //之前出价高的人，给他退钱.如果最高出价者地址不为空，说明有最高出价者
        // if(auction.highestBidder != address(0)){
        //     payable(auction.highestBidder).transfer(auction.highestBid);
        // }
        //然后将这个auction修改最高出价者为当前用户
        // auction.highestBid = msg.value;
        // auction.highestBidder = msg.sender;
    }

    //出价
    // function bid(uint256 _auctionId) public payable {
    //     Auction storage auction = auctions[_auctionId];

    //     //检查拍卖是否存在
    //     require(_auctionId < nextAuctionId, "Auction does not exist");
    //     //检查拍卖是否结束
    //     require(!auction.ended && (auction.startTime + auction.duration) > block.timestamp, "Auction has ended");
    //     //检查出价是否大于最高出价          
    //     require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");
    //     //检查出价是否大于起始价格
    //     require(msg.value >= auction.startPrice, "Bid must be at least the starting price");
    //     //如果有最高出价者，退还其出价
    //     if (auction.highestBidder != address(0)) {
    //         payable(auction.highestBidder).transfer(auction.highestBid);
    //     }
    //     //更新拍卖信息
    //     auction.highestBidder = msg.sender;
    //     auction.highestBid = msg.value;
    // }

    //结束拍卖
    function endAuction(uint256 _auctionId) public {
        Auction storage auction = auctions[_auctionId]; 
        //检查拍卖是否存在
        require(_auctionId < nextAuctionId, "Auction does not exist");
        //检查拍卖是否结束
        require(!auction.ended, "Auction has already ended");
        //检查是否是卖家调用
        require(msg.sender == auction.seller, "Only seller can end the auction");
        //检查拍卖是否到期
        require((auction.startTime + auction.duration) <= block.timestamp, "Auction is still ongoing");
        //标记拍卖结束
        auction.ended = true;
        //如果有最高出价者，转账给卖家
        if (auction.highestBidder != address(0)) {
            //payable(admin).transfer(address(this).balance); // 将合约中的余额转给卖家
            //转移NFT给最高出价者
            IERC721(auction.nftContract).transferFrom(admin, auction.highestBidder, auction.tokenId);
        } else {
            //如果没有出价者，直接将NFT转回卖家
            IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        }
    }


    // function _authorizeUpgrade(address newImplementation) internal override view{
    //     //只有管理员可以升级合约
    //     require(msg.sender == admin, "only admin can upgrade contract");
    // }  
}