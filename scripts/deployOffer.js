const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
const BetFactoryABI = require("../artifacts/contracts/BetFactory.sol/BetFactory.json").abi
const BetOfferABI = require("../artifacts/contracts/BetOffer.sol/BetOffer.json").abi

const url = process.env.MUMBAI_URL

const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

async function main() {
    const BetFactoryAddress = process.env.BETFACTORY_ADDRESS
    const network = await customHttpProvider.getNetwork()

    const sf = await Framework.create({
        chainId: network.chainId,
        provider: customHttpProvider
    })

    const deployer = sf.createSigner({
        privateKey: process.env.DEPLOYER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    console.log("running deploy script...")

    const betFactory = new ethers.Contract(
        BetFactoryAddress,
        BetFactoryABI,
        customHttpProvider
    )

    const oneWeekInSeconds = 604800;
    const goerli_ETH_USD_oracle = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e"
    const mumbai_LINK_ETH_oracle = "0x12162c3E810393dEC01362aBf156D7ecf6159528"

    //Deployment using factory:
    // const createTx = await betFactory
    //     .connect(deployer)
    //     .createNewOffer(
    //         ethers.utils.parseEther("0.00000000001"),
    //         true,
    //         oneWeekInSeconds,
    //         ethers.utils.parseEther("0.000000170000"),
    //         sf.settings.config.hostAddress, //address of host
    //         goerli_ETH_USD_oracle
    //     )

    //Deployment of a single offer:
    const BetOffer = await hre.ethers.getContractFactory("BetOffer")
    const createTx = await BetOffer.connect(deployer).deploy(
        deployer.address,
        ethers.utils.parseEther("0.0000003"), //a little less than 1/mo
        true,
        60,
        ethers.utils.parseEther("0.000000170000"),
        sf.settings.config.hostAddress, //address of host
        mumbai_LINK_ETH_oracle
    )

    await createTx.deployed()

    console.log("BetOffer.sol deployed to:", createTx.address)

    // const bets = await betFactory.getOffers(deployer.address)

    // console.log("Bet offer deployed to:", bets[bets.length - 1])

    // const nextBet = await betFactory.idToOffer(1)
    // console.log(nextBet)
    // console.log(bets)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })