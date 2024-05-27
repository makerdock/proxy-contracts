// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ABDKMathQuad} from "abdk-libraries-solidity/ABDKMathQuad.sol";

library ABDKMathQuadLib {
    using ABDKMathQuad for bytes16;

    function powAndMultiply(uint256 a) internal pure returns (uint256) {
        // Convert a to quadruple precision
        bytes16 aQuad = ABDKMathQuad.fromUInt(a);

        // Calculate the exponent 1.05 in quadruple precision
        bytes16 exp = ABDKMathQuad.div(
            ABDKMathQuad.fromUInt(105),
            ABDKMathQuad.fromUInt(100)
        );

        // Calculate ln(a)
        bytes16 lnA = ABDKMathQuad.ln(aQuad);

        // Calculate 1.05 * ln(a)
        bytes16 exponentiatedLnA = ABDKMathQuad.mul(exp, lnA);

        // Calculate e^(1.05 * ln(a)) = a^1.05
        bytes16 resultQuad = ABDKMathQuad.exp(exponentiatedLnA);

        // Convert result back to uint256
        uint256 result = ABDKMathQuad.toUInt(resultQuad);

        // Multiply by 60
        return result * 60;
    }
}
