// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface Comptroller {
    function claimComp(address holder) external;
}
