const { ethers,deployments } = require("hardhat")

describe("test auction",async function () {
    it("testauction",async function () {
    await deployments.fixture("deployNftAuction")
    const nftAuctionProxy = await deployments.get("NftAuctionProxy")
    console.log("部署合约。。。。")
    const [signer,buyer] = await ethers.getSigners()

    //部署721合约
    console.log("开始部署721")
    const TestERC721 = await ethers.getContractFactory("TestERC721")
    const testERC721 = await TestERC721.deploy()
    await testERC721.waitForDeployment()

    const testERC721Address = await testERC721.getAddress()
    console.log("testERC721Address:",testERC721Address)

    //mintERC721
    for (let index = 0; index < 10; index++) {
        await testERC721.mint(signer.address,index+1)
    }
    console.log("mint成功")
    const nftAuction = await ethers.getContractAt("NftAuction",nftAuctionProxy.address)
    await testERC721.connect(signer).setApprovalForAll(nftAuctionProxy.address,true)
    await nftAuction.createAuction(
        10,
        ethers.parseEther("0.01"),
        testERC721Address,
        1
    )
    const auction = await nftAuction.auctions(0)
    console.log("创建拍卖成功")

    //买方
    await nftAuction.connect(buyer).placeBid(0,{values: ethers.parseEther("0.01")})
    //结束拍
    await new Promise((resolve) => setTimeout(resolve,10 * 1000))
    console.log("等待10s完成")
    await nftAuction.connect(signer).endAuction(0)
    console.log("endAuction完成")
    //验证结果
    const auctionResult = await nftAuction.auctions(0);
    console.log(auctionResult)
    })
})