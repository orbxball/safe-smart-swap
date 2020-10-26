// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../interfaces/IDexHandler.sol";
import "../../interfaces/IGovernanceSwap.sol";
import "../../interfaces/ISafeSmartSwap.sol";

/*
 * SafeSmartSwap 
 */
abstract
contract SafeSmartSwap is ISafeSmartSwap {
    using SafeMath for uint256;

    IGovernanceSwap public governanceSwap;

    constructor(address _governanceSwap) public {
        governanceSwap = IGovernanceSwap(_governanceSwap);
    }

    // Governance path swap
    function _swap(uint256 _amount, address _in, address _out) internal returns (uint _amountOut) {

        address _handler = governanceSwap.getPairDefaultDexHandler(_in, _out);
        bytes memory _data = governanceSwap.getPairDefaultData(_in, _out);
        return IDexHandler(_handler).swap(_data, _amount);

    }

    // Custom path swap
    function _swap(uint256 _amount, address _in, address _out, address _dex, bytes memory _data) internal returns (uint _amountOut) {
        uint256 inBalancePreSwap = IERC20(_in).balanceOf(address(this));
        uint256 outBalancePreSwap = IERC20(_out).balanceOf(address(this));

        // Get governanceSwap amount for token pair
        address _defaultHandler = governanceSwap.getPairDefaultDexHandler(_in, _out);
        bytes memory _defaultData = governanceSwap.getPairDefaultData(_in, _out);
        uint256 _governanceAmountOut = IDexHandler(_defaultHandler).getAmountOut(_defaultData, _amount);

        address _handler = governanceSwap.getDexHandler(_dex);
        require(_handler != address(0), 'no-handler-for-dex');
        _amountOut = IDexHandler(_handler).swap(_data, _amount);

        require(
            _amountOut >= _governanceAmountOut,
            'custom-path-is-suboptimal'
        );
        // TODO Check gas spendage if _amountOut == _governanceAmountOut to avoid gas mining? (overkill)

        uint256 inBalancePostSwap = IERC20(_in).balanceOf(address(this));
        uint256 outBalancePostSwap = IERC20(_out).balanceOf(address(this));

        // Extra checks to avoid custom path exploits
        require(inBalancePostSwap >= inBalancePreSwap.sub(_amount), 'in-balance-mismatch');
        require(outBalancePostSwap >= outBalancePreSwap.add(_governanceAmountOut), 'out-balance-mismatch');
    }

}