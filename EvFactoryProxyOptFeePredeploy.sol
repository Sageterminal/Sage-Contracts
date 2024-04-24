// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC314
 * @dev Implementation of the ERC314 interface.
 * ERC314 is a derivative of ERC20 which aims to integrate a liquidity pool on the token in order to enable native swaps, notably to reduce gas consumption.
 */

// Events interface for ERC314
interface IEERC314 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AddLiquidity(uint32 _timeTillUnlockLiquidity, uint256 value);
    event RemoveLiquidity(uint256 value);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
}

interface IFactory {
    function getOwner() external view returns (address);
}

struct Opt {
    uint32 timeTillUnlockLiquidity;
    bool tradingEnable;
    bool liquidityAdded;
    bool maxWalletEnable;
    bool feeDisable;
    bool ownerRenounced;
    bool liquidityProviderRenounced;
    bool feeCollectorRenounced;
    uint16 fee;
}

abstract contract ERC314Implementation is IEERC314 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    Opt private _opt;

    uint256 public maxWallet;

    address private _liquidityProvider;
    address private _feeCollector;

    uint256 public accruedFeeAmount;

    modifier onlyOwner() {
        require(msg.sender == this.owner(), "Ownable: caller is not the owner");
        _;
    }

    modifier onlyLiquidityProvider() {
        require(
            msg.sender == this.liquidityProvider(),
            "You are not the liquidity provider"
        );
        _;
    }

    modifier onlyFeeCollector() {
        require(msg.sender == this.feeCollector(), "You are not the fee collector");
        _;
    }

    function initialize(uint256 percentSupplyDeployer) external {
        require(_balances[address(this)] == 0);
        address _owner = this.owner();
        uint _totalSupply = this.totalSupply();
        _balances[_owner] = _totalSupply *percentSupplyDeployer/ 100;
        uint256 liquidityAmount = _totalSupply - _balances[_owner];
        _balances[address(this)] = liquidityAmount;
    }

    function factory() public view virtual returns (address) {
        assembly {
            extcodecopy(address(), sub(0x20, 0x14), 0x2d, 0x14)
            return(0x0, 0x20)
        }
    }

    function owner() public view virtual returns (address) {
        if (_opt.ownerRenounced) return address(0);
        assembly {
            extcodecopy(address(), sub(0x20, 0x14), 0x41, 0x14)
            return(0x0, 0x20)
        }
    }

    function totalSupply() public view virtual returns (uint _totalSupply) {
        assembly {
            extcodecopy(address(), 0x20, 0x55, 0x4)
            let lengths := mload(0x20)
            let offset := add(0x55, 0x4)
            let length := byte(0x0, lengths)
            extcodecopy(address(), sub(0x20, length), offset, length)
            _totalSupply := mload(0x0)
        }
        return _totalSupply - _balances[address(0)];
    }

    function fee() public view virtual returns (uint16) {
        if (_opt.feeDisable) return 0;
        if (_opt.fee != 0) return _opt.fee;
        assembly {
            extcodecopy(address(), 0x20, 0x55, 0x4)
            let lengths := mload(0x20)
            let offset := add(0x55, 0x4)
            offset := add(offset, byte(0x0, lengths))
            let length := byte(0x1, lengths)
            extcodecopy(address(), sub(0x20, length), offset, length)
            return(0x0, 0x20)
        }
    }

    function name() public view virtual returns (string memory) {
        assembly {
            extcodecopy(address(), 0x20, 0x55, 0x4)
            let lengths := mload(0x20)
            let offset := add(0x55, 0x4)
            offset := add(offset, byte(0x0, lengths))
            offset := add(offset, byte(0x1, lengths))
            let length := byte(0x2, lengths)
            mstore(0x40, 0x0)
            extcodecopy(address(), 0x40, offset, length)
            mstore(0x0, 0x20)
            mstore(0x20, length)
            return(0x0, 0x60)
        }
    }

    function symbol() public view virtual returns (string memory) {
        assembly {
            extcodecopy(address(), 0x20, 0x55, 0x4)
            let lengths := mload(0x20)
            let offset := add(0x55, 0x4)
            offset := add(offset, byte(0x0, lengths))
            offset := add(offset, byte(0x1, lengths))
            offset := add(offset, byte(0x2, lengths))
            let length := byte(0x3, lengths)
            mstore(0x40, 0x0)
            extcodecopy(address(), 0x40, offset, length)
            mstore(0x0, 0x20)
            mstore(0x20, length)
            return(0x0, 0x60)
        }
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function WETH() public pure virtual returns (address) {
        return address(0x4200000000000000000000000000000000000006);
    }

    function token0() public pure virtual returns (address) {
        return address(0x4200000000000000000000000000000000000006);
    }

    function token1() public view virtual returns (address) {
        return address(this);
    }

    function liquidityProvider() public view virtual returns (address) {
        if (_opt.liquidityProviderRenounced) return address(0);
        if (_liquidityProvider != address(0)) return _liquidityProvider;
        return this.owner();
    }

    function feeCollector() public view virtual returns (address) {
        if (_opt.feeCollectorRenounced) return address(0);
        if (_feeCollector != address(0)) return _feeCollector;
        return this.owner();
    }

    function timeTillUnlockLiquidity() public view virtual returns (uint32) {
        return _opt.timeTillUnlockLiquidity;
    }

    function tradingEnable() public view virtual returns (bool) {
        return _opt.tradingEnable;
    }

    function liquidityAdded() public view virtual returns (bool) {
        return _opt.liquidityAdded;
    }

    function maxWalletEnable() public view virtual returns (bool) {
        return _opt.maxWalletEnable;
    }
 
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
     
        _transfer(msg.sender, to, value);
        
        return true;
    }

    function allowance(address _owner, address spender) public view virtual returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        require(_allowances[from][msg.sender] >= value, "ERC314: transfer amount exceeds allowance");
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowances[from][msg.sender] - value);
        return true;
    }

    function _approve(address _owner, address spender, uint256 value) internal virtual {
        require(_owner != address(0), "ERC314: approve from the zero address");
        require(spender != address(0), "ERC314: approve to the zero address");

        _allowances[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {

        require(
            _balances[from] >= value,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[from] -= value;
        }

        unchecked {
            _balances[to] += value;
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
        _opt.tradingEnable = _tradingEnable;
    }

    /**
     * @dev Enables or disables the max wallet.
     * @param _maxWalletEnable: true to enable max wallet, false to disable max wallet.
     * onlyOwner modifier
     */
    function enableMaxWallet(bool _maxWalletEnable) external onlyOwner {
        _opt.maxWalletEnable = _maxWalletEnable;
    }

    /**
     * @dev Modify trading fees
     * @param _fee: trading fee amount
     * onlyOwner modifier
     */

    function setTradingFee(uint16 _fee) external onlyOwner {
        require(_fee <= 500, "max 5% fee");
        _opt.fee = _fee;
        if (_fee == 0) _opt.feeDisable = true;
        if (_fee != 0) _opt.feeDisable = false;
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
        _feeCollector = _newFeeCollector;
        if (_newFeeCollector == address(0)) _opt.feeCollectorRenounced = true;
        if (_newFeeCollector != address(0)) _opt.feeCollectorRenounced = false;
    }

    /**
     * @dev Transfers the ownership of the contract to zero address
     * onlyOwner modifier
     */
    function renounceOwnership() external onlyOwner {
        if (!_opt.feeCollectorRenounced && _feeCollector == address(0)) _feeCollector = this.owner();
        if (!_opt.liquidityProviderRenounced && _liquidityProvider == address(0)) _liquidityProvider = this.owner();
        _opt.ownerRenounced = true;
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
        _liquidityProvider = _newLiquidityProvider;
        if (_newLiquidityProvider == address(0)) _opt.liquidityProviderRenounced = true;
        if (_newLiquidityProvider != address(0)) _opt.liquidityProviderRenounced = false;
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
        require(_opt.liquidityAdded == false, "Liquidity already added");

        _opt.liquidityAdded = true;

        require(msg.value > 0, "No ETH sent");
        require(
            block.timestamp < _timeTillUnlockLiquidity,
            "The time until unlock liquidity is too low"
        );

        _opt.timeTillUnlockLiquidity = _timeTillUnlockLiquidity;
        _opt.tradingEnable = true;

        emit AddLiquidity(_timeTillUnlockLiquidity, msg.value);
    }

    /**
     * @dev Removes liquidity from the contract.
     * onlyLiquidityProvider modifier
     */
    function removeLiquidity() public onlyLiquidityProvider {
        require(block.timestamp > _opt.timeTillUnlockLiquidity, "Liquidity locked");

        _opt.tradingEnable = false;

        (uint256 reserveETH, ) = getReserves();

        (bool success, ) = payable(msg.sender).call{value: reserveETH}("");
        if (!success) {
            revert("Could not remove liquidity");
        }
        _opt.liquidityAdded = false; 

        emit RemoveLiquidity(reserveETH);
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
            _opt.timeTillUnlockLiquidity < _timeTillUnlockLiquidity,
            "You can't shorten duration"
        );

        _opt.timeTillUnlockLiquidity = _timeTillUnlockLiquidity;
    }

    /**
     * @dev Estimates the amount of tokens or ETH to receive when buying or selling.
     * @param value: the amount of ETH or tokens to swap.
     * @param _buyBool: true if buying, false if selling.
     */
    function getAmountOut(
        uint256 value,
        bool _buyBool
    ) public view returns (uint256) {
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        if (_buyBool) {
            uint256 valueAfterFee = (value * (10000 - this.fee())) / 10000;
            return ((valueAfterFee * reserveToken)) / (reserveETH + valueAfterFee);
        } else {
            uint256 ethValue = ((value * reserveETH)) / (reserveToken + value);
            ethValue = (ethValue * (10000 - this.fee())) / 10000;
            return ethValue;
        }
    }

    /**
     * @dev Buys tokens with ETH.
     * internal function
     */
    function buy(uint256 amountOutMin) public payable {
        require(_opt.tradingEnable, "Trading not enable");

        uint256 feeAmount = (msg.value * this.fee()) / 10000;

        uint256 ETHafterFee;
        unchecked {
            ETHafterFee = msg.value - feeAmount;
        }

        unchecked {
            accruedFeeAmount += feeAmount;
        }
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        uint256 tokenAmount = (ETHafterFee * reserveToken) / reserveETH;
        require(tokenAmount > 0, "Bought amount too low");

        if (_opt.maxWalletEnable) {
            require(
                tokenAmount + _balances[msg.sender] <= maxWallet,
                "Max wallet exceeded"
            );
        }

        require(tokenAmount >= amountOutMin, "slippage reached");

        _transfer(address(this), msg.sender, tokenAmount);

        emit Swap(msg.sender, msg.value, 0, 0, tokenAmount,msg.sender);
    }

    // Modify the claimFees function to distribute fees accordingly
    function claimFees() external {
        uint256 totalAccruedAmount = accruedFeeAmount;
        if (totalAccruedAmount > address(this).balance) {
            totalAccruedAmount = address(this).balance;
        }


        uint256 factoryShare = (totalAccruedAmount * 10) / 100; // 10% to factory owner

        //give all fees to factory if reannounced
        If (_opt.feeCollectorRenounced) {
            factoryShare = totalAccruedAmount;
        }

        uint256 ownerShare = totalAccruedAmount - factoryShare;

        accruedFeeAmount = 0;

        if(factoryShare > 0) {
            (bool successFactory, ) = payable(IFactory(this.factory()).getOwner()).call{value: factoryShare}("");
            
        }

        (bool successOwner, ) = payable(feeCollector()).call{value: ownerShare}("");
        
    }


    /**
     * @dev Sells tokens for ETH.
     * internal function
     */
    function sell(uint256 sellAmount, uint256 amountOutMin) public {
        require(_opt.tradingEnable, "Trading not enable");

        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        uint256 ethAmount = (sellAmount * reserveETH) /
            (reserveToken + sellAmount);

        require(reserveETH >= ethAmount, "Insufficient ETH in reserves");

        uint256 feeAmount = (ethAmount * this.fee()) / 10000;

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

        emit Swap(msg.sender, 0, sellAmount, ethAmount, 0, msg.sender);
    }

}

// free function to determine bytes needed to store some number
function bytesNeeded(uint x) pure returns (uint8) {
    for (uint i; i < 8; i++) x |= x >> (1 << i);
    unchecked { x = x 
        * 0xFF7E7D7C7B7A79787767574737271706D6C6A6968665646261605514941211 
        >> 248; }
    return uint8(bytes(
        hex'00D201EDD37F02F6EED4CAA8804403FBF7EFC2DFD5CB77BDA9918161452504FC'
        hex'F3F8BAF0E5C36FE8E0D6B2CCA0783CC6BEAEAA9A9282677262524636261605FD'
        hex'EBF4A6F9DDBB5FF1E3E69EC4987034E9DBE196D9D7B357CDB5A18979593D1DCF'
        hex'C7BF8EB7AFAB4FA39B93868B83682C7B736B635B534B473F372F271F170F06FE'
        hex'D1EC7EF5C9A743FAC1DE76BC906024F2B9E46EE7B19F3BC5AD996671513515EA'
        hex'A5DC5EE29D9733DA95D856B488581CCE8DB64EA2858A2B7A6A5A4A3E2E1E0ED0'
        hex'7DC842C0758F23B86DB03AAC655014A45D9C329455871B8C4D842A69492D0D7C'
        hex'4174226C3964135C31541A4C29480C402138123019280B2011180A10090807FF'
        )[x]) / 8 + 1; }

contract BlankERC314 is ERC314Implementation {
    constructor() {}
}

contract EVToken is ERC314Implementation {
    constructor(
        address implementation,
        address factory,
        address owner,
        uint totalSupply,
        uint fee,
        string memory name,
        string memory symbol
    ) {
        require(fee <= 500, "max 5% fee");
        require(bytes(symbol).length <= 32, "symbol too long");
        require(bytes(name).length <= 32, "name too long");

        uint sizeCursor;
        assembly { sizeCursor := mload(0x40) }
        uint byteCursor = sizeCursor;
        uint byteCursorInit = byteCursor;

        uint erc1167Left = 0x363d3d373d3d3d363d73;
        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, 0xa)), erc1167Left)) }
        sizeCursor += 0xa;
        byteCursor += 0xa;
        assembly { mstore(0x40, add(mload(0x40), 0xa)) }

        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, 0x14)), implementation)) }
        sizeCursor += 0x14;
        byteCursor += 0x14;
        assembly { mstore(0x40, add(mload(0x40), 0x14)) }

        uint erc1167Right = 0x5af43d82803e903d91602b57fd5bf3;
        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, 0xf)), erc1167Right)) }
        sizeCursor += 0xf;
        byteCursor += 0xf;
        assembly { mstore(0x40, add(mload(0x40), 0xf)) }
        
        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, 0x14)), factory)) }
        sizeCursor += 0x14;
        byteCursor += 0x14;
        assembly { mstore(0x40, add(mload(0x40), 0x14)) }
        
        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, 0x14)), owner)) }
        sizeCursor += 0x14;
        byteCursor += 0x14;
        assembly { mstore(0x40, add(mload(0x40), 0x14)) }

        byteCursor += 0x4;

        uint8 totalSupplyBytesNeeded = bytesNeeded(totalSupply);
        assembly { mstore8(sizeCursor, totalSupplyBytesNeeded) }
        sizeCursor += 0x1;
        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, totalSupplyBytesNeeded)), totalSupply)) }
        byteCursor += totalSupplyBytesNeeded;
        assembly { mstore(0x40, add(mload(0x40), add(0x1, totalSupplyBytesNeeded))) }

        uint8 feeBytesNeeded = bytesNeeded(fee);
        assembly { mstore8(sizeCursor, feeBytesNeeded) }
        sizeCursor += 0x1;
        assembly { mstore(byteCursor, shl(mul(0x8, sub(0x20, feeBytesNeeded)), fee)) }
        byteCursor += feeBytesNeeded;
        assembly { mstore(0x40, add(mload(0x40), add(0x1, feeBytesNeeded))) }

        uint8 nameBytesNeeded = uint8(bytes(name).length);
        assembly { mstore8(sizeCursor, nameBytesNeeded) }
        sizeCursor += 0x1;
        assembly { mstore(byteCursor, mload(add(0x20, name))) }
        byteCursor += nameBytesNeeded;
        assembly { mstore(0x40, add(mload(0x40), add(0x1, nameBytesNeeded))) }

        uint8 symbolBytesNeeded = uint8(bytes(symbol).length);
        assembly { mstore8(sizeCursor, symbolBytesNeeded) }
        sizeCursor += 0x1;
        assembly { mstore(byteCursor, mload(add(0x20, symbol))) }
        byteCursor += symbolBytesNeeded;
        assembly { mstore(0x40, add(mload(0x40), add(0x1, symbolBytesNeeded))) }

        assembly { return(byteCursorInit, sub(byteCursor, byteCursorInit)) }
    }
}

