// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TokenizedTreasury
 * @notice ERC20 token representing tokenized treasury notes on Arbitrum
 * @dev Each token represents a fractional ownership of US Treasury notes
 *      Includes compliance features like pause and authorized minting
 */
contract TokenizedTreasury is ERC20, ERC20Burnable, Ownable, Pausable {
    // Treasury note details
    uint256 public immutable maturityDate;
    uint256 public immutable couponRate; // Basis points (e.g., 500 = 5%)
    string public cusip; // CUSIP identifier for the underlying treasury

    // Compliance and control
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public blacklisted;

    // Token economics
    uint256 public constant DECIMALS_MULTIPLIER = 10**18;
    uint256 public totalValueLocked; // Total USD value of underlying treasuries

    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event TreasuryDetailsUpdated(string cusip, uint256 totalValue);

    modifier onlyMinter() {
        require(authorizedMinters[msg.sender], "TokenizedTreasury: not authorized minter");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "TokenizedTreasury: account blacklisted");
        _;
    }

    /**
     * @param _name Token name (e.g., "Tokenized US Treasury 2-Year")
     * @param _symbol Token symbol (e.g., "UST2Y")
     * @param _maturityDate Unix timestamp of treasury maturity
     * @param _couponRate Annual coupon rate in basis points
     * @param _cusip CUSIP identifier for the treasury
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maturityDate,
        uint256 _couponRate,
        string memory _cusip
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_maturityDate > block.timestamp, "TokenizedTreasury: invalid maturity date");
        maturityDate = _maturityDate;
        couponRate = _couponRate;
        cusip = _cusip;

        // Owner is initially an authorized minter
        authorizedMinters[msg.sender] = true;
    }

    /**
     * @notice Mint new treasury tokens (only for authorized minters)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
        require(to != address(0), "TokenizedTreasury: mint to zero address");
        require(!blacklisted[to], "TokenizedTreasury: recipient blacklisted");
        _mint(to, amount);
    }

    /**
     * @notice Authorize an address to mint tokens
     * @param minter Address to authorize
     */
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /**
     * @notice Revoke minting authorization
     * @param minter Address to revoke
     */
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /**
     * @notice Add an address to the blacklist
     * @param account Address to blacklist
     */
    function addToBlacklist(address account) external onlyOwner {
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @notice Remove an address from the blacklist
     * @param account Address to unblacklist
     */
    function removeFromBlacklist(address account) external onlyOwner {
        blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    /**
     * @notice Update treasury backing details
     * @param _totalValue Total USD value of underlying treasuries
     */
    function updateTreasuryDetails(uint256 _totalValue) external onlyOwner {
        totalValueLocked = _totalValue;
        emit TreasuryDetailsUpdated(cusip, _totalValue);
    }

    /**
     * @notice Pause all token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Get the current value per token in USD (18 decimals)
     * @return Value per token
     */
    function getValuePerToken() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return DECIMALS_MULTIPLIER;
        return (totalValueLocked * DECIMALS_MULTIPLIER) / supply;
    }

    /**
     * @notice Check if treasury has matured
     * @return True if matured
     */
    function hasMatured() external view returns (bool) {
        return block.timestamp >= maturityDate;
    }

    /**
     * @notice Calculate accrued interest (simplified)
     * @param principal Principal amount
     * @return Accrued interest
     */
    function calculateAccruedInterest(uint256 principal) external view returns (uint256) {
        if (block.timestamp >= maturityDate) {
            return (principal * couponRate) / 10000;
        }
        uint256 timeElapsed = block.timestamp - (maturityDate - 365 days);
        return (principal * couponRate * timeElapsed) / (10000 * 365 days);
    }

    // Override transfer functions to include compliance checks
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        if (from != address(0)) {
            require(!blacklisted[from], "TokenizedTreasury: sender blacklisted");
        }
        if (to != address(0)) {
            require(!blacklisted[to], "TokenizedTreasury: recipient blacklisted");
        }
        super._update(from, to, amount);
    }
}