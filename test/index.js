const { ethers,deployments } = require("hardhat")
const { expect } = require("chai")

describe("Starting",async function () {
    // it("test",async function () {
    //     //创建工厂
    //     const factory = await ethers.getContractFactory("NftAuction")
    //     //部署合约
    //     const nftAuction = await factory.deploy()
    //     await nftAuction.waitForDeployment()

    //     await nftAuction.createAuction(
    //         100 * 1000,
    //         ethers.parseEther("0.001"),
    //         ethers.ZeroAddress,
    //         1
    //     )
    //     const auction = await nftAuction.auctions(0)
    //     console.log(auction)
    // })

    it("test",async function () {
        //部署业务合约
        await deployments.fixture("deployNftAuction")
        const nftAuctionProxy = await deployments.get("NftAuctionProxy")
        const nftAuction = await ethers.getContractAt("NftAuction",nftAuctionProxy.address)

        await nftAuction.createAuction(
            100 * 1000,
            ethers.parseEther("0.01"),
            ethers.ZeroAddress,
            1
        )
        const auction = await nftAuction.auctions(0)
        console.log("创建拍卖成功")

        //升级合约
        await deployments.fixture("upgradeNftAuction")
        // const nftAuctionProxyV2 = await deployments.get("NftAuctionProxyV2")
        const nftAuctionV2 = await ethers.getContractAt("NftAuctionV2",nftAuctionProxy.address) 
        const auction2 = await nftAuctionV2.auctions(0)
        const hello = await nftAuctionV2.testHello()
        expect(auction2.startTime).to.equals(auction.startTime)
        console.log(hello)
    })
})