// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "./BetOffer.sol";

contract BetFactory {

    uint256 public offerId;

    mapping(address => BetOffer[]) public ownerToOffers;
    mapping(uint256 => BetOffer) public idToOffer;

    function createNewOffer(
        int96 minPaymentFlowRate,
        bool isCall, // call "option" = true; put "option" = false;
        uint256 freezePeriod,
        int256 strikePrice,
        ISuperfluid host,
        address chainLinkOracle
    ) external {
        BetOffer newBetOffer = new BetOffer(
            msg.sender, //owner
            minPaymentFlowRate,
            isCall,
            freezePeriod,
            strikePrice,
            host,
            chainLinkOracle
        );

        offerId++;
        idToOffer[offerId] = newBetOffer;

        ownerToOffers[msg.sender].push(newBetOffer);
    }

    function getOffers(address owner) public view returns (BetOffer[] memory) {
        return ownerToOffers[owner];
    }
}