pragma solidity 0.5.17;

import "./IBUSD.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract BUSDEthManager {
    using SafeMath for uint256;

    IBUSD public busd_;

    mapping(bytes32 => bool) public usedEvents_;

    event Locked(
        address indexed token,
        address indexed sender,
        uint256 amount,
        address recipient
    );

    event Unlocked(uint256 amount, address recipient);

    mapping(address => uint256) public wards;

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        require(guy != owner, "EthManager/cannot deny the owner");
        wards[guy] = 0;
    }

    modifier auth {
        require(wards[msg.sender] == 1, "EthManager/not-authorized");
        _;
    }

    address public owner;

    /**
     * @dev constructor
     * @param busd token contract address, e.g., erc20 contract
     */
    constructor(IBUSD busd) public {
        owner = msg.sender;
        wards[msg.sender] = 1;
        busd_ = busd;
    }

    /**
     * @dev lock tokens to be minted on harmony chain
     * @param amount amount of tokens to lock
     * @param recipient recipient address on the harmony chain
     */
    function lockToken(uint256 amount, address recipient) public {
        require(
            recipient != address(0),
            "EthManager/recipient is a zero address"
        );
        require(amount > 0, "EthManager/zero token locked");
        uint256 _balanceBefore = busd_.balanceOf(msg.sender);
        require(
            busd_.transferFrom(msg.sender, address(this), amount),
            "EthManager/lock failed"
        );
        uint256 _balanceAfter = busd_.balanceOf(msg.sender);
        uint256 _actualAmount = _balanceBefore.sub(_balanceAfter);
        emit Locked(address(busd_), msg.sender, _actualAmount, recipient);
    }

    /**
     * @dev unlock tokens after burning them on harmony chain
     * @param amount amount of unlock tokens
     * @param recipient recipient of the unlock tokens
     * @param receiptId transaction hash of the burn event on harmony chain
     */
    function unlockToken(
        uint256 amount,
        address recipient,
        bytes32 receiptId
    ) public auth {
        require(
            !usedEvents_[receiptId],
            "EthManager/The burn event cannot be reused"
        );
        usedEvents_[receiptId] = true;
        require(busd_.transfer(recipient, amount), "EthManager/unlock failed");
        emit Unlocked(amount, recipient);
    }
}
