import dotenv from "dotenv";
import { NAVISDKClient } from 'navi-sdk'
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { depositCoin, borrowCoin, SignAndSubmitTXB } from 'navi-sdk/dist/libs/PTB'
import { Sui, NAVX, pool } from 'navi-sdk/dist/address.js';
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
    const deposit_coin = txb.splitCoins(txb.gas, [txb.pure(amount)]);
    const SUI_POOL: PoolConfig = pool[Sui.symbol as keyof Pool];
    await depositCoin(txb, SUI_POOL, deposit_coin, amount);

    // step 2
    const borrow_amount = 666;
    const NAVX_POOL: PoolConfig = pool[NAVX.symbol as keyof Pool];
    const [borrowed_coin] = await borrowCoin(txb, NAVX_POOL, borrow_amount);

    // step 3
    await depositCoin(txb, NAVX_POOL, borrowed_coin, borrow_amount);

    const result = await SignAndSubmitTXB(txb, account.client, account.keypair);
    console.log("result: ", result);
}

main();