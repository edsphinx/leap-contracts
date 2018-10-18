pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721BasicToken.sol";
import "./ParsecBridge.sol";
import "./TxLib.sol";

contract ExitToken is ERC721BasicToken {

  // event Debug(bytes data);
  event ProxyExit(address exiter, uint256 utxoId);

  ParsecBridge public bridge;

  constructor(address b) public {
    bridge = ParsecBridge(b);
  }

  function proxyExit(bytes32[] _proof, uint256 _oindex) public {
    uint256 utxoId = uint256(bridge.startExit(_proof, _oindex));
    address exiter = recoverSigner(_proof);
    _mint(exiter, utxoId);
    emit ProxyExit(exiter, utxoId);
  }

  function withdrawUtxo(uint256 utxoId) public {
    (uint256 amount, uint16 color, , bool finalized, ) = bridge.exits(bytes32(utxoId));
    require(finalized);
    (address erc20, ) = bridge.tokens(color);
    ERC20(erc20).transfer(ownerOf(utxoId), amount);
    _burn(ownerOf(utxoId), utxoId);
  }

  // will only work from proxyExit due to calldata offset
  function recoverSigner(bytes32[] _proof) public pure returns (address signer) {
    uint256 offset = uint16(_proof[1] >> 248);
    uint256 txLength = uint16(_proof[1] >> 224);

    bytes memory txData = new bytes(txLength);

    // Use this to find calldata offset if params change
    // uint256 size;
    // assembly {
    //   size := calldatasize()
    // }
    // bytes memory callData = new bytes(size);
    // assembly {
    //   calldatacopy(add(callData, 32), 0, size)
    // }
    // emit Debug(callData);

    assembly {
      calldatacopy(add(txData, 32), add(100, offset), txLength)
    }
    TxLib.Tx memory txn = TxLib.parseTx(txData);
    signer = ecrecover(TxLib.getSigHash(txData), txn.ins[0].v, txn.ins[0].r, txn.ins[0].s);
  }

}