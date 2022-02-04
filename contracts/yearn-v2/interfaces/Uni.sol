// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface Uni {
    function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external;
}
