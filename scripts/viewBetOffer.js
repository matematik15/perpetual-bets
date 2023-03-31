const ethers = require("ethers")
const BetOfferABI = require("../artifacts/contracts/BetOffer.sol/BetOffer.json").abi
// const ERC777ABI = require("../artifacts/@openzeppelin/contracts/token/ERC777/ERC777.sol/ERC777.json").abi
// const ERC20ABI = require("../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json").abi
const { Framework } = require("@superfluid-finance/sdk-core")

const BetOfferAddress = process.env.OFFER_ADDRESS
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

    //make the EOA BetOffer:
    // await daix.connect(deployer).getLatestPriceBTC().then(tx => {
    //     console.log(tx)
    // });

    const price = ethers.utils.formatEther(await betOffer.getLatestPrice())
    console.log("price: " + price)

    const owner = await betOffer.owner()
    console.log("owner: " + owner)

    const buyer = await betOffer.buyer()
    console.log("buyer: " + buyer)

    const freezePeriod = ethers.utils.formatEther(await betOffer.freezePeriod())
    console.log("freezePeriod: " + freezePeriod)

    const freezePeriodEnd = ethers.utils.formatEther(await betOffer.freezePeriodEnd())
    console.log("freezePeriodEnd: " + freezePeriodEnd)

    const strikePrice = ethers.utils.formatEther(await betOffer.strikePrice())
    console.log("strikePrice: " + strikePrice)

    const minPaymentFlowRate = ethers.utils.formatEther(await betOffer.minPaymentFlowRate())
    console.log("minPaymentFlowRate: " + minPaymentFlowRate)

    const isCall = await betOffer.isCall()
    console.log("isCall: " + isCall)

    const priceFeed = await betOffer.priceFeed()
    console.log("priceFeed: " + priceFeed)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
