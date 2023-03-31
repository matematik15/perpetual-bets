// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract BetOffer is SuperAppBase {
    using CFAv1Library for CFAv1Library.InitData;

    address public owner;
    address public buyer;
    uint256 public freezePeriod;
    uint256 public freezePeriodEnd;
    int256 public strikePrice;
    AggregatorV3Interface public priceFeed;
    int96 public minPaymentFlowRate;
    bool public isCall;
    ISuperfluid public immutable host;
    ISuperToken public immutable betToken = ISuperToken(0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00);
    //Goerli fDAIx: 0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00
    //Mumbai fDAIx: 0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f
   
    //CFA's setup
    CFAv1Library.InitData public cfaV1;
    bytes32 public constant CFA_ID =
        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    // ---------------------------------------------------------------------------------------------
    //MODIFIERS

    /// @dev checks that only the CFA is being used
    ///@param agreementClass the address of the agreement which triggers callback
    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    ///@dev checks that only the betToken is used when sending streams into this contract
    ///@param superToken the token being streamed into the contract
    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(betToken);
    }

    ///@dev ensures that only the host can call functions where this is implemented
    //for usage in callbacks only
    modifier onlyHost() {
        require(msg.sender == address(cfaV1.host), "Only host can call callback");
        _;
    }

    ///@dev used to implement _isSameToken and _isCFAv1 modifiers
    ///@param superToken used when sending streams into contract to trigger callbacks
    ///@param agreementClass the address of the agreement which triggers callback
    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can execute");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute");
        _;
    }

    modifier onlyAfterFreezePeriod() {
        require(block.timestamp > freezePeriodEnd);
        _;
    }

    constructor(address _owner,
                int96 _minPaymentFlowRate,
                bool _isCall,
                uint256 _freezePeriod,
                int256 _strikePrice,
                ISuperfluid _host, // address of SF host
                address _chainLinkOracle) {
        owner = _owner;
        minPaymentFlowRate = _minPaymentFlowRate;
        isCall = _isCall;
        freezePeriod = _freezePeriod;
        strikePrice = _strikePrice;
        host = _host;
        priceFeed = AggregatorV3Interface(_chainLinkOracle);

        // CFA lib initialization
        IConstantFlowAgreementV1 cfa = IConstantFlowAgreementV1(
            address(_host.getAgreementClass(CFA_ID))
        );

        cfaV1 = CFAv1Library.InitData(_host, cfa);

        // super app registration
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }

    function getLatestPrice() public view returns (int256) {
        (
            /* uint80 roundID */,
            int256 price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }

    function executeBet() external onlyBuyer {
        address _to = buyer; //define an intermediary variable for the Checks-Effects-Interactions pattern
        //"call" bet:
        if (isCall) {
            require(getLatestPrice() >= strikePrice, "Current price lower than strike price");
            _resetBuyerAndFreeze;
            betToken.transfer(_to, betToken.balanceOf(address(this)));
            _deleteFlows();
        } else {
        //"put" bet:
            require(getLatestPrice() <= strikePrice, "Current price higher than strike price");
            _resetBuyerAndFreeze;
            betToken.transfer(_to, betToken.balanceOf(address(this)));
            _deleteFlows();
        }
    }

    function cancelBet() external onlyOwner onlyAfterFreezePeriod {
        _deleteFlows();
        _resetBuyerAndFreeze();
        betToken.transfer(owner, betToken.balanceOf(address(this)));
    }

    function _deleteFlows() internal {
        cfaV1.deleteFlow(buyer, address(this), betToken);
        cfaV1.deleteFlow(address(this), owner, betToken);
    }

    function _resetBuyerAndFreeze() internal {
        buyer = address(0);
        freezePeriodEnd = 0;
    }

    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS

    /// @dev Equivalent of buying the bet option. This covers both the initial buy and an outbid buy
    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        newCtx = ctx;
        (, int96 inFlow, , ) = cfaV1.cfa.getFlow(betToken, host.decodeCtx(ctx).msgSender, address(this));

        //A buyer exists and the freeze period hasn't passed:
        if (buyer != address(0) && block.timestamp <= freezePeriodEnd) {
            revert("Bet already sold, freeze period not over");
        } else {

        //There is no buyer, offer being bought for the first time:
            if(buyer == address(0)) {
                if (inFlow < minPaymentFlowRate) {
                    revert("Payment too small");
                } else {
                    buyer = host.decodeCtx(ctx).msgSender;
                    freezePeriodEnd = block.timestamp + freezePeriod;
                    newCtx = cfaV1.createFlowWithCtx(newCtx, owner, betToken, inFlow);
                }
            }
        }

        //A buyer exists and the freeze period passed. He can be outbid by anyone now:
        if (buyer != address(0) && block.timestamp > freezePeriodEnd) {
            if (inFlow < minPaymentFlowRate) { //increase the minPaymentFlowRate by at least 25% on each new outbid
                revert("Payment too small");
            } else {
                newCtx = cfaV1.updateFlowWithCtx(newCtx, owner, betToken, inFlow); //the bet must have some supertokens for this to work
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, buyer, address(this), betToken);
                freezePeriodEnd = block.timestamp + freezePeriod;
                buyer = host.decodeCtx(ctx).msgSender;
            }
        }

        //Make the next outbid be at least 25% higher:
        minPaymentFlowRate = inFlow * 5/4;
        return newCtx;
    }

    /// @dev super app after agreement updated callback
    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        newCtx = ctx;
        //buyer lowers the flowrate below the minimal:
        if(host.decodeCtx(ctx).msgSender == buyer){
            (, int96 inFlow, , ) = cfaV1.cfa.getFlow(betToken, host.decodeCtx(ctx).msgSender, address(this));
            if (inFlow < minPaymentFlowRate) {
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), owner, betToken);
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, host.decodeCtx(ctx).msgSender, address(this), betToken);
                _resetBuyerAndFreeze();
            } else {
                //Make the next outbid be at least 25% higher:
                minPaymentFlowRate = minPaymentFlowRate * 5/4;
            }
        } else {
            revert("Unsupported operation");
        }
        return newCtx;
    }

    /// @dev Equivalent of exiting the bet option
    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata ctx
    ) external override onlyHost returns (bytes memory newCtx) {
        if (!_isCFAv1(_agreementClass) || !_isSameToken(_superToken)) {
            return ctx;
        }
        newCtx = ctx;
        address streamMsgSender = host.decodeCtx(ctx).msgSender;
        if (streamMsgSender != buyer ||
           (streamMsgSender != owner && block.timestamp > freezePeriodEnd))
        {
            //Bet owner can only close the stream after the freeze period
            revert("Only buyer can close the stream before the expiry");
        } else {
            newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), owner, betToken);
            _resetBuyerAndFreeze();
        }
        return newCtx;
    }
}
