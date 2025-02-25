import { Transaction } from '@mysten/sui/transactions';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

async function solve(flag: number[]) {
    const secretKey = "......";
    const keypair = Ed25519Keypair.fromSecretKey(secretKey);

    const tx = new Transaction();
    tx.setSender(keypair.toSuiAddress());
    tx.moveCall({
        target: "0x097a3833b6b5c62ca6ad10f0509dffdadff7ce31e1d86e63e884a14860cedc0f::lets_move::get_flag",
        arguments: [
            tx.pure.vector("u8", flag),
            tx.pure.string("zcy1024"),
            tx.object("0x19e76ca504c5a5fa5e214a45fca6c058171ba333f6da897b82731094504d5ab9"),
            tx.object("0x8")
        ]
    });

    const rpcUrl = getFullnodeUrl('testnet');
    const client = new SuiClient({ url: rpcUrl });

    const res = await client.dryRunTransactionBlock({ transactionBlock: await tx.build({ client }) });
    return res;
}

function dfs(i: number, flag: number[]) {
    if (i === flag.length) {
        flag.push(0);
        return;
    }
    flag[i] = flag[i] + 1;
    if (flag[i] === 256) {
        flag[i] = 0;
        dfs(i + 1, flag);
    }
    return;
}

async function main() {
    let flag: number[] = [];
    while (true) {
        dfs(0, flag);
        console.log(flag);
        try {
            const res = await solve(flag);
            console.log(res.events);
            break;
        } catch(err) {}
    }
}

main();