contract ERC314Factory {
    address[] public allTokens;
    address public owner;
    uint public deployFee;
    uint16 public split;
    uint public accruedFeeAmount;
    address public evFeeCollector;
    address public dzhvFeeCollector;

    constructor(uint _deployFee, uint16 _split, address _evFeeCollector, address _dzhvFeeCollector) {
        require(_split <= 10000, "split cannot exceed 100%");
        owner = msg.sender;
        // implementation = new BlankERC314();
        deployFee = _deployFee;
        split = _split;
        evFeeCollector = _evFeeCollector;
        dzhvFeeCollector = _dzhvFeeCollector;
    }

    event TokenCreated(address tokenAddress);

    function createERC314(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 fee,
        uint256 deployerSupplyPercentage
    ) public payable {
        require(deployerSupplyPercentage <= 100, "percent cannot exceed 100%");
        require(msg.value == deployFee, "deployment fee not paid");
        accruedFeeAmount += msg.value;
        EVToken newToken = new EVToken(
            address(0x94feeD82755b4a1Ec918fA38f4D6e7Be6c651A36),
            address(this),
            msg.sender,
            totalSupply,
            fee,
            name,
            symbol
        );
        newToken.initialize(deployerSupplyPercentage);
        // allTokens.push(address(newToken));
        emit TokenCreated(address(newToken));
    }

    modifier onlyOwner() {
        require(msg.sender == this.owner(), "Ownable: caller is not the owner");
        _;
    }

    function setDeployFee(uint _newDeployFee) external onlyOwner {
        deployFee = _newDeployFee;
    }

    function claimFees() external {
        uint256 totalAccruedAmount = accruedFeeAmount;
        if (totalAccruedAmount > address(this).balance) {
            totalAccruedAmount = address(this).balance;
        }

        uint256 evTeamShare = (totalAccruedAmount * split) / 10000;
        uint256 dzhvTeamShare = totalAccruedAmount - evTeamShare;

        accruedFeeAmount = 0;

        (bool successEvFeeCollect, ) = payable(evFeeCollector).call{value: evTeamShare}("");
        require(successEvFeeCollect, "Transfer of EV team share failed");

        (bool successDzhvFeeCollect, ) = payable(dzhvFeeCollector).call{value: dzhvTeamShare}("");
        require(successDzhvFeeCollect, "Transfer of DZHV team share failed");
    }

    // Add function to retrieve factory owner for fee distribution
    function getOwner() external view returns (address) {
        return owner;
    }

    function setFeesWallet(address _evWallet, address _dzhvWallet) external onlyOwner {
        evFeeCollector = _evWallet;
        dzhvFeeCollector = _dzhvWallet;
    }

}
