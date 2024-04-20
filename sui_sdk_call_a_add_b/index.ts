import dotenv from "dotenv";
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { getFullnodeUrl, SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { createInterface } from "readline";

dotenv.config();
const MNEMONIC = process.env.MNEMONIC!;
// console.log(MNEMONIC);

const keyPair = Ed25519Keypair.deriveKeypair(MNEMONIC);

const client = new SuiClient({url: getFullnodeUrl("testnet")});

const txb = new TransactionBlock();

const PACKAGE = "0xe2496799139225a06e7251857cdf46a32c20d773030c62b9bf24095cd60aac43";
const MODULE = "my_module";
const FUN = "add";
const target = `${PACKAGE}::${MODULE}::${FUN}`;
// console.log(target);

async function read(): Promise<string[]> {
    const readline = createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    var strNumber = "";
    readline.question("Please enter two numbers, separated by spaces: ", inputNumber => {
        strNumber = inputNumber;
        readline.close();
    });

    while (strNumber == "")
        await new Promise(resolve => setTimeout(resolve, 100));
    return strNumber.split(' ');
}

async function callAdd(a: number, b: number) {
    txb.moveCall({
        target,
        arguments: [txb.pure.u64(a), txb.pure.u64(b)],
    });
    
    const result = await client.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        signer: keyPair,
        requestType: "WaitForLocalExecution",
        options: {
            showObjectChanges: true,
        }
    });
    
    console.log(
        `executeTransactionBlock result: ${JSON.stringify(result, null, 2)}`
    );
}

async function main() {
    const nums = await read();
    // const a = Number(nums[0]);
    // const b = Number(nums[1]);
    // console.log(typeof a, typeof b, a, b);
    callAdd(Number(nums[0]), Number(nums[1]));
}

main();