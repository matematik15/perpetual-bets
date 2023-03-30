const ethers = require("ethers")
const BetOfferABI = require("../artifacts/contracts/BetOffer.sol/BetOffer.json").abi
// const ERC777ABI = require("../artifacts/@openzeppelin/contracts/token/ERC777/ERC777.sol/ERC777.json").abi
// const ERC20ABI = require("../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json").abi
const { Framework } = require("@superfluid-finance/sdk-core")

const BetOfferAddress = process.env.OFFER_ADDRESS
const DAIxAddress = "0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00"
const url = process.env.MUMBAI_URL

const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

async function main() {
    const network = await customHttpProvider.getNetwork()

    const betOffer = new ethers.Contract(
        BetOfferAddress,
        BetOfferABI,
        customHttpProvider
    )

    const sf = await Framework.create({
        chainId: network.chainId,
        provider: customHttpProvider
    })

    const deployer = sf.createSigner({
        privateKey: process.env.DEPLOYER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    const buyer = sf.createSigner({
        privateKey: process.env.BUYER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    await betOffer
        .connect(deployer)
        .cancelBet()
        .then(tx => {
            console.log(tx)
        })

}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
