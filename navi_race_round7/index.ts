import dotenv from "dotenv";
import { NAVISDKClient } from "navi-sdk";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { borrowCoin, SignAndSubmitTXB } from "navi-sdk/dist/libs/PTB";
import { Sui, pool } from 'navi-sdk/dist/address.js';
import { Pool, PoolConfig } from "navi-sdk/dist/types";

// const sui_system = "0x3"
const SuiSystemState = "0x5";

const liquid_staking = "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55";
const NativePool = "0x7fa2faa111b8c65bea48a23049bfd81ca8f971a262d981dcd9a17c3825cb5baf";
const Metadata = "0x680cd26af32b2bde8d3361e804c53ec1d1cfe24c7f039eb7f549e8dfde389a60";
// stake(self: &mut NativePool, metadata: &mut Metadata<CERT>, wrapper: &mut SuiSystemState, coin: Coin<SUI>, ctx: &mut TxContext)

const aftermath = "0x7f6ce7ade63857c4fd16ef7783fed2dfc4d7fb7e40615abdb653030b76aef0c6";
const StakedSuiVault = "0x2f8f6d5da7f13ea37daa397724280483ed062769813b6f31e9788e59cc88994d";
const Safe = "0xeb685899830dd5837b47007809c76d91a098d52aabbf61e8ac467c59e5cc4610";
const ReferralVault = "0x4ce9a19b594599536c53edb25d22532f82f18038dc8ef618afd00fbbfb9845ef";
const ValidatorAddress = "0xd30018ec3f5ff1a3c75656abf927a87d7f0529e6dc89c7ddd1bd27ecb05e3db2";
// request_stake(arg0: StakedSuiVault, arg1: Safe, arg2: SuiSystemState, arg3: ReferralVault, arg4: Coin<SUI>, arg5: address)

async function main() {
    dotenv.config();
    const MNEMONIC = process.env.MNEMONIC!;
    // console.log(MNEMONIC);

    const client = new NAVISDKClient({mnemonic: MNEMONIC, numberOfAccounts: 1});
    const account = client.accounts[0];
    // console.log(account.getAllCoins());

    const txb: any = new TransactionBlock();

    // step 1
    const borrow_amount = 12 * 10 ** 9;
    const Sui_Pool: PoolConfig = pool[Sui.symbol as keyof Pool];
    const [borrowed_sui] = await borrowCoin(txb, Sui_Pool, borrow_amount);

    // step 2
    // Volo
    const [to_stake_volo_sui] = await txb.splitCoins(borrowed_sui, [6 * 10 ** 9]);
    await txb.moveCall({
        target: `${liquid_staking}::native_pool::stake`,
        arguments: [
            txb.object(NativePool),
            txb.object(Metadata),
            txb.object(SuiSystemState),
            to_stake_volo_sui,
        ]
    });
    // Aftermath
    await txb.moveCall({
        target: `${aftermath}::staked_sui_vault::request_stake_and_keep`,
        arguments: [
            txb.object(StakedSuiVault),
            txb.object(Safe),
            txb.object(SuiSystemState),
            txb.object(ReferralVault),
            borrowed_sui,
            txb.pure(ValidatorAddress, "address"),
        ]
    });

    const result = await SignAndSubmitTXB(txb, account.client, account.keypair);
    console.log("result: ", result);
}

main();