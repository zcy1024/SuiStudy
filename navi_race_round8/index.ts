import dotenv from "dotenv";
import { NAVISDKClient } from "navi-sdk";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { flashloan, depositCoin, borrowCoin, repayFlashLoan, SignAndSubmitTXB } from "navi-sdk/dist/libs/PTB";
import { Sui, vSui, pool } from 'navi-sdk/dist/address.js';
import { Pool, PoolConfig } from "navi-sdk/dist/types";

// const sui_system = "0x3"
const SuiSystemState = "0x5";

const liquid_staking = "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55";
const NativePool = "0x7fa2faa111b8c65bea48a23049bfd81ca8f971a262d981dcd9a17c3825cb5baf";
const Metadata = "0x680cd26af32b2bde8d3361e804c53ec1d1cfe24c7f039eb7f549e8dfde389a60";
// stake(self: &mut NativePool, metadata: &mut Metadata<CERT>, wrapper: &mut SuiSystemState, coin: Coin<SUI>, ctx: &mut TxContext)

async function main() {
    dotenv.config();
    const MNEMONIC = process.env.MNEMONIC!;
    // console.log(MNEMONIC);

    const client = new NAVISDKClient({mnemonic: MNEMONIC, numberOfAccounts: 1});
    const account = client.accounts[0];
    // console.log(account.getAllCoins());

    const txb: any = new TransactionBlock();

    // step 1
    const flash_amount = 5 * 10 ** 9;
    const Sui_Pool: PoolConfig = pool[Sui.symbol as keyof Pool];
    const [flash_balance, receipt] = await flashloan(txb, Sui_Pool, flash_amount);
    // balance -> coin
    const [flash_coin] = await txb.moveCall({
        target: "0x2::coin::from_balance",
        arguments: [flash_balance],
        typeArguments: [Sui_Pool.type],
    });

    // step 2
    const wallet_amount = 11 * 10 ** 9;
    const [wallet_coin] = await txb.splitCoins(txb.gas, [wallet_amount]);
    await txb.mergeCoins(wallet_coin, [flash_coin]);

    // step 3
    const [staked_vSui] = await txb.moveCall({
        target: `${liquid_staking}::native_pool::stake_non_entry`,
        arguments: [
            txb.object(NativePool),
            txb.object(Metadata),
            txb.object(SuiSystemState),
            wallet_coin,
        ]
    });

    // step 4
    const vSui_Pool: PoolConfig = pool[vSui.symbol as keyof Pool];
    const deposit_amount = 15 * 10 ** 9;
    const deposit_coin = await txb.splitCoins(staked_vSui, [deposit_amount]);
    await depositCoin(txb, vSui_Pool, deposit_coin, deposit_amount);
    await txb.transferObjects([staked_vSui], account.address);

    // step 5
    const borrow_amount = flash_amount * (1 + 0.06);
    const [borrowed_sui] = await borrowCoin(txb, Sui_Pool, borrow_amount);
    // coin -> balance
    const [borrowed_balance] = await txb.moveCall({
        target: '0x2::coin::into_balance',
        arguments: [borrowed_sui],
        typeArguments: [Sui_Pool.type],
    });

    // step 6
    const [extra_balance] = await repayFlashLoan(txb, Sui_Pool, receipt, borrowed_balance);
    // balance -> coin
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