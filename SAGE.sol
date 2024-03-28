pragma solidity ^0.8.20;

/**
 * @title ERC314
 * @dev Implementation of the ERC314 interface.
 * ERC314 is a derivative of ERC20 which aims to integrate a liquidity pool on the token in order to enable native swaps, notably to reduce gas consumption.
 */

// Events interface for ERC314
interface IEERC314 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AddLiquidity(uint32 _timeTillUnlockLiquidity, uint256 value);
    event RemoveLiquidity(uint256 value);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out
    );
}

abstract contract ERC314 is IEERC314 {
    mapping(address account => uint256) private _balances;

    uint256 private _totalSupply;
    uint256 public maxWallet;
    uint32 public timeTillUnlockLiquidity;

    string private _name;
    string private _symbol;

    address public owner;
    address public liquidityProvider;
    address public feeCollector;

    bool public tradingEnable;
    bool public liquidityAdded;
    bool public maxWalletEnable;
    uint256 public fee; //trading fee

    mapping(address account => uint32) public lastTransaction;
    uint256 public accruedFeeAmount;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyLiquidityProvider() {
        require(
            msg.sender == liquidityProvider,
            "You are not the liquidity provider"
        );
        _;
    }

    modifier onlyFeeCollector() {
        require(msg.sender == feeCollector, "You are not the fee collector");
        _;
    }

    /**
     * @dev Sets the values for {name}, {symbol} and {totalSupply} and {fee}
     *
     * The name and symbol are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 _fee
    ) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_;
        maxWallet = totalSupply_ / 50;
        owner = msg.sender;
        maxWalletEnable = true;
        _balances[msg.sender] = totalSupply_ /5;
        uint256 liquidityAmount = totalSupply_ - _balances[msg.sender];
        _balances[address(this)] = liquidityAmount;
        liquidityProvider = msg.sender;
        feeCollector = msg.sender;
        fee = _fee;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - the caller must have a balance of at least `value`.
     * - if the receiver is the contract, the caller must send the amount of tokens to sell
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively burns if `to` is the zero address.
     * All customizations to transfers and burns should be done by overriding this function.
     * This function includes MEV protection, which prevents the same address from making two transactions in the same block.(lastTransaction)
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        require(
            lastTransaction[msg.sender] != block.number,
            "You can't make two transactions in the same block"
        );

        lastTransaction[msg.sender] = uint32(block.number);

        require(
            _balances[from] >= value,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[from] -= value;
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Returns the amount of ETH and tokens in the contract, used for trading.
     */
    function getReserves() public view returns (uint256, uint256) {
        return (
            (address(this).balance - accruedFeeAmount),
            _balances[address(this)]
        );
    }

    /**
     * @dev Enables or disables trading.
     * @param _tradingEnable: true to enable trading, false to disable trading.
     * onlyOwner modifier
     */
    function enableTrading(bool _tradingEnable) external onlyOwner {
        tradingEnable = _tradingEnable;
    }

    /**
     * @dev Enables or disables the max wallet.
     * @param _maxWalletEnable: true to enable max wallet, false to disable max wallet.
     * onlyOwner modifier
     */
    function enableMaxWallet(bool _maxWalletEnable) external onlyOwner {
        maxWalletEnable = _maxWalletEnable;
    }

    /**
     * @dev Modify trading fees
     * @param _fee: trading fee amount
     * onlyOwner modifier
     */

    function setTradingFee(uint256 _fee) external onlyOwner {
        require(_fee <= 500, "max 5% fee");
        fee = _fee;
    }

    /**
     * @dev Sets the max wallet.
     * @param _maxWallet_: the new max wallet.
     * onlyOwner modifier
     */
    function setMaxWallet(uint256 _maxWallet_) external onlyOwner {
        maxWallet = _maxWallet_;
    }

    /**
     *
     * @dev Sets the new fee collector
     * @param _newFeeCollector the new fee collector
     * onlyOwner modifier
     */
    function setFeeCollector(address _newFeeCollector) external onlyOwner {
        feeCollector = _newFeeCollector;
    }

    /**
     * @dev Transfers the ownership of the contract to zero address
     * onlyOwner modifier
     */
    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }

    /**
     *
     * @dev Sets the new liquidity provider
     * @param _newLiquidityProvider the new liquidity provider
     * onlyLiquidityProvider modifier
     */
    function setLiquidityProvider(
        address _newLiquidityProvider
    ) external onlyLiquidityProvider {
        liquidityProvider = _newLiquidityProvider;
    }

    /**
     * @dev Adds liquidity to the contract.
     * @param _timeTillUnlockLiquidity: the block timestamp to unlock the liquidity.
     * value: the amount of ETH to add to the liquidity.
     * onlyLiquidityProvider modifier
     */
    function addLiquidity(
        uint32 _timeTillUnlockLiquidity
    ) public payable onlyLiquidityProvider {
        require(liquidityAdded == false, "Liquidity already added");

        liquidityAdded = true;

        require(msg.value > 0, "No ETH sent");
        require(
            block.timestamp < _timeTillUnlockLiquidity,
            "The time until unlock liquidity is too low"
        );

        timeTillUnlockLiquidity = _timeTillUnlockLiquidity;
        tradingEnable = true;

        emit AddLiquidity(_timeTillUnlockLiquidity, msg.value);
    }

    /**
     * @dev Removes liquidity from the contract.
     * onlyLiquidityProvider modifier
     */
    function removeLiquidity() public onlyLiquidityProvider {
        require(block.timestamp > timeTillUnlockLiquidity, "Liquidity locked");

        tradingEnable = false;

        (uint256 reserveETH, ) = getReserves();

        (bool success, ) = payable(msg.sender).call{value: reserveETH}("");
        if (!success) {
            revert("Could not remove liquidity");
        }

        emit RemoveLiquidity(address(this).balance);
    }

    /**
     * @dev Extends the liquidity lock, only if the new block timestamp is higher than the current one.
     * @param _timeTillUnlockLiquidity: the new block timestamp to unlock the liquidity.
     * onlyLiquidityProvider modifier
     */
    function extendLiquidityLock(
        uint32 _timeTillUnlockLiquidity
    ) public onlyLiquidityProvider {
        require(
            timeTillUnlockLiquidity < _timeTillUnlockLiquidity,
            "You can't shorten duration"
        );

        timeTillUnlockLiquidity = _timeTillUnlockLiquidity;
    }

    /**
     * @dev Estimates the amount of tokens or ETH to receive when buying or selling.
     * @param value: the amount of ETH or tokens to swap.
     * @param _buy: true if buying, false if selling.
     */
    function getAmountOut(
        uint256 value,
        bool _buy
    ) public view returns (uint256) {
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        if (_buy) {
            uint256 valueAfterFee = (value * (10000 - fee)) / 10000;
            return ((valueAfterFee * reserveToken)) / (reserveETH + value);
        } else {
            uint256 ethValue = ((value * reserveETH)) / (reserveToken + value);
            ethValue = (ethValue * (10000 - fee)) / 10000;
            return ethValue;
        }
    }

    /**
     * @dev Buys tokens with ETH.
     * internal function
     */
    function buy(uint256 amountOutMin) public payable {
        require(tradingEnable, "Trading not enable");

        uint256 feeAmount = (msg.value * fee) / 10000;

        uint256 ETHafterFee;
        unchecked {
            ETHafterFee = msg.value - feeAmount;
        }

        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        uint256 tokenAmount = (ETHafterFee * reserveToken) / reserveETH;
        require(tokenAmount > 0, "Bought amount too low");
        unchecked {
            accruedFeeAmount += feeAmount;
        }

        if (maxWalletEnable) {
            require(
                tokenAmount + _balances[msg.sender] <= maxWallet,
                "Max wallet exceeded"
            );
        }

        require(tokenAmount >= amountOutMin, "slippage reached");

        _transfer(address(this), msg.sender, tokenAmount);

        emit Swap(msg.sender, msg.value, 0, 0, tokenAmount);
    }

    function claimFees() external onlyFeeCollector {
        uint256 accruedAmount = accruedFeeAmount;

        if (accruedAmount > address(this).balance)
            // in case we don't have enough eth for the fees, just send the balance
            accruedAmount = address(this).balance;

        accruedFeeAmount = 0;
        (bool success, ) = payable(msg.sender).call{value: accruedAmount}("");
        if (!success) revert("Transfer of fee failed");
    }

    /**
     * @dev Sells tokens for ETH.
     * internal function
     */
    function sell(uint256 sellAmount, uint256 amountOutMin) public {
        require(tradingEnable, "Trading not enable");

        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        uint256 ethAmount = (sellAmount * reserveETH) /
            (reserveToken + sellAmount);

        require(reserveETH >= ethAmount, "Insufficient ETH in reserves");

        uint256 feeAmount = (ethAmount * fee) / 10000;

        unchecked {
            ethAmount -= feeAmount;
        }
        require(ethAmount > 0, "Sell amount too low");
        require(ethAmount >= amountOutMin, "slippage reached");

        unchecked {
            accruedFeeAmount += feeAmount;
        }

        _transfer(msg.sender, address(this), sellAmount);

        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        if (!success) {
            revert("Could not sell");
        }

        emit Swap(msg.sender, 0, sellAmount, ethAmount, 0);
    }
}

contract SAGE is ERC314 {
    constructor() ERC314("SAGE ERC314", "SAGE", 1_000_000 * 10 ** 18, 100) {}
}
