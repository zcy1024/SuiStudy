import dotenv from "dotenv";
import { NAVISDKClient } from 'navi-sdk'
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { flashloan, depositCoin, withdrawCoin, repayFlashLoan, SignAndSubmitTXB } from 'navi-sdk/dist/libs/PTB'
import { vSui, pool } from 'navi-sdk/dist/address.js';
import { Pool, PoolConfig } from "navi-sdk/dist/types";

async function main() {
    dotenv.config();
    const MNEMONIC = process.env.MNEMONIC!;
    // console.log(MNEMONIC);

    const client = new NAVISDKClient({mnemonic: MNEMONIC, numberOfAccounts: 1});
    const account = client.accounts[0];
    // console.log(account.getAllCoins());

    const txb: any = new TransactionBlock();

    // step 1
    const amount = 999;
    const vSui_Pool: PoolConfig = pool[vSui.symbol as keyof Pool];
    const [balance, receipt] = await flashloan(txb, vSui_Pool, amount);

    // balance -> coin
    const vSui_Coin = await txb.moveCall({
        target: "0x2::coin::from_balance",
        arguments: [balance],
        typeArguments: [vSui_Pool.type],
    });

    // step 2
    await depositCoin(txb, vSui_Pool, vSui_Coin, amount);

    // step 3
    const [withdraw_Coin] = await withdrawCoin(txb, vSui_Pool, amount);

    // coin -> balance
    const [repayBalance] = await txb.moveCall({
        target: "0x2::coin::into_balance",
        arguments: [withdraw_Coin],
        typeArguments: [vSui_Pool.type],
    });

    // step 4
    const [extraBalance] = await repayFlashLoan(txb, vSui_Pool, receipt, repayBalance);

    // get extra value
    const [extraValue] = await txb.moveCall({
        target: "0x2::balance::value",
        arguments: [extraBalance],
        typeArguments: [vSui_Pool.type],
    });

    if (extraValue == 0) {
        // destroy
        await txb.moveCall({
            target: "0x2::balance::destroy_zero",
            arguments: [extraBalance],
            typeArguments: [vSui_Pool.type],
        });
    } else {
        // balance -> coin
        const [extraCoin] = await txb.moveCall({
            target: "0x2::coin::from_balance",
            arguments: [extraBalance],
            typeArguments: [vSui_Pool.type],
        });

        // transfer extra coin
        await txb.transferObjects([extraCoin], account.address);
    }

    const result = await SignAndSubmitTXB(txb, account.client, account.keypair);
    console.log("result: ", result);
}

main();