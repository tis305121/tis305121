// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/ISlashCustomPlugin.sol";
import "./libs/UniversalERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IMyHackNFT {
    function mint(address to) external returns (uint256);
}


contract MyHackExtension is ISlashCustomPlugin, Ownable {
    using UniversalERC20 for IERC20;
    using SafeMath for uint256;

    // 寄付達成時にMintされるNFT
    IMyHackNFT private myHackNFT;
    IMyHackNFT private myHackNFTEveryone;

    // 寄付情報
    struct Donation {
        mapping(address => uint256) amounts;    // 各アカウントの寄付額のmapping
        address targetToken;                    // 寄付対象のトークン名
        address receiver;                       // 寄付の送り先addr
        string detailURI;                       // 寄付の詳細URL
        uint256 total;                          // 寄付の合計値
        uint256 goalPerAddr;                    // 寄付の目標値　個人
        uint256 goalPerEveryone;                // 寄付の目標値　全員
    }

    // 現在のフェーズ
    uint256 public currentPhase = 1;

    // フェーズごとの寄付情報
    mapping(uint256 => Donation) public donations;

    // 全員での寄付額達成のNFTを受け取ったか
    mapping(address => bool) nftReceivedFlags;

    // 寄付の割合
    uint256 public numerator; 
    uint256 private constant DENOMINATOR = 10000;

    constructor(address nftAddr, address nftAddrEveryone, uint256 numerator_) {
        myHackNFT = IMyHackNFT(nftAddr);
        myHackNFTEveryone = IMyHackNFT(nftAddrEveryone);
        numerator = numerator_;
    }

    function registerDonation(
        uint256 phase,
        address targetToken_,
        address receiver_,
        string memory detailURI_,
        uint256 goalPerAddr_,
        uint256 goalPerEveryone_
    ) external onlyOwner {
        require(
            targetToken_ != address(0) && 
            receiver_ != address(0) && 
            bytes(detailURI_).length != 0  && 
            goalPerAddr_ != 0 && 
            goalPerEveryone_ != 0, 
            "invalid parameter"
        );
        require(donations[phase].goalPerAddr == 0, "already registered");

        donations[phase].targetToken = targetToken_;
        donations[phase].receiver = receiver_;
        donations[phase].detailURI = detailURI_;
        donations[phase].goalPerAddr = goalPerAddr_;
        donations[phase].goalPerEveryone = goalPerEveryone_;
    }

    function updateDonation(
        uint256 phase,
        address receiver_,
        string memory detailURI_,
        uint256 goalPerAddr_,
        uint256 goalPerEveryone_
    ) external onlyOwner {
        require(
            receiver_ != address(0) && 
            bytes(detailURI_).length != 0 && 
            goalPerAddr_ != 0 && 
            goalPerEveryone_ != 0, 
            "invalid parameter"
        );
        require(donations[phase].goalPerAddr != 0, "not registered");
    
        donations[phase].receiver = receiver_;
        donations[phase].detailURI = detailURI_;
        donations[phase].goalPerAddr = goalPerAddr_;
        donations[phase].goalPerEveryone = goalPerEveryone_;
    }

    function setNftAddr(address nftAddr) external onlyOwner {
        myHackNFT = IMyHackNFT(nftAddr);
    }

    function setNftEveryoneAddr(address nftAddr) external onlyOwner {
        myHackNFTEveryone = IMyHackNFT(nftAddr);
    }

    function setNumerator(uint256 numerator_) external onlyOwner {
        require(numerator_ < DENOMINATOR, "invalid numerator");
        numerator = numerator_;
    }

    function setCurrentPhase(uint256 newPhase) external onlyOwner {
        currentPhase = newPhase;
    }

    function receivePayment(
        address receiveToken,
        uint256 amount,
        bytes calldata paymentId,
        string calldata optional,
        bytes calldata /** reserved */
    ) external payable override {
        require(amount > 0, "invalid amount");
        
        // 寄付対象のトークンでの支払いか判別
        if (isDonation(receiveToken)) {
            uint256 donationAmount = calcDonation(amount);
            IERC20(receiveToken).universalTransferFromSenderToThis(amount);
            IERC20(receiveToken).universalTransfer(owner(), amount.sub(donationAmount));
            IERC20(receiveToken).universalTransfer(donations[currentPhase].receiver, donationAmount);
            afterReceived(donationAmount);
        } else {
            IERC20(receiveToken).universalTransferFrom(msg.sender, owner(), amount);
        }
    }

    function afterReceived(uint256 donationAmount) internal {
        uint256 preAmount = donations[currentPhase].amounts[tx.origin];
        uint256 preTotal = donations[currentPhase].total;
        donations[currentPhase].amounts[tx.origin] += donationAmount;
        donations[currentPhase].total += donationAmount;
        
        if (preAmount < donations[currentPhase].goalPerAddr && donations[currentPhase].amounts[tx.origin] >= donations[currentPhase].goalPerAddr) {
            myHackNFT.mint(tx.origin);
        }
        if (preTotal < donations[currentPhase].goalPerEveryone && donations[currentPhase].total >= donations[currentPhase].goalPerEveryone) {
            // 全員での寄付額合計が、目標値を超えた場合の処理を行う
            if (!nftReceivedFlags[tx.origin]) {
                nftReceivedFlags[tx.origin] = true;
                myHackNFTEveryone.mint(tx.origin);
            }
        }   
    }

    function calcDonation(uint256 amount) internal view returns (uint256) {
        return ((amount.mul(numerator)).div(DENOMINATOR)); 
    }

    function isDonation(address receiveToken) internal view returns (bool) {
        return (receiveToken == donations[currentPhase].targetToken);
    }

    function supportSlashExtensionInterface()
        external
        pure
        override
        returns (uint8)
    {
        return 2;
    }
}
