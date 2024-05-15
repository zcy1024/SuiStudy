import dotenv from "dotenv";
import { NAVISDKClient } from "navi-sdk/dist";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { getFullnodeUrl } from "@mysten/sui.js/client";
import { Dex } from "kriya-dex-sdk";
import { Pool as kriya_Pool } from "kriya-dex-sdk/dist/types";
import { flashloan, depositCoin, borrowCoin, repayFlashLoan, SignAndSubmitTXB } from "navi-sdk/dist/libs/PTB";
import { Sui, vSui, pool } from 'navi-sdk/dist/address.js';
import { Pool, PoolConfig } from "navi-sdk/dist/types";

async function main() {
    dotenv.config();
    const MNEMONIC = process.env.MNEMONIC!;
    // console.log(MNEMONIC);

    const client = new NAVISDKClient({mnemonic: MNEMONIC, numberOfAccounts: 1});
    const account = client.accounts[0];
    // console.log(account.getAllCoins());

    const txb: any = new TransactionBlock();
    // const url = getFullnodeUrl("mainnet");
    // const dex = new Dex(url);
    const vSui_Sui_Pool: kriya_Pool = {
        objectId: "0xf385dee283495bb70500f5f8491047cd5a2ef1b7ff5f410e6dfe8a3c3ba58716",
        tokenXType: "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
        tokenYType: "0x2::sui::SUI",
    };

    // step 1
    const flash_amount = 11 * 10 ** 9;
    const Sui_Pool: PoolConfig = pool[Sui.symbol as keyof Pool];
    const [flash_balance, receipt] = await flashloan(txb, Sui_Pool, flash_amount);
    const flash_coin = await txb.moveCall({
        target: "0x2::coin::from_balance",
        arguments: [flash_balance],
        typeArguments: [Sui_Pool.type],
    });

    // step 2
    const swap_vsui = await txb.moveCall({
        target: "0xa0eba10b173538c8fecca1dff298e488402cc9ff374f8a12ca7758eebe830b66::spot_dex::swap_token_y",
        arguments: [
            txb.object(vSui_Sui_Pool.objectId),
            txb.object(flash_coin),
            txb.pure(flash_amount),
            txb.pure(10 * 10 ** 9),
        ],
        typeArguments: [
            vSui_Sui_Pool.tokenXType,
            vSui_Sui_Pool.tokenYType,
        ],
    });

    // step 3
    const to_deposit_amount = 10 * 10 ** 9;
    const to_deposit_pool: PoolConfig = pool[vSui.symbol as keyof Pool];
    const to_deposit_coin = await txb.splitCoins(swap_vsui, [txb.pure(to_deposit_amount)]);
    await depositCoin(txb, to_deposit_pool, to_deposit_coin, to_deposit_amount);
    
    // transfer the remaining swap_vsui
    txb.transferObjects([swap_vsui], account.address);

    // step 4
    const borrow_amount = 10 * 10 ** 9;
    const [borrowed_sui] = await borrowCoin(txb, Sui_Pool, borrow_amount);

    // step 5
    const repay_coin = await txb.splitCoins(txb.gas, [txb.pure(2 * 10 ** 9)]);
    await txb.mergeCoins(repay_coin, [borrowed_sui]);
    const [repay_balance] = await txb.moveCall({
        target: "0x2::coin::into_balance",
        arguments: [repay_coin],
        typeArguments: [Sui_Pool.type],
    });
    const [extra_balance] = await repayFlashLoan(txb, Sui_Pool, receipt, repay_balance);

    // transfer the extra coin
    const [extra_coin] = await txb.moveCall({
        target: "0x2::coin::from_balance",
        arguments: [extra_balance],
        typeArguments: [Sui_Pool.type],
    });
    await txb.transferObjects([extra_coin], account.address);

    const result = await SignAndSubmitTXB(txb, account.client, account.keypair);
    console.log("result: ", result);
}

main();