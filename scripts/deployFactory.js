const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")

const url = process.env.GOERLI_URL

const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

async function main() {
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

    const BetFactory = await hre.ethers.getContractFactory("BetFactory")
    const betFactory = await BetFactory.connect(deployer).deploy()

    await betFactory.deployed()

    console.log("BetFactory.sol deployed to:", betFactory.address)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